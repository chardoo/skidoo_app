import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/features/ads/models/ad_campaign.dart';

AdCampaign _campaign({double budget = 100, double spent = 0}) => AdCampaign(
      id: 'c1',
      advertiserId: 'a1',
      advertiserType: 'photographer',
      name: 'Promo',
      objective: CampaignObjective.awareness,
      budgetAmount: budget,
      spent: spent,
      currency: 'GHS',
      status: CampaignStatus.active,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
    );

void main() {
  group('AdCampaign computed budget getters', () {
    test('spentPercent is the spent/budget ratio clamped to 0..1', () {
      expect(_campaign(budget: 100, spent: 25).spentPercent, 0.25);
      expect(_campaign(budget: 100, spent: 150).spentPercent, 1.0);
      expect(_campaign(budget: 0, spent: 50).spentPercent, 0.0);
    });

    test('remaining never goes negative or above budget', () {
      expect(_campaign(budget: 100, spent: 30).remaining, 70);
      expect(_campaign(budget: 100, spent: 250).remaining, 0);
    });
  });

  group('AdCampaign.fromJson', () {
    test('parses required fields and accepts spent/amount_spent aliases', () {
      final c = AdCampaign.fromJson({
        'id': 'c9',
        'name': 'Launch',
        'budget_amount': 500,
        'amount_spent': 120,
        'status': 'active',
        'objective': 'traffic',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
      });
      expect(c.id, 'c9');
      expect(c.budgetAmount, 500.0);
      expect(c.spent, 120.0);
      expect(c.status, CampaignStatus.active);
      expect(c.objective, CampaignObjective.traffic);
      expect(c.currency, 'GHS');
    });

    test('synthesizes a single AdMedia from a cover URL fallback', () {
      final c = AdCampaign.fromJson({
        'id': 'c9',
        'name': 'Launch',
        'budget_amount': 500,
        'status': 'draft',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
        'thumbnail_url': 'https://x/cover.jpg',
      });
      expect(c.media, hasLength(1));
      expect(c.media.first.url, 'https://x/cover.jpg');
      expect(c.media.first.mediaType, 'image');
    });
  });

  group('CampaignStatus', () {
    test('fromString maps known values and defaults to draft', () {
      expect(CampaignStatus.fromString('pending_payment'), CampaignStatus.pendingPayment);
      expect(CampaignStatus.fromString('active'), CampaignStatus.active);
      expect(CampaignStatus.fromString('garbage'), CampaignStatus.draft);
    });

    test('action permissions follow the status', () {
      expect(CampaignStatus.draft.canPay, isTrue);
      expect(CampaignStatus.draft.canDelete, isTrue);
      expect(CampaignStatus.active.canPause, isTrue);
      expect(CampaignStatus.active.canResume, isFalse);
      expect(CampaignStatus.paused.canResume, isTrue);
      expect(CampaignStatus.paused.canTopup, isTrue);
      expect(CampaignStatus.completed.isEditable, isFalse);
      expect(CampaignStatus.active.isEditable, isTrue);
    });
  });

  group('CampaignObjective', () {
    test('fromString handles aliases and defaults to awareness', () {
      expect(CampaignObjective.fromString('traffic'), CampaignObjective.traffic);
      expect(CampaignObjective.fromString('conversions'), CampaignObjective.conversion);
      expect(CampaignObjective.fromString('conversion'), CampaignObjective.conversion);
      expect(CampaignObjective.fromString('???'), CampaignObjective.awareness);
    });

    test('value matches the serialized form', () {
      expect(CampaignObjective.awareness.value, 'awareness');
      expect(CampaignObjective.traffic.value, 'traffic');
      expect(CampaignObjective.conversion.value, 'conversion');
    });
  });
}
