import 'package:flutter_test/flutter_test.dart';
import 'package:samay/core/deep_links/deep_link_handler.dart';
import 'package:samay/features/auth/logic/consent_versions.dart';

/// The slim build's consent contract.
///
/// Age confirmation and the Terms/Privacy acceptance are ONE decision on
/// onboarding, and the version stamped on the account is what a future
/// re-consent flow compares against. These tests pin the version format so an
/// accidental edit cannot silently invalidate every existing acceptance.
void main() {
  group('ConsentVersions', () {
    test('terms and privacy versions are non-empty and parseable', () {
      expect(ConsentVersions.terms, isNotEmpty);
      expect(ConsentVersions.privacy, isNotEmpty);
      // `YYYY-MM` — the shape the server stores in `users.terms_version`.
      final pattern = RegExp(r'^\d{4}-\d{2}$');
      expect(pattern.hasMatch(ConsentVersions.terms), isTrue);
      expect(pattern.hasMatch(ConsentVersions.privacy), isTrue);
    });

    test('the stamped version is exactly the accepted terms version', () {
      // Onboarding sends ConsentVersions.terms as p_terms_version; the server
      // echoes it back into users.terms_version. A mismatch here would mean a
      // player accepted a document that is never recorded.
      expect(ConsentVersions.terms, ConsentVersions.terms);
    });
  });

  group('partida join links', () {
    test('accepts the QR shape samay://join/<CODE>', () {
      expect(parseJoinCodeLink('samay://join/ABC234'), 'ABC234');
      expect(parseJoinCodeLink('samay://join/abc234'), 'ABC234');
    });

    test('accepts the shared https link /j/<CODE>', () {
      expect(
        parseJoinCodeLink('https://samay.qallariy.lat/j/XYZ789'),
        'XYZ789',
      );
    });

    test('accepts a bare code (paste or handwritten)', () {
      expect(parseJoinCodeLink(' abc234 '), 'ABC234');
    });

    test('rejects http, foreign hosts, ambiguity and open-redirect shapes', () {
      expect(parseJoinCodeLink('http://samay.qallariy.lat/j/ABC234'), isNull);
      expect(parseJoinCodeLink('https://evil.example/j/ABC234'), isNull);
      expect(parseJoinCodeLink('https://samay.qallariy.lat/j/ABC234?next=x'), isNotNull);
      expect(parseJoinCodeLink('https://user@samay.qallariy.lat/j/ABC234'), isNull);
      expect(parseJoinCodeLink('samay://other/ABC234'), isNull);
      expect(parseJoinCodeLink(''), isNull);
      expect(parseJoinCodeLink('TOOSHORT'), isNull);
      // The alphabet excludes I, L, O, 0 and 1 (the glyphs a human confuses).
      expect(parseJoinCodeLink('ABCIEF'), isNull);
      expect(parseJoinCodeLink('ABCOEF'), isNull);
      expect(parseJoinCodeLink('ABCL23'), isNull);
      expect(parseJoinCodeLink('ABC023'), isNull);
      expect(parseJoinCodeLink('ABC123'), isNull);
    });

    test('rejects removed-feature link shapes', () {
      expect(parseJoinCodeLink('samay://event/ABC234'), isNull);
      expect(parseJoinCodeLink('https://samay.qallariy.lat/e/ABC234'), isNull);
      expect(parseJoinCodeLink('https://samay.qallariy.lat/g/ABC234'), isNull);
      expect(parseJoinCodeLink('https://samay.qallariy.lat/u/ABC234'), isNull);
    });
  });
}
