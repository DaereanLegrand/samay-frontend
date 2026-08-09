import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_chip.dart';

/// Curated interest-tag catalog (PRFL "interest tags" gap — I-36 foundation).
///
/// The identifiers are stable lowercase slugs that map 1:1 to ARB labels
/// through [interestTagLabel]; the catalog is deliberately a plain `const`
/// list so the picker and tests stay dead simple. Persistence needs a
/// `users.interest_tags text[]` column migration (see the I-36 daily log —
/// owned by the migration agents I-31/I-32, NOT this app layer).
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

/// Immutable value object for a user's interest-tag selection (PRFL gap
/// foundation — I-36).
///
/// Storage contract: `users.interest_tags text[]`. [fromDb] accepts both the
/// PostgREST native list form and a JSON-encoded array string; [toDb] emits
/// the sorted JSON array literal PostgREST accepts for `text[]` columns
/// (deterministic ordering keeps roundtrips and diffs stable).
class UserInterests {
  const UserInterests([this.tags = const <String>{}]);

  static const UserInterests empty = UserInterests();

  /// Selected tag ids (catalog slugs). Treat as immutable — use the
  /// copy-on-write methods ([withTag], [without], [toggle]) to change it.
  final Set<String> tags;

  bool get isEmpty => tags.isEmpty;

  bool contains(String tagId) => tags.contains(tagId);

  factory UserInterests.fromDb(Object? value) {
    if (value == null) return UserInterests.empty;
    if (value is List) {
      return UserInterests(
        value.map((e) => e.toString()).toSet(),
      );
    }
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return UserInterests(
          decoded.map((e) => e.toString()).toSet(),
        );
      }
    }
    throw FormatException('Unsupported interest_tags DB value: $value');
  }

  /// JSON array literal for PostgREST `text[]` writes, ids sorted.
  String toDb() {
    final sorted = tags.toList()..sort();
    return jsonEncode(sorted);
  }

  UserInterests withTag(String tagId) =>
      UserInterests(<String>{...tags, tagId});

  UserInterests without(String tagId) =>
      UserInterests(<String>{...tags}..remove(tagId));

  UserInterests toggle(String tagId) =>
      contains(tagId) ? without(tagId) : withTag(tagId);

  @override
  bool operator ==(Object other) =>
      other is UserInterests && setEquals(tags, other.tags);

  @override
  int get hashCode => Object.hashAllUnordered(tags);

  @override
  String toString() => 'UserInterests(${toDb()})';
}

/// Multi-select tag picker (PRFL "interest tags" gap — I-36 foundation).
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
