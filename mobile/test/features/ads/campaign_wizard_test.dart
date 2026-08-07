import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/ads/models/ad_campaign.dart';
import 'package:jperg_app/features/ads/presentation/pages/campaign_wizard_page.dart';

/// The wizard's rules, away from the widgets that render them.
///
/// Every one of these is also enforced by the server — the format's media
/// count, the objective names, the budget arithmetic — so a disagreement here
/// shows up as a submission the user cannot explain being refused.
void main() {
  group('format decides how many files', () {
    test('the ranges match what the server will accept', () {
      expect(CampaignFormat.image.mediaRange, (1, 1));
      expect(CampaignFormat.carousel.mediaRange, (2, 3));
      expect(CampaignFormat.video.mediaRange, (1, 1));
    });

    test('three is the most any format takes', () {
      for (final format in CampaignFormat.values) {
        expect(format.mediaRange.$2, lessThanOrEqualTo(3));
      }
    });
  });

  group('objectives survive the round trip', () {
    test('every objective the wizard offers parses back to itself', () {
      for (final objective in CampaignObjective.values) {
        expect(CampaignObjective.fromString(objective.value), objective);
      }
    });

    test('the retired name still resolves', () {
      // "conversion" is on live rows. Falling back to awareness would
      // silently relabel somebody's campaign.
      expect(CampaignObjective.fromString('conversion'),
          CampaignObjective.leads);
    });

    test('the four the design names are all present', () {
      expect(
        CampaignObjective.values.map((o) => o.label),
        containsAll([
          'Brand Awareness',
          'Drive Traffic',
          'Get Leads',
          'Promote Services',
        ]),
      );
    });
  });

  group('budget arithmetic', () {
    CampaignDraft draftWith({
      required BudgetMode mode,
      required String amount,
      required String days,
    }) {
      final d = CampaignDraft()
        ..budgetMode = mode
        ..budget.text = amount
        ..duration.text = days;
      return d;
    }

    test('a daily budget derives the total the review card shows', () {
      final d = draftWith(mode: BudgetMode.daily, amount: '50', days: '14');
      expect(d.derived, 700);
    });

    test('a total budget derives the daily figure', () {
      final d = draftWith(mode: BudgetMode.total, amount: '700', days: '14');
      expect(d.derived, 50);
    });

    test('a zero duration derives nothing rather than dividing by it', () {
      final d = draftWith(mode: BudgetMode.total, amount: '700', days: '0');
      expect(d.derived, 0);
    });

    test('junk in the field is zero, not a crash', () {
      final d = draftWith(mode: BudgetMode.daily, amount: 'abc', days: 'x');
      expect(d.budgetValue, 0);
      expect(d.durationValue, 0);
      expect(d.derived, 0);
    });
  });

  group('a step is done when its required fields are', () {
    CampaignDraft filled() => CampaignDraft()
      ..headline.text = 'Book Your Perfect Photoshoot'
      ..copy.text = 'Professional photography.'
      ..ctaText.text = 'Book Now'
      ..ctaUrl.text = 'https://mystudio.com/booking';

    test('creative needs the image count its format demands', () {
      final d = filled()..format = CampaignFormat.image;
      expect(d.creativeDone, isFalse, reason: 'no image yet');
    });

    test('a carousel is not done with one image', () {
      final d = filled()..format = CampaignFormat.carousel;
      expect(d.creativeDone, isFalse);
    });

    test('audience needs a location and somewhere to run', () {
      final d = CampaignDraft();
      expect(d.audienceDone, isFalse, reason: 'no location chosen');
      d.locations.add('Accra');
      expect(d.audienceDone, isTrue);
      d.placements.clear();
      expect(d.audienceDone, isFalse, reason: 'nowhere to place it');
    });

    test('budget needs an amount, a duration and dates in order', () {
      final d = CampaignDraft()
        ..budget.text = '50'
        ..duration.text = '14';
      expect(d.budgetDone, isFalse, reason: 'no dates');

      d.startDate = DateTime(2026, 8, 15);
      d.endDate = DateTime(2026, 8, 29);
      expect(d.budgetDone, isTrue);

      d.endDate = DateTime(2026, 8, 1);
      expect(d.budgetDone, isFalse, reason: 'ends before it starts');
    });
  });

  group('status drives what the details screen offers', () {
    test('an approved-unpaid campaign can be paid for', () {
      expect(CampaignStatus.approvedUnpaid.canPay, isTrue);
      expect(CampaignStatus.active.canPay, isFalse);
    });

    test('only a queued campaign can be withdrawn', () {
      expect(CampaignStatus.pendingReview.canWithdraw, isTrue);
      expect(CampaignStatus.draft.canWithdraw, isFalse);
      expect(CampaignStatus.active.canWithdraw, isFalse);
    });

    test('a lapsed campaign can go again; a live one cannot', () {
      expect(CampaignStatus.paymentExpired.canSubmit, isTrue);
      expect(CampaignStatus.rejected.canSubmit, isTrue);
      expect(CampaignStatus.draft.canSubmit, isTrue);
      expect(CampaignStatus.active.canSubmit, isFalse);
      expect(CampaignStatus.pendingReview.canSubmit, isFalse);
    });

    test('the pills read as the design labels them', () {
      expect(CampaignStatus.pendingReview.label, 'In Review');
      expect(CampaignStatus.approvedUnpaid.label, 'Unpaid');
      expect(CampaignStatus.completed.label, 'Closed');
      expect(CampaignStatus.draft.label, 'Draft');
    });
  });

  group('the campaign a list row is built from', () {
    test('reads the new fields, and the aggregated counters', () {
      final c = AdCampaign.fromJson({
        'id': 'c1',
        'name': 'Wedding Season Promo',
        'objective': 'services',
        'format': 'carousel',
        'budget_amount': 700.0,
        'budget_mode': 'daily',
        'daily_budget': 50.0,
        'duration_days': 14,
        'spent': 0,
        'currency': 'GHS',
        'status': 'approved_unpaid',
        'headline': 'Book Your Perfect Photoshoot Today',
        'cta_text': 'Book Now',
        'payment_seconds_left': 3600,
        'impressions': 6000,
        'clicks': 94,
        'reach': 2000,
        'placements': ['event_feed', 'explore'],
        'createdAt': '2026-08-01T10:00:00Z',
        'updatedAt': '2026-08-01T10:00:00Z',
      });

      expect(c.objective, CampaignObjective.services);
      expect(c.format, CampaignFormat.carousel);
      expect(c.budgetMode, BudgetMode.daily);
      expect(c.dailyBudget, 50.0);
      expect(c.durationDays, 14);
      expect(c.status, CampaignStatus.approvedUnpaid);
      expect(c.paymentSecondsLeft, 3600);
      expect(c.reach, 2000);
      expect(c.clicks, 94);
      expect(c.placements, ['event_feed', 'explore']);
    });

    test('a campaign from before the redesign still parses', () {
      // Older rows carry none of the new keys. They must not blow up the list.
      final c = AdCampaign.fromJson({
        'id': 'old',
        'name': 'Legacy',
        'objective': 'awareness',
        'budget_amount': 100.0,
        'spent': 10.0,
        'currency': 'GHS',
        'status': 'active',
        'createdAt': '2026-05-01T10:00:00Z',
        'updatedAt': '2026-05-01T10:00:00Z',
      });
      expect(c.format, CampaignFormat.image, reason: 'a sane default');
      expect(c.dailyBudget, isNull);
      expect(c.paymentSecondsLeft, isNull);
      expect(c.reach, 0);
      expect(c.placements, isEmpty);
    });
  });

  _lifecycle();
  _editPrefill();
  _targetAge();
}

