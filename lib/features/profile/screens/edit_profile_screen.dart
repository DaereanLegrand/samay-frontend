import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/features/profile/providers/profile_providers.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:samay/shared/widgets/v_spinner.dart';

/// Gallery-picking seam for tests: `image_picker` is a platform plugin that
/// cannot run in widget tests, so the screen accepts an injectable function.
typedef GalleryPicker = Future<XFile?> Function(ImageSource source);

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, this.galleryPicker});

  /// Injectable for tests; defaults to `ImagePicker.pickImage(gallery)`.
  final GalleryPicker? galleryPicker;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _bioController = TextEditingController();
  final _picker = ImagePicker();
  late final GalleryPicker _galleryPicker =
      widget.galleryPicker ?? ((source) => _picker.pickImage(source: source));
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _bioLoaded = false;
  String? _avatarUrl;
  String _initials = '';

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<Map<String, dynamic>?>>(myProfileProvider, (
      _,
      next,
    ) {
      if (next.hasValue && !_bioLoaded) {
        _applyProfile(next.value ?? const <String, dynamic>{});
      }
    });
    _load();
  }

  void _applyProfile(Map<String, dynamic> profile) {
    _bioLoaded = true;
    _bioController.text = profile['bio'] as String? ?? '';
    _avatarUrl = profile['avatar_url'] as String?;
    final username = profile['username']?.toString() ?? '';
    _initials = username.isEmpty
        ? ''
        : username
              .substring(0, username.length < 2 ? username.length : 2)
              .toUpperCase();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _load() async {
    final profile = ref.read(myProfileProvider);
    if (profile.hasValue) {
      _applyProfile(profile.value ?? const <String, dynamic>{});
      return;
    }
    try {
      final user = ref.read(authServiceProvider).auth.currentUser;
      if (user == null) return;
      final res = await ref.read(userServiceProvider).getUserProfile(user.id);
      if (res != null) {
        _applyProfile(res);
      }
    } catch (e, st) {
      AppLogger.instance.error('loadProfileBio error: $e', '$st');
    } finally {
      if (mounted && !_bioLoaded) setState(() => _loading = false);
    }
  }

  /// The avatar-upload flow: gallery pick → compress in
  /// [MediaService.uploadUserAvatar] → persist the URL → invalidate
  /// [myProfileProvider] so every profile consumer refetches.
  Future<void> _uploadAvatar() async {
    final l10n = AppLocalizations.of(context);
    final file = await _galleryPicker(ImageSource.gallery);
    if (file == null) return;
    // Await the auth resolution: `ref.read(authStateProvider)` alone returns
    // the in-flight AsyncLoading on first access (nothing watches it on this
    // screen), which would silently abort the flow with a null user.
    final authState = await ref.read(authStateProvider.future);
    final userId = authState.user?['id'] as String?;
    if (userId == null) return;
    if (!mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await ref
          .read(mediaServiceProvider)
          .uploadUserAvatar(userId, bytes);
      await ref.read(userServiceProvider).updateAvatarUrl(userId, url);
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileAvatarUpdatedSnack)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final user = ref.read(authServiceProvider).auth.currentUser;
      if (user == null) return;
      await ref
          .read(userServiceProvider)
          .updateBio(
            user.id,
            InputSanitizer.sanitize(
              _bioController.text,
              maxLength: InputSanitizer.bioMaxLength,
            ),
          );
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileUpdatedSnack)));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: VHeaderBar(
        title: l10n.profileEditTitle,
        child: _loading
            // First load shows the shared spinner.
            ? const VLoadingView()
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        ProfileAvatar(
                          initials: _initials,
                          imageUrl: _avatarUrl,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.white,
                            child: _uploadingAvatar
                                ? const VSpinner(
                                    size: 16,
                                    color: AppColors.discoBlack,
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: AppColors.discoBlack,
                                    ),
                                    tooltip: l10n.profileAvatarChange,
                                    onPressed: _uploadAvatar,
                                    padding: EdgeInsets.zero,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  VInput(controller: _bioController, label: l10n.profileBio),
                  const SizedBox(height: AppSpacing.xxl),
                  VButton.emphasized(
                    label: l10n.profileSaveChanges,
                    loading: _saving,
                    onPressed: _save,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // The password-change placeholder renders disabled — an
                  // enabled no-op button would be a misleading affordance.
                  TextButton(
                    onPressed: null,
                    child: Text(l10n.profileChangePassword),
                  ),
                ],
              ),
      ),
    );
  }
}
