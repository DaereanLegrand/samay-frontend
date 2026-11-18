/// One human seat at a single-device ("pass the phone") match.
///
/// A local match has no server session and no accounts: every participant is
/// either the device owner (`isGuest == false`) or a guest typed in by the
/// host. [id] is generated once per seat and never reused for another player in
/// the same match.
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

@immutable
class LocalPlayer {
  const LocalPlayer({
    required this.id,
    required this.name,
    this.isGuest = false,
  });

  /// The longest name the pass-the-phone UI renders on one line.
  static const int maxNameLength = 24;

  static const Uuid _uuid = Uuid();

  /// Builds a seat from a display [name], trimming it and clamping it to
  /// [maxNameLength]. Blank names are rejected — the caller must prompt the
  /// host for a real name instead of rendering an empty chip.
  ///
  /// A supplied [id] is kept verbatim (restoring a roster); otherwise a
  /// random v4 UUID is generated for the seat.
  factory LocalPlayer.create(String name, {bool isGuest = false, String? id}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    final clamped = trimmed.length > maxNameLength
        ? trimmed.substring(0, maxNameLength)
        : trimmed;
    final generated = id ?? _uuid.v4();
    return LocalPlayer(id: generated, name: clamped, isGuest: isGuest);
  }

  final String id;
  final String name;
  final bool isGuest;

  LocalPlayer copyWith({String? id, String? name, bool? isGuest}) {
    return LocalPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      isGuest: isGuest ?? this.isGuest,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalPlayer &&
        other.id == id &&
        other.name == name &&
        other.isGuest == isGuest;
  }

  @override
  int get hashCode => Object.hash(id, name, isGuest);

  @override
  String toString() => 'LocalPlayer($id, $name, guest: $isGuest)';
}
