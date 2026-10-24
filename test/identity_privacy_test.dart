import 'package:flutter_test/flutter_test.dart';
import 'package:samay/core/models/user_search_result.dart';
import 'package:samay/features/auth/logic/age_policy.dart';
import 'package:samay/features/social/providers/social_providers.dart';

void main() {
  group('Q17 age policy', () {
    final now = DateTime(2026, 10, 23);

    test('18th birthday today is adult; tomorrow is not', () {
      expect(isAdult(DateTime(2008, 10, 23), now: now), isTrue);
      expect(isAdult(DateTime(2008, 10, 24), now: now), isFalse);
      expect(isAdult(null, now: now), isFalse);
      expect(isAdult(DateTime(2030, 1, 1), now: now), isFalse);
    });

    test('leap-day boundary is calendar-accurate', () {
      expect(isAdult(DateTime(2008, 2, 29), now: DateTime(2026, 2, 28)),
          isFalse);
      expect(isAdult(DateTime(2008, 2, 29), now: DateTime(2026, 3, 1)), isTrue);
    });

    test('signup guard rejects missing, malformed, and underage DOB', () {
      expect(signupDobError(null, now: now), 'required');
      expect(signupDobError('', now: now), 'required');
      expect(signupDobError('not-a-date', now: now), 'invalid');
      expect(signupDobError('2008-10-24', now: now), 'underage');
      expect(signupDobError('2008-10-23', now: now), isNull);
    });
  });

  group('Q8 private-profile projections', () {
    test('ranking row carries the opt-in flag', () {
      final publicRow = UserRankingEntry.fromRow({
        'user_id': 'u1',
        'username': 'smoke1',
        'avatar_url': null,
        'personal_shards': 10,
        'profile_public': true,
      });
      expect(publicRow.profilePublic, isTrue);
      expect(publicRow.username, 'smoke1');
    });

    test('search rows never expose bio and may carry a null avatar', () {
      final row = UserSearchResult.fromJson({
        'id': 'u1',
        'username': 'privateuser',
        'avatar_url': null,
      });
      expect(row.username, 'privateuser');
      expect(row.avatarUrl, isNull);
    });
  });
}
