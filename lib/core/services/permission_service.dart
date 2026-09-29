import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Outcome of an OS permission request, collapsed to the three states the UI
/// needs to act on.
enum PermissionOutcome { granted, denied, permanentlyDenied }

/// Injection seam for the `permission_handler` plugin (a MethodChannel plugin
/// that cannot run in widget tests): callers/tests substitute this function
/// instead of mocking the channel.
typedef PermissionRequester = Future<ph.PermissionStatus> Function(
  ph.Permission permission,
);

Future<ph.PermissionStatus> _defaultRequest(ph.Permission permission) =>
    permission.request();

Future<bool> _defaultOpenSettings() => ph.openAppSettings();

/// Single seam for every OS permission the app needs (camera, photo library,
/// …). All future camera/gallery code — the group-cover picker today, the QR
/// scanner tomorrow — must go through this service instead of calling
/// `permission_handler` directly, so the rationale/denied/permanently-denied
/// UX stays consistent and testable.
///
/// Both platform calls are injectable ([request], [openSettings]) — the
/// default implementations talk to the plugin, tests substitute fakes.
class PermissionService {
  PermissionService({
    PermissionRequester? request,
    Future<bool> Function()? openSettings,
  })  : _request = request ?? _defaultRequest,
        _openSettings = openSettings ?? _defaultOpenSettings;

  final PermissionRequester _request;
  final Future<bool> Function() _openSettings;

  /// Requests [permission] and collapses the plugin's six statuses into
  /// [PermissionOutcome]:
  ///
  /// * `granted` / `limited` (iOS partial photo access) / `provisional` →
  ///   [PermissionOutcome.granted] — the feature may run.
  /// * `permanentlyDenied` → [PermissionOutcome.permanentlyDenied] — only the
  ///   system settings can change this; show the settings dialog.
  /// * `denied` / `restricted` → [PermissionOutcome.denied] — requestable
  ///   again; show the rationale.
  Future<PermissionOutcome> ensure(ph.Permission permission) async {
    final status = await _request(permission);
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return PermissionOutcome.granted;
    }
    if (status.isPermanentlyDenied) return PermissionOutcome.permanentlyDenied;
    return PermissionOutcome.denied;
  }

  /// Gallery access, resolved per OS version.
  ///
  /// `Permission.photos` maps to READ_MEDIA_IMAGES, which only EXISTS on
  /// Android 13+ (API 33). On Android 12 and below the OS has no such
  /// permission, so the request comes back denied no matter what the user
  /// taps and the picker never opens — the bug reported on a Galaxy S10+
  /// (Android 12) while newer phones worked fine. Those versions need
  /// READ_EXTERNAL_STORAGE (`Permission.storage`), which the manifest already
  /// declares with `maxSdkVersion=32`.
  ///
  /// Rather than take a dependency just to read the SDK int, ask for photos
  /// first and, on Android only, fall back to storage — on 13+ the first ask
  /// succeeds and the fallback never runs; on <=12 the first ask is a no-op
  /// against a permission the OS does not know and the fallback is the real
  /// request. iOS/web keep the photos path.
  Future<PermissionOutcome> ensurePhotoLibrary() async {
    final outcome = await ensure(ph.Permission.photos);
    if (outcome == PermissionOutcome.granted) return outcome;
    if (kIsWeb || !Platform.isAndroid) return outcome;
    return ensure(ph.Permission.storage);
  }

  /// Opens the OS app-settings page (the only way out of a permanent deny).
  Future<bool> openSettings() => _openSettings();

  /// The full permission UX for a feature entry point:
  ///
  /// 1. [PermissionOutcome.granted] → returns `true` immediately.
  /// 2. [PermissionOutcome.denied] → shows a rationale [SnackBar] with
  ///    [rationale] and returns `false`.
  /// 3. [PermissionOutcome.permanentlyDenied] → shows an [AlertDialog]
  ///    ([settingsTitle]/[settingsBody]) offering [settingsAction] (calls
  ///    [openSettings]) or [cancelAction], and returns `false`.
  ///
  /// The message strings are caller-supplied so this service stays decoupled
  /// from the localization layer (callers pass `AppLocalizations` values).
  Future<bool> ensureWithPrompt(
    BuildContext context, {
    required ph.Permission permission,
    required String rationale,
    required String settingsTitle,
    required String settingsBody,
    required String settingsAction,
    required String cancelAction,
  }) async {
    // Gallery asks route through the version-aware path so Android <= 12
    // (no READ_MEDIA_IMAGES) still reaches the picker.
    final outcome = permission == ph.Permission.photos
        ? await ensurePhotoLibrary()
        : await ensure(permission);
    if (outcome == PermissionOutcome.granted) return true;
    if (!context.mounted) return false;

    if (outcome == PermissionOutcome.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(rationale)),
      );
      return false;
    }

    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(settingsTitle),
        content: Text(settingsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(settingsAction),
          ),
        ],
      ),
    );
    if (shouldOpenSettings == true) {
      await _openSettings();
    }
    return false;
  }
}
