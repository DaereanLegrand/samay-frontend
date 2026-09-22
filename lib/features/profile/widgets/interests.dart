import 'package:flutter/material.dart';
import 'package:samay/core/models/user_interests.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_chip.dart';

/// Curated interest-tag catalog.
///
/// The identifiers are stable lowercase slugs that map 1:1 to ARB labels
/// through [interestTagLabel]; the catalog is deliberately a plain `const`
/// list so the picker stays dead simple. Persistence needs a
/// `users.interest_tags text[]` column migration (owned by the DB layer).
const List<String> kInterestTagIds = <String>[
  'musica',
  'fiestas',
  'deportes',
  'gaming',
  'cine',
  'arte',
  'viajes',
  'comida',
];

/// Resolves the localized label for [tagId]. Throws [ArgumentError] for ids
/// outside the catalog — the picker only ever renders catalog entries, so an
/// unknown id is a programming error worth surfacing loudly.
String interestTagLabel(AppLocalizations l10n, String tagId) {
  switch (tagId) {
    case 'musica':
      return l10n.interestMusica;
    case 'fiestas':
      return l10n.interestFiestas;
    case 'deportes':
      return l10n.interestDeportes;
    case 'gaming':
      return l10n.interestGaming;
    case 'cine':
      return l10n.interestCine;
    case 'arte':
      return l10n.interestArte;
    case 'viajes':
      return l10n.interestViajes;
    case 'comida':
      return l10n.interestComida;
  }
  throw ArgumentError.value(tagId, 'tagId', 'Unknown interest tag id');
}

/// Multi-select tag picker.
///
/// A `Wrap` of [VChip] (disco-styled [FilterChip]s) rendering the whole
/// catalog; [onChanged] receives the new selection set on every toggle. The
/// widget is stateless and const-constructible — the parent owns the
/// [UserInterests] state (persistence lands with the `interest_tags`
/// migration).
class InterestTagPicker extends StatelessWidget {
  const InterestTagPicker({
    super.key,
    this.selected = const <String>{},
    required this.onChanged,
  });

  /// Currently selected tag ids.
  final Set<String> selected;

  /// Called with the updated selection after any chip toggles.
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tagId in kInterestTagIds)
          VChip(
            label: interestTagLabel(l10n, tagId),
            selected: selected.contains(tagId),
            onSelected: () => onChanged(
              UserInterests(selected).toggle(tagId).tags,
            ),
          ),
      ],
    );
  }
}
