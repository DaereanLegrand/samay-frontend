import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/permission_service.dart';
import 'package:samay/core/utils/form_validators.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_input.dart';

/// Gallery-picking seam for tests: `image_picker` is a platform plugin that
/// cannot run in widget tests, so the screen accepts an injectable function
/// (same thin-wrapper pattern as `PermissionService` and
/// `EditProfileScreen.galleryPicker`).
typedef GalleryPicker = Future<XFile?> Function(ImageSource source);

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key, this.permissions, this.galleryPicker});

  /// Injectable for tests (SEC-07); defaults to the real service.
  final PermissionService? permissions;

  /// Injectable for tests; defaults to `ImagePicker.pickImage(gallery)`.
  final GalleryPicker? galleryPicker;

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _picker = ImagePicker();
  late final PermissionService _permissions =
      widget.permissions ?? PermissionService();
  late final GalleryPicker _galleryPicker =
      widget.galleryPicker ?? ((source) => _picker.pickImage(source: source));
  XFile? _coverImage;
  bool _loading = false;

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    final granted = await _permissions.ensureWithPrompt(
      context,
      permission: Permission.photos,
      rationale: l10n.permissionsPhotoRationale,
      settingsTitle: l10n.permissionsSettingsTitle,
      settingsBody: l10n.permissionsSettingsBody,
      settingsAction: l10n.permissionsOpenSettings,
      cancelAction: l10n.commonCancel,
    );
    if (!granted) return;
    final file = await _galleryPicker(ImageSource.gallery);
    if (file != null) setState(() => _coverImage = file);
  }

  Future<void> _create() async {
    final name = InputSanitizer.sanitize(
      _nameController.text,
      maxLength: InputSanitizer.groupNameMaxLength,
    );
    if (requiredValidator(name) != null) return;
    final description = InputSanitizer.sanitizeOptional(
      _descController.text,
      maxLength: InputSanitizer.groupDescriptionMaxLength,
    );
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      final groupCount = await ref
          .read(groupServiceProvider)
          .getUserGroupCount();
      if (groupCount >= 5) {
        setState(() => _loading = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(l10n.groupsLimitReached),
              content: Text(l10n.groupsLimitReachedBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonOk),
                ),
              ],
            ),
          );
        }
        return;
      }
      String? coverUrl;
      if (_coverImage != null) {
        final bytes = await _coverImage!.readAsBytes();
        coverUrl = await ref.read(mediaServiceProvider).uploadGroupCover(bytes);
      }
      await ref.read(groupServiceProvider).createGroup({
        'name': name,
        'description': description,
        'cover_url': coverUrl,
      });
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.groupsCreatedSnack)));
        context.pop();
      }
    } catch (e, st) {
      setState(() => _loading = false);
      AppLogger.instance.error('createGroup error: $e', '$st');
      if (mounted) showAppError(context, e, blocking: true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupsCreateGroup)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      // §5.8 skeleton-base surface for the empty cover slot +
                      // the §2.1 interactive-outline token (never raw greys).
                      color: AppColors.surfaceAlt,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _coverImage != null
                        ? ClipRect(
                            child: Image.file(
                              File(_coverImage!.path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 160,
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.camera_alt,
                                  size: 40,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.groupsAddCover,
                                  style: const TextStyle(
                                    color: AppColors.mutedStrong,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                VInput(
                  controller: _nameController,
                  label: l10n.groupsNameLabel,
                ),
                const SizedBox(height: 16),
                VInput(
                  controller: _descController,
                  label: l10n.groupsDescriptionOptional,
                  maxLines: 3,
                ),
                const SizedBox(height: 32),
                // §5.1 LUXE: creating the group is the screen's one brand
                // moment — the violet glow accent (family gradient fill,
                // black text 6.00:1).
                VButton.glowAccent(
                  filled: true,
                  gradient: AppGradients.violet,
                  label: l10n.commonCreate,
                  loading: _loading,
                  onPressed: _create,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
