import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/photographers/data/premium_service.dart';

/// The premium tier's terms, as the app reads and renders them.
///
/// Every number on the rules page comes from the server — including the tier's
/// name, which is still being argued about. A build that shipped the word, or
/// the window, would render one thing while the server and the admin panel said
/// another, and the first anybody would notice is an argument with a creator
/// who has just been demoted over a rule they were shown differently.
void main() {
  Map<String, dynamic> terms({
    String? name,
    int hours = 48,
    int cooldown = 90,
    bool enabled = true,
  }) =>
      {
        if (name != null) 'name': name,
        'enabled': enabled,
        'joining_open': enabled,
        'delivery_hours': hours,
        'strike_limit': 2,
        'strike_window_days': 180,
        'cooldown_days': cooldown,
        'terms_version': 3,
      };

  group('reading the terms', () {
    test('the name comes from the server', () {
      expect(PremiumTerms.fromJson(terms(name: 'Jperger')).name, 'Jperger');
      expect(PremiumTerms.fromJson(terms(name: 'Skiddo Pro')).name, 'Skiddo Pro');
    });

    test('an empty name falls back rather than rendering nothing', () {
      // A blank badge label is worse than a generic one: the reader sees a
      // sentence with a hole in it.
      expect(PremiumTerms.fromJson(terms(name: '   ')).name, 'Premium');
      expect(PremiumTerms.fromJson(terms()).name, 'Premium');
    });

    test('a response missing everything still parses', () {
      // An older build meeting a newer server, or the other way round. The
      // screen should render the defaults rather than throw.
      final parsed = PremiumTerms.fromJson(const {});
      expect(parsed.deliveryHours, 48);
      expect(parsed.enabled, isFalse);
    });
  });

  group('saying the window out loud', () {
    test('48 hours stays hours, because that is how the rule is written', () {
      expect(PremiumTerms.fromJson(terms(hours: 48)).windowLabel, '48 hours');
    });

    test('a single day is hours too', () {
      // "1 day" invites the question "from when?", which the rule answers with
      // midnight. "24 hours" does not invite it.
      expect(PremiumTerms.fromJson(terms(hours: 24)).windowLabel, '24 hours');
    });

    test('longer windows become days, because nobody converts 72', () {
      expect(PremiumTerms.fromJson(terms(hours: 72)).windowLabel, '3 days');
      expect(PremiumTerms.fromJson(terms(hours: 168)).windowLabel, '7 days');
    });

    test('an odd window stays in hours rather than rounding', () {
      // Rounding 36 hours to "2 days" would state the promise as longer than
      // it is, on the screen where somebody agrees to it.
      expect(PremiumTerms.fromJson(terms(hours: 36)).windowLabel, '36 hours');
    });
  });

  group('saying the cooldown out loud', () {
    test('90 days is three months', () {
      expect(PremiumTerms.fromJson(terms(cooldown: 90)).cooldownLabel, '3 months');
    });

    test('30 days is a month', () {
      expect(PremiumTerms.fromJson(terms(cooldown: 30)).cooldownLabel, 'a month');
    });

    test('anything not a round month stays in days', () {
      expect(PremiumTerms.fromJson(terms(cooldown: 45)).cooldownLabel, '45 days');
    });
  });

  group('where this account stands', () {
    test('a member with no record yet has no score, which is not zero', () {
      // Zero out of a hundred says something false about a creator who simply
      // has not taken premium work yet.
      final status = PremiumStatus.fromJson({
        'terms': terms(),
        'member': true,
        'can_join': false,
        'needs_reaccept': false,
        'delivery': {'on_time': 0, 'late': 0, 'score': null},
      });

      expect(status.member, isTrue);
      expect(status.score, isNull);
    });

    test('a cooling-down account carries the date it may return', () {
      final status = PremiumStatus.fromJson({
        'terms': terms(),
        'member': false,
        'can_join': false,
        'needs_reaccept': false,
        'reason': 'cooling_down',
        'blocked_until': '2026-12-24T00:00:00Z',
      });

      expect(status.coolingDown, isTrue);
      expect(status.blockedUntil, isNotNull);
    });

    test('a member whose terms moved is still a member', () {
      // They are held to the version they agreed to, not thrown out of the
      // tier because an admin changed a number.
      final status = PremiumStatus.fromJson({
        'terms': terms(),
        'member': true,
        'can_join': false,
        'needs_reaccept': true,
      });

      expect(status.member, isTrue);
      expect(status.needsReaccept, isTrue);
    });
  });
}
