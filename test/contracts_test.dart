import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:samay/core/models/event.dart';
import 'package:samay/core/models/group.dart';
import 'package:samay/core/models/group_theme.dart';
import 'package:samay/core/models/user_profile.dart';

/// Validates the shared E0 fixtures in `../backend/test/contracts` against the
/// same frozen key set the Go server checks. Skipped when the backend checkout
/// is not a sibling (the repos are consumed separately in release builds).
void main() {
  final dir = Directory('../backend/test/contracts');

  test('contract fixtures match the frozen wire shapes', () {
    if (!dir.existsSync()) {
      markTestSkipped('backend contract fixtures not present at ${dir.path}');
      return;
    }
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.contract.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);

    for (final file in files) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final name = json['name'] as String;
      final fields = (json['fields'] as Map?)?.cast<String, String>() ?? {};
      final enums = (json['enums'] as Map?) ?? {};
      final samples = (json['samples'] as List?) ?? [];

      if (fields.isNotEmpty) {
        expect(samples, isNotEmpty, reason: '$name has no samples');
        for (final raw in samples) {
          final sample = (raw as Map).cast<String, dynamic>();
          expect(
            sample.keys.toSet(),
            fields.keys.toSet(),
            reason: '$name sample must have exactly the frozen fields',
          );
          for (final entry in fields.entries) {
            final value = sample[entry.key];
            _checkType(name, entry.key, entry.value, value);
            final allowed = enums[entry.key] as List?;
            if (value != null && allowed != null) {
              expect(allowed, contains(value), reason: '$name.${entry.key}');
            }
          }
        }
      }

      final codes = (json['codes'] as List?)?.cast<String>() ?? [];
      if (codes.isNotEmpty) {
        expect(codes.toSet().length, codes.length, reason: '$name duplicate code');
      }
      final http = (json['http'] as Map?)?.cast<String, int>() ?? {};
      for (final entry in http.entries) {
        expect(codes, contains(entry.key), reason: '$name unknown http code');
      }
    }
  });

  test('model decoders accept the frozen samples', () {
    if (!dir.existsSync()) {
      markTestSkipped('backend contract fixtures not present at ${dir.path}');
      return;
    }
    Map<String, dynamic> sample(String name) {
      final file = File('${dir.path}/$name.contract.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return (json['samples'] as List).first as Map<String, dynamic>;
    }

    expect(UserProfile.fromJson(sample('user_profile')).id, isNotEmpty);
    expect(Event.fromJson(sample('event')).id, isNotEmpty);
    expect(Group.fromJson(sample('group')).id, isNotEmpty);
    final theme = GroupTheme.fromJson(sample('group_theme'));
    expect(theme.groupId, isNotEmpty);
    expect(theme.palette, isNotEmpty);
    expect(theme.controlMode, 'everyone');

    final blocked = sample('direct_chat_blocked');
    expect(blocked['status'], 'blocked');
    expect(sample('direct_chat_ok')['chatId'], isNotEmpty);
  });
}

void _checkType(String fixture, String field, String expr, Object? value) {
  final types = expr.split('|').map((t) => t.trim()).toSet();
  if (value == null) {
    expect(types, contains('null'), reason: '$fixture.$field is non-null ($expr)');
    return;
  }
  final ok = switch (value) {
    String _ => types.contains('string') || types.contains('date'),
    bool _ => types.contains('boolean'),
    int _ => types.contains('integer') || types.contains('number'),
    double _ => types.contains('number'),
    Map _ => types.contains('object'),
    List _ => types.contains('array'),
    _ => false,
  };
  expect(ok, isTrue, reason: '$fixture.$field = $value is not $expr');
  if (value is String && types.contains('date')) {
    expect(DateTime.tryParse(value), isNotNull, reason: '$fixture.$field date');
  }
}
