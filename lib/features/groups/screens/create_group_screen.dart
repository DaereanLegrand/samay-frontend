import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/utils/form_validators.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Gallery-picking seam for tests: `image_picker` is a platform plugin that
/// cannot run in widget tests, so the screen accepts an injectable function
/// (same thin-wrapper pattern as `EditProfileScreen.galleryPicker`).
typedef GalleryPicker = Future<XFile?> Function(ImageSource source);

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key, this.galleryPicker});

  /// Injectable for tests; defaults to `ImagePicker.pickImage(gallery)`.
  final GalleryPicker? galleryPicker;

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _picker = ImagePicker();
  late final GalleryPicker _galleryPicker =
      widget.galleryPicker ?? ((source) => _picker.pickImage(source: source));
  XFile? _coverImage;
  bool _loading = false;

  Future<void> _pickImage() async {
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
      // The group's chat row is created with it (group_service) — refresh the
      // inbox so the new group chat shows immediately.
      ref.invalidate(chatInboxProvider);
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
      body: VHeaderBar(
        title: l10n.groupsCreateGroup,
        child: ListView(
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
                        // Skeleton-base surface for the empty cover slot +
                        // the interactive-outline token (never raw greys).
                        color: context.palette.surfaceAlt,
                        border: Border.all(color: context.palette.border),
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
                                  Icon(
                                    Icons.camera_alt,
                                    size: 40,
                                    color: context.palette.mutedForeground,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.groupsAddCover,
                                    style: TextStyle(
                                      color: context.palette.mutedForeground,
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
                  // Creating the group is the screen's primary action.
                  VButton.dark(
                    label: l10n.commonCreate,
                    loading: _loading,
                    onPressed: _create,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