/// The lifecycle the details screen drives — pause, resume, duplicate — and the
/// numbers it shows.
void _lifecycle() {
  group('what a status allows', () {
    test('only a live campaign can be paused, only a paused one resumed', () {
      expect(CampaignStatus.active.canPause, isTrue);
      expect(CampaignStatus.paused.canPause, isFalse);
      expect(CampaignStatus.paused.canResume, isTrue);
      expect(CampaignStatus.active.canResume, isFalse);
    });

    test('a finished campaign can be run again', () {
      expect(CampaignStatus.completed.canDuplicate, isTrue);
      expect(CampaignStatus.paused.canDuplicate, isTrue);
      // A live one does not need duplicating; it needs leaving alone.
      expect(CampaignStatus.active.canDuplicate, isFalse);
      expect(CampaignStatus.draft.canDuplicate, isFalse);
    });
  });

  group('the performance summary', () {
    AdCampaign parse(Map<String, dynamic> extra) => AdCampaign.fromJson({
          'id': 'c1',
          'name': 'Promo',
          'objective': 'services',
          'budget_amount': 700.0,
          'spent': 350.0,
          'currency': 'GHS',
          'status': 'active',
          'createdAt': '2026-08-01T10:00:00Z',
          'updatedAt': '2026-08-01T10:00:00Z',
          ...extra,
        });

    test('reads the figures the four cards show', () {
      final c = parse({
        'impressions': 12400,
        'clicks': 512,
        'conversions': 94,
        'ctr': 4.1,
        'cost_per_conversion': 3.72,
        'impressions_trend_pct': 14.0,
      });
      expect(c.impressions, 12400);
      expect(c.clicks, 512);
      expect(c.conversions, 94);
      expect(c.ctr, 4.1);
      expect(c.costPerConversion, 3.72);
      expect(c.impressionsTrendPct, 14.0);
    });

    test('an unseen campaign has no CTR and no trend, rather than zeroes', () {
      // Zero would read as "nobody clicked" and "flat this week"; neither is
      // true of a campaign that has not run.
      final c = parse({'impressions': 0, 'clicks': 0});
      expect(c.ctr, isNull);
      expect(c.impressionsTrendPct, isNull);
      expect(c.costPerConversion, isNull);
    });

    test('a fall is carried as a negative, not dropped', () {
      expect(parse({'impressions_trend_pct': -8.5}).impressionsTrendPct, -8.5);
    });
  });

  group('lifecycle timestamps', () {
    test('paused and completed dates are read for the notices', () {
      final c = AdCampaign.fromJson({
        'id': 'c1',
        'name': 'Promo',
        'objective': 'awareness',
        'budget_amount': 700.0,
        'spent': 0,
        'currency': 'GHS',
        'status': 'paused',
        'paused_at': '2026-08-02T09:00:00Z',
        'completed_at': null,
        'duplicated_from_id': 'original-1',
        'createdAt': '2026-08-01T10:00:00Z',
        'updatedAt': '2026-08-01T10:00:00Z',
      });
      expect(c.pausedAt, isNotNull);
      expect(c.completedAt, isNull);
      expect(c.duplicatedFromId, 'original-1');
    });
  });
}

