import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Immutable value object for a user's interest-tag selection (PRFL gap
/// foundation).
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
