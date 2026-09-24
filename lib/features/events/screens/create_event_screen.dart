import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/config_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/providers/user_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/permission_service.dart';
import 'package:samay/features/events/logic/event_form_data.dart';
import 'package:samay/features/events/providers/event_discovery_providers.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/location_picker_sheet.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';

/// Gallery-picking seam for tests: `image_picker` is a platform plugin that
/// cannot run in widget tests, so the screen accepts an injectable function
/// (same thin-wrapper pattern as `CreateGroupScreen`/`EditProfileScreen`).
typedef EventCoverPicker = Future<XFile?> Function(ImageSource source);

/// Event creation flow.
///
/// Single-scroll form covering the spec's steps 1–5 and 7: type selector
/// (Casual/Juerga/Tono), details (name, description, date/time pickers,
/// location, optional cover), visibility (public vs group-scoped from the
/// user's host groups), join mode (public only), the Juerga location
/// warning modal, and the preshards section (Juerga/Tono only — pool, per-user
/// cap, remainder action; hidden and forced to 0 for Casual, mirroring the
/// DB CHECK constraint `check_casual_no_preshards`).
///
/// Step 6 (invite hosts) and step 7's daily-limit check + static QR are
/// tracked separately; the creator is auto-inserted as host by
/// `EventService.createEvent`.
///
/// Route: `/group/:groupId/create-event` (group-scoped prefill). A standalone
/// `/event/create` path is deliberately NOT added, keeping route ordering
/// unambiguous.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({
    super.key,
    this.groupId,
    this.permissions,
    this.coverPicker,
  });

  /// The group this event is being created for (`/group/:groupId/create-event`
  /// route); `null` for the standalone public flow.
  final String? groupId;

  /// Injectable for tests; defaults to the real service.
  final PermissionService? permissions;

  /// Injectable for tests; defaults to `ImagePicker.pickImage(gallery)`.
  final EventCoverPicker? coverPicker;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _poolController = TextEditingController();
  final _capController = TextEditingController();
  final _picker = ImagePicker();

  late final PermissionService _permissions =
      widget.permissions ?? PermissionService();
  late final EventCoverPicker _coverPicker =
      widget.coverPicker ?? ((source) => _picker.pickImage(source: source));

  late EventFormData _form = EventFormData(
    startsAt: _defaultStarts(),
    endsAt: _defaultEnds(),
    // Group-route prefills: the event is born group-scoped.
    visibility: widget.groupId == null
        ? EventVisibility.public
        : EventVisibility.group,
    groupId: widget.groupId,
  );

  XFile? _coverImage;
  bool _loading = false;
  List<Map<String, dynamic>> _myGroups = [];
  bool _groupsError = false;

  /// Attendee capacity (host + staff + guests). The server freezes the real
  /// cap; the stepper is bounded to the creator's entitlement-tier max.
  int _capacity = 7;
  int _tierCap = 7;
  bool _capacityEdited = false;

  /// Default start: 1 h out, but clamped to TODAY near midnight. A naive
  /// `now + 1 h` crosses into the next calendar day (e.g. 23:05 → 00:05
  /// tomorrow), which silently shifts "starts now"-style events ~24 h out.
  /// Same-day keeps the event immediate; the server accepts a start that has
  /// already passed and the code window opens at once.
  static DateTime _defaultStarts() {
    final now = DateTime.now();
    final start = now.add(const Duration(hours: 1));
    final crossesMidnight =
        start.year != now.year ||
        start.month != now.month ||
        start.day != now.day;
    return crossesMidnight ? now : start;
  }

  static DateTime _defaultEnds() =>
      _defaultStarts().add(const Duration(hours: 2));

  @override
  void initState() {
    super.initState();
    _loadMyGroups();
    _loadEntitlement();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _poolController.dispose();
    _capController.dispose();
    super.dispose();
  }

  /// The user's host/staff groups for the group-scoped selector.
  /// Failures are non-blocking: the route-prefilled group (if any) stays
  /// usable and public events never need this list.
  Future<void> _loadMyGroups() async {
    try {
      final groups = await ref.read(groupServiceProvider).getMyGroups();
      if (!mounted) return;
      setState(() => _myGroups = groups);
    } catch (e, st) {
      AppLogger.instance.error('getMyGroups (create event) error: $e', '$st');
      if (!mounted) return;
      setState(() => _groupsError = true);
    }
  }

  /// Resolves the creator's entitlement-tier attendance cap from
  /// app_config (`events.{free,t2,t1,t0}_max_attendees`). Falls back to the
  /// seeded free value (7) while the profile/config are loading or missing.
  Future<void> _loadEntitlement() async {
    try {
      final profile = await ref.read(currentUserProvider.future);
      final tier = profile?.entitlementTier ?? 'free';
      final cfg = await ref.read(appConfigProvider.future);
      final cap =
          int.tryParse(cfg['events.${tier}_max_attendees'] ?? '') ??
          _fallbackCap(tier);
      if (!mounted) return;
      setState(() {
        _tierCap = cap;
        if (!_capacityEdited) _capacity = cap;
        _form = _form.copyWith(capacity: _capacity);
      });
    } catch (e, st) {
      AppLogger.instance.error(
        'create event: resolve capacity error: $e',
        '$st',
      );
    }
  }

  static int _fallbackCap(String tier) {
    return switch (tier) {
      't2' => 14,
      't1' => 56,
      't0' => 1120,
      _ => 7,
    };
  }

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
    final file = await _coverPicker(ImageSource.gallery);
    if (file != null && mounted) setState(() => _coverImage = file);
  }

  /// Switching to Juerga requires the explicit location warning confirmation;
  /// cancelling keeps the previous type (no silent switch).
  Future<void> _selectType(EventType type) async {
    final l10n = AppLocalizations.of(context);
    if (type == EventType.juerga && _form.type != EventType.juerga) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.discoBlack,
          title: Text(
            l10n.eventsJuergaWarningTitle,
            style: const TextStyle(color: AppColors.white),
          ),
          content: Text(
            l10n.eventsJuergaWarningBody,
            style: const TextStyle(color: AppColors.mutedStrong),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.eventsJuergaWarningConfirm,
                style: const TextStyle(color: AppColors.white),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() {
        _form = _form.copyWith(
          type: EventType.juerga,
          juergaLocationConfirmed: true,
          // A sensible remainder default once preshards are enabled.
          remainderAction:
              _form.remainderAction ??
              EventRemainderAction.returnToContributors,
        );
      });
      return;
    }
    setState(() {
      _form = _form.copyWith(
        type: type,
        // Casual hides the preshards section — drop any stale pool input so
        // the forced-zero rule can never trip on hidden fields.
        preshardsPool: type == EventType.casual ? 0 : _form.preshardsPool,
      );
      if (type == EventType.casual) {
        _poolController.clear();
        _capController.clear();
      } else if (type == EventType.tono && _form.remainderAction == null) {
        _form = _form.copyWith(
          remainderAction: EventRemainderAction.returnToContributors,
        );
      }
    });
  }

  void _setVisibility(EventVisibility visibility) {
    setState(() {
      _form = _form.copyWith(
        visibility: visibility,
        // Keep the route prefill when group-scoped; clear it for public.
        groupId: visibility == EventVisibility.group
            ? (_form.groupId ?? widget.groupId)
            : null,
      );
    });
  }

  Future<void> _pickDate(bool starts) async {
    final l10n = AppLocalizations.of(context);
    final current = starts ? _form.startsAt : _form.endsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: starts
          ? DateTime.now().subtract(const Duration(days: 1))
          : _form.startsAt,
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: starts ? l10n.eventsStartsLabel : l10n.eventsEndsLabel,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (starts) {
        var ends = _form.endsAt;
        // Keep the invariant end > start by nudging a stale end.
        if (!ends.isAfter(picked)) {
          ends = picked.add(const Duration(hours: 1));
        }
        _form = _form.copyWith(startsAt: picked, endsAt: ends);
      } else {
        _form = _form.copyWith(endsAt: picked);
      }
    });
  }

  /// Opens the map/link/coords picker and stores the chosen point on the form
  /// (feeds `events.location_lat/lng` → server-side km discovery).
  Future<void> _pickCoordinates() async {
    final current = (_form.locationLat == null || _form.locationLng == null)
        ? null
        : LatLng(_form.locationLat!, _form.locationLng!);
    final picked = await showLocationPicker(context, initial: current);
    if (picked == null || !mounted) return;
    setState(() {
      _form = _form.copyWith(
        locationLat: picked.latitude,
        locationLng: picked.longitude,
      );
    });
  }

  Future<void> _submit() async {
    final form = _form
        .copyWith(
          name: _nameController.text,
          description: _descriptionController.text,
          locationName: _locationController.text,
          preshardsPool: _form.preshardsEnabled
              ? int.tryParse(_poolController.text) ?? 0
              : 0,
          preshardsCapPerUser: _capController.text.trim().isEmpty
              ? null
              : int.tryParse(_capController.text),
          capacity: _capacity.clamp(1, _tierCap).toInt(),
        )
        .sanitized();
    final errors = form.validate();
    if (errors.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(context, errors.first))),
      );
      return;
    }

    setState(() {
      _form = form;
      _loading = true;
    });
    try {
      String? coverUrl;
      if (_coverImage != null) {
        final bytes = await _coverImage!.readAsBytes();
        coverUrl = await ref.read(mediaServiceProvider).uploadEventCover(bytes);
      }
      final payload = form.toPayload()..['cover_url'] = coverUrl;
      final created = await ref.read(eventServiceProvider).createEvent(payload);
      setState(() => _loading = false);
      if (!mounted) return;
      // The events tab list is cached — invalidate so the new event shows.
      ref.invalidate(myEventsProvider);
      ref.invalidate(eventDiscoveryProvider);
      // The event detail screen owns the real detail view; until then the
      // route keeps its coming-soon placeholder — navigation shape is final.
      context.push(RoutePaths.eventDetail(created['id'] as String));
    } catch (e, st) {
      setState(() => _loading = false);
      AppLogger.instance.error('createEvent error: $e', '$st');
      if (mounted) showAppError(context, e, blocking: true);
    }
  }

  String _errorMessage(BuildContext context, EventFormError error) {
    final l10n = AppLocalizations.of(context);
    return switch (error) {
      EventFormError.nameRequired => l10n.eventsErrorNameRequired,
      EventFormError.invalidTimeRange => l10n.eventsErrorTimeRange,
      EventFormError.casualPoolMustBeZero => l10n.eventsErrorCasualPool,
      EventFormError.juergaLocationUnconfirmed => l10n.eventsErrorJuergaConfirm,
      EventFormError.groupRequired => l10n.eventsErrorGroup,
      EventFormError.joinModeRequired => l10n.eventsErrorJoinMode,
    };
  }

  String _typeDescription(AppLocalizations l10n) {
    return switch (_form.type) {
      EventType.casual => l10n.eventsTypeCasualDescription,
      EventType.juerga => l10n.eventsTypeJuergaDescription,
      EventType.tono => l10n.eventsTypeTonoDescription,
    };
  }

  String _formatDateTime(BuildContext context, DateTime dt) {
    final material = MaterialLocalizations.of(context);
    return '${material.formatFullDate(dt)} · '
        '${TimeOfDay.fromDateTime(dt).format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: VHeaderBar(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  // §5.8 skeleton-base surface for the empty cover slot + the
                  // §2.1 interactive-outline token (never raw greys —
                  // create_group precedent).
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
                            const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.xl),
            VInput(controller: _nameController, label: l10n.eventsNameLabel),
            const SizedBox(height: AppSpacing.lg),
            VInput(
              controller: _descriptionController,
              label: l10n.eventsDescriptionOptional,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            _sectionLabel(l10n.eventsTypeLabel),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final type in EventType.values)
                  VChip(
                    label: switch (type) {
                      EventType.casual => l10n.eventsTypeCasual,
                      EventType.juerga => l10n.eventsTypeJuerga,
                      EventType.tono => l10n.eventsTypeTono,
                    },
                    selected: _form.type == type,
                    onSelected: () => _selectType(type),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _typeDescription(l10n),
              style: const TextStyle(color: AppColors.mutedStrong),
            ),
            const SizedBox(height: AppSpacing.xl),
            _dateRow(context, starts: true),
            const SizedBox(height: AppSpacing.sm),
            _dateRow(context, starts: false),
            const SizedBox(height: AppSpacing.lg),
            VInput(
              controller: _locationController,
              label: l10n.eventsLocationLabel,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _pickCoordinates,
                  icon: const Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: AppColors.white,
                  ),
                  label: Text(
                    _form.locationLat == null || _form.locationLng == null
                        ? l10n.eventsPickLocation
                        : l10n.locationPickerCoordinates(
                            '${_form.locationLat!.toStringAsFixed(5)}, '
                            '${_form.locationLng!.toStringAsFixed(5)}',
                          ),
                    style: const TextStyle(color: AppColors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _sectionLabel(l10n.eventsCapacityTitle),
            const SizedBox(height: AppSpacing.md),
            _buildCapacityStepper(context),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.eventsCapacityHint,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.mutedStrong),
            ),
            if (_capacity >= _tierCap) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _contactUs,
                  icon: const Icon(
                    Icons.mail_outline,
                    size: 18,
                    color: AppColors.glowPink,
                  ),
                  label: Text(
                    l10n.eventsCapacityContact,
                    style: const TextStyle(color: AppColors.glowPink),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _sectionLabel(l10n.eventsVisibilityLabel),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                VChip(
                  label: l10n.eventsVisibilityPublic,
                  selected: _form.visibility == EventVisibility.public,
                  onSelected: () => _setVisibility(EventVisibility.public),
                ),
                VChip(
                  label: l10n.eventsVisibilityGroup,
                  selected: _form.visibility == EventVisibility.group,
                  onSelected: () => _setVisibility(EventVisibility.group),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_form.visibility == EventVisibility.group) ...[
              _buildGroupSelector(context),
              const SizedBox(height: AppSpacing.lg),
            ] else ...[
              _sectionLabel(l10n.eventsJoinModeLabel),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  VChip(
                    label: l10n.eventsJoinModeOpen,
                    selected: _form.joinMode == EventJoinMode.open,
                    onSelected: () => setState(
                      () =>
                          _form = _form.copyWith(joinMode: EventJoinMode.open),
                    ),
                  ),
                  VChip(
                    label: l10n.eventsJoinModeApproval,
                    selected: _form.joinMode == EventJoinMode.approval,
                    onSelected: () => setState(
                      () => _form = _form.copyWith(
                        joinMode: EventJoinMode.approval,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _form.joinMode == EventJoinMode.approval
                    ? l10n.eventsJoinModeApprovalDescription
                    : l10n.eventsJoinModeOpenDescription,
                style: const TextStyle(color: AppColors.mutedStrong),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (_form.preshardsEnabled) ...[
              _sectionLabel(l10n.eventsPreshardsLabel),
              const SizedBox(height: AppSpacing.sm),
              VInput(
                controller: _poolController,
                label: l10n.eventsPreshardsPoolLabel,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.lg),
              VInput(
                controller: _capController,
                label: l10n.eventsPreshardsCapLabel,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.lg),
              _sectionLabel(l10n.eventsRemainderLabel),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  VChip(
                    label: l10n.eventsRemainderReturn,
                    selected:
                        _form.remainderAction ==
                        EventRemainderAction.returnToContributors,
                    onSelected: () => setState(
                      () => _form = _form.copyWith(
                        remainderAction:
                            EventRemainderAction.returnToContributors,
                      ),
                    ),
                  ),
                  VChip(
                    label: l10n.eventsRemainderRedistribute,
                    selected:
                        _form.remainderAction ==
                        EventRemainderAction.redistribute,
                    onSelected: () => setState(
                      () => _form = _form.copyWith(
                        remainderAction: EventRemainderAction.redistribute,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.eventsDynamicQrHint,
                style: const TextStyle(color: AppColors.mutedStrong),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            const SizedBox(height: AppSpacing.sm),
            VButton.dark(
              label: l10n.groupsCreateEvent,
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: AppTypography.sectionLabel);
  }

  /// "¿Quieres más? Contáctanos" — static for now; the billing/contact
  /// pipeline is not built yet.
  void _contactUs() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.eventsContactSoon)));
  }

  void _setCapacity(int value) {
    final next = value.clamp(1, _tierCap).toInt();
    setState(() {
      _capacityEdited = true;
      _capacity = next;
      _form = _form.copyWith(capacity: next);
    });
  }

  Widget _buildCapacityStepper(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.none),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _capacity > 1 ? () => _setCapacity(_capacity - 1) : null,
            icon: const Icon(Icons.remove, color: AppColors.mutedStrong),
          ),
          Text(
            '$_capacity',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: AppColors.white),
          ),
          IconButton(
            onPressed: _capacity < _tierCap
                ? () => _setCapacity(_capacity + 1)
                : null,
            icon: const Icon(Icons.add, color: AppColors.mutedStrong),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(BuildContext context, {required bool starts}) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () => _pickDate(starts),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: starts ? l10n.eventsStartsLabel : l10n.eventsEndsLabel,
          labelStyle: const TextStyle(color: AppColors.mutedStrong),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          enabledBorder: const OutlineInputBorder(
            borderRadius: AppRadius.sharp,
            borderSide: BorderSide(color: AppColors.border),
          ),
          border: const OutlineInputBorder(
            borderRadius: AppRadius.sharp,
            borderSide: BorderSide(color: AppColors.border),
          ),
        ),
        child: Text(
          _formatDateTime(context, starts ? _form.startsAt : _form.endsAt),
          style: const TextStyle(color: AppColors.white),
        ),
      ),
    );
  }

  Widget _buildGroupSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <DropdownMenuItem<String>>[
      for (final group in _myGroups)
        DropdownMenuItem(
          value: group['id'] as String,
          child: Text(
            group['name'] as String? ?? l10n.commonGroup,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    final current = _form.groupId;
    // The route-prefilled group may not be in the fetched list yet (or the
    // list may have failed to load) — keep it selectable so the flow works.
    if (current != null && !_myGroups.any((g) => g['id'] == current)) {
      items.add(
        DropdownMenuItem(value: current, child: Text(l10n.commonGroup)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.eventsGroupSelectorLabel,
            labelStyle: const TextStyle(color: AppColors.mutedStrong),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.sharp,
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadius.sharp,
              borderSide: BorderSide(color: AppColors.white),
            ),
            border: const OutlineInputBorder(
              borderRadius: AppRadius.sharp,
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
          isEmpty: current == null,
          child: DropdownButton<String>(
            value: current,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: AppColors.surfaceAlt,
            iconEnabledColor: AppColors.white,
            style: const TextStyle(color: AppColors.white),
            hint: Text(
              l10n.eventsGroupSelectorHint,
              style: const TextStyle(color: AppColors.muted),
            ),
            items: items,
            onChanged: (value) =>
                setState(() => _form = _form.copyWith(groupId: value)),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_groupsError)
          Text(
            l10n.eventsGroupsLoadError,
            style: const TextStyle(color: AppColors.glowPink),
          )
        else if (_myGroups.isEmpty && current == null)
          Text(
            l10n.groupsNoneYet,
            style: const TextStyle(color: AppColors.mutedStrong),
          ),
      ],
    );
  }
}
