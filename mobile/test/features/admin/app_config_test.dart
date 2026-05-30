import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/features/admin/data/models/app_config.dart';

void main() {
  group('AppConfig.fromJson', () {
    test('reads snake_case fields', () {
      final c = AppConfig.fromJson({
        'ads_enabled': false,
        'requests_enabled': false,
        'ads_every_n_events': 3,
        'requests_every_n_events': 7,
        'comments_enabled': false,
        'min_campaign_budget_ghs': 50,
      });
      expect(c.adsEnabled, isFalse);
      expect(c.requestsEnabled, isFalse);
      expect(c.adsEveryNEvents, 3);
      expect(c.requestsEveryNEvents, 7);
      expect(c.commentsEnabled, isFalse);
      expect(c.minCampaignBudgetGhs, 50.0);
    });

    test('unwraps a nested data envelope', () {
      final c = AppConfig.fromJson({
        'data': {'ads_enabled': false, 'min_campaign_budget_ghs': 99},
      });
      expect(c.adsEnabled, isFalse);
      expect(c.minCampaignBudgetGhs, 99.0);
    });

    test('falls back to defaults on missing keys', () {
      final c = AppConfig.fromJson({});
      expect(c.adsEnabled, isTrue);
      expect(c.requestsEnabled, isTrue);
      expect(c.adsEveryNEvents, 10);
      expect(c.requestsEveryNEvents, 20);
      expect(c.commentsEnabled, isTrue);
      expect(c.minCampaignBudgetGhs, 30.0);
    });
  });

  test('toJson round-trips through fromJson', () {
    const original = AppConfig(
      adsEnabled: false,
      requestsEnabled: true,
      adsEveryNEvents: 4,
      requestsEveryNEvents: 8,
      commentsEnabled: false,
      minCampaignBudgetGhs: 75,
    );
    final restored = AppConfig.fromJson(original.toJson());
    expect(restored.adsEnabled, original.adsEnabled);
    expect(restored.adsEveryNEvents, original.adsEveryNEvents);
    expect(restored.requestsEveryNEvents, original.requestsEveryNEvents);
    expect(restored.commentsEnabled, original.commentsEnabled);
    expect(restored.minCampaignBudgetGhs, original.minCampaignBudgetGhs);
  });

  test('copyWith overrides only the given fields', () {
    const c = AppConfig();
    final updated = c.copyWith(adsEnabled: false, adsEveryNEvents: 2);
    expect(updated.adsEnabled, isFalse);
    expect(updated.adsEveryNEvents, 2);
    // untouched
    expect(updated.requestsEnabled, c.requestsEnabled);
    expect(updated.minCampaignBudgetGhs, c.minCampaignBudgetGhs);
  });
}
