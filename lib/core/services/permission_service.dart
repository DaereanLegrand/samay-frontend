import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Outcome of an OS permission request, collapsed to the three states the UI
/// needs to act on (SEC-07 / DEP-11).
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
/// scanner (I-57) tomorrow — must go through this service instead of calling
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
    final outcome = await ensure(permission);
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