/// The edit form opens on what is already there. Opening on blanks and saving
/// would write the blanks back — which is what made this worth pinning.
void _editPrefill() {
  AdCampaign campaign(Map<String, dynamic> extra) => AdCampaign.fromJson({
        'id': 'c1',
        'name': 'Promo',
        'objective': 'services',
        'format': 'carousel',
        'budget_amount': 700.0,
        'budget_mode': 'daily',
        'daily_budget': 50.0,
        'duration_days': 14,
        'spent': 0,
        'currency': 'GHS',
        'status': 'draft',
        'headline': 'Book Your Perfect Photoshoot (Copy)',
        'createdAt': '2026-08-01T10:00:00Z',
        'updatedAt': '2026-08-01T10:00:00Z',
        ...extra,
      });

  group('the audience comes back off the campaign', () {
    test('locations, interests and audience are read', () {
      final c = campaign({
        'locations': ['Accra', 'Kumasi'],
        'interests': ['Weddings', 'Portraits'],
        'audience': 'creators',
      });
      expect(c.locations, ['Accra', 'Kumasi']);
      expect(c.interests, ['Weddings', 'Portraits']);
      expect(c.audience, 'creators');
    });

    test('a campaign without them defaults rather than throwing', () {
      final c = campaign({});
      expect(c.locations, isEmpty);
      expect(c.interests, isEmpty);
      expect(c.audience, 'all');
    });

    test('the chip lists the two screens offer are the same list', () {
      // The wizard and the edit form used to hold their own copies; a location
      // added to one and not the other is a filter nobody can clear.
      expect(kCampaignLocations, contains('Accra'));
      expect(kCampaignInterests, contains('Weddings'));
      expect(kCampaignLocations, isNotEmpty);
      expect(kCampaignInterests, isNotEmpty);
    });
  });

  group('media already on the campaign', () {
    test('is carried so the strip can show it', () {
      final c = campaign({
        'media': [
          {'id': 'm1', 'url': 'https://x/1.jpg', 'media_type': 'image'},
          {'id': 'm2', 'url': 'https://x/2.jpg', 'media_type': 'image'},
        ],
      });
      expect(c.media.length, 2);
      expect(c.media.first.id, 'm1');
    });

    test('a carousel with two images already satisfies its format', () {
      final c = campaign({
        'media': [
          {'id': 'm1', 'url': 'https://x/1.jpg', 'media_type': 'image'},
          {'id': 'm2', 'url': 'https://x/2.jpg', 'media_type': 'image'},
        ],
      });
      final (low, high) = c.format.mediaRange;
      expect(c.media.length >= low && c.media.length <= high, isTrue);
    });
  });
}

/// The audience card the design draws: Locations, Target Age, Interests.
///
/// The card rendered Placements and nothing else, and the age band was
/// collected by no screen at all — the repository would send it, the server
/// would store it, and nothing ever set it.
void _targetAge() {
  AdCampaign campaign(Map<String, dynamic> extra) => AdCampaign.fromJson({
        'id': 'c1',
        'name': 'Promo',
        'objective': 'services',
        'budget_amount': 700.0,
        'spent': 0,
        'currency': 'GHS',
        'status': 'active',
        'createdAt': '2026-08-01T10:00:00Z',
        'updatedAt': '2026-08-01T10:00:00Z',
        ...extra,
      });

  group('target age', () {
    test('reads the band and labels it the way the card shows it', () {
      final c = campaign({'age_min': 25, 'age_max': 55});
      expect(c.ageMin, 25);
      expect(c.ageMax, 55);
      expect(c.ageLabel, '25 – 55 years');
    });

    test('no band means no line, rather than "null – null years"', () {
      expect(campaign({}).ageLabel, isNull);
    });

    test('one end set still produces a readable band', () {
      expect(campaign({'age_min': 30}).ageLabel, '30 – 65 years');
      expect(campaign({'age_max': 40}).ageLabel, '13 – 40 years');
    });

    test('the wizard starts at the widest band it offers', () {
      // Narrowing an audience should be a decision, not something inherited
      // from a default nobody chose.
      final d = CampaignDraft();
      expect(d.ages.start, 18);
      expect(d.ages.end, 65);
    });
  });
}
