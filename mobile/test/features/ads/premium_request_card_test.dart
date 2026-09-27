import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';

/// What a request card calls itself.
///
/// A request posted as premium-only is a different offer from an ordinary one:
/// the requester asked for somebody who has promised a delivery window, and
/// only members can answer it. Labelling both "Photographer Request" hides the
/// only reason a member is being shown that card — which is exactly how it
/// shipped, because the flag reached the board's *filter* without ever
/// reaching the card's *words*.
///
/// The tier's name is served rather than written into the app. It is still
/// being decided, and a build that hardcoded it would label a card one thing
/// while the rest of the app said another.
void main() {
  Map<String, dynamic> request({bool premiumOnly = false}) => {
        'id': 'r1',
        'requester_id': 'u1',
        'requester_name': 'Ama',
        'requester_type': 'client',
        'title': 'Wedding at Labadi',
        'description': 'Full day',
        'event_type': 'wedding',
        'location': 'Accra',
        'premium_only': premiumOnly,
      };

  Map<String, dynamic> config({String? name, bool enabled = true}) => {
        'data': {
          'premium': {
            if (name != null) 'name': name,
            'enabled': enabled,
          },
        },
      };

  /// What the pill would read, given a request and the tier's settings.
  ///
  /// Mirrors the expression in `feed_item_card.dart`. Kept here rather than
  /// pumping the whole card because the card needs a media pipeline, a bloc
  /// and a screen to build — and the thing worth pinning is the sentence, not
  /// the pixels.
  String pill(FeedRequestModel req, AppConfig cfg) =>
      req.premiumOnly && cfg.premiumEnabled
          ? '${cfg.premiumName} Request'
          : 'Photographer Request';

  group('reading the request', () {
    test('a premium request says so', () {
      expect(FeedRequestModel.fromJson(request(premiumOnly: true)).premiumOnly,
          isTrue);
    });

    test('an ordinary one does not', () {
      expect(FeedRequestModel.fromJson(request()).premiumOnly, isFalse);
    });

    test('a server too old to send the flag is read as ordinary', () {
      final json = request()..remove('premium_only');
      expect(FeedRequestModel.fromJson(json).premiumOnly, isFalse);
    });
  });

  group('what the card calls it', () {
    test('a premium request is named for the tier', () {
      // The bug this file exists for: the card read "Photographer Request"
      // even though the requester had asked for a member.
      final label = pill(
        FeedRequestModel.fromJson(request(premiumOnly: true)),
        AppConfig.fromJson(config(name: 'Jperger')),
      );
      expect(label, 'Jperger Request');
    });

    test('renaming the tier renames the card', () {
      final label = pill(
        FeedRequestModel.fromJson(request(premiumOnly: true)),
        AppConfig.fromJson(config(name: 'Skiddo Pro')),
      );
      expect(label, 'Skiddo Pro Request');
    });

    test('an ordinary request is unchanged', () {
      // The whole feature is an add-on. A request nobody asked a promise for
      // reads exactly as it always did.
      final label = pill(
        FeedRequestModel.fromJson(request()),
        AppConfig.fromJson(config(name: 'Jperger')),
      );
      expect(label, 'Photographer Request');
    });

    test('a request that fell back stops claiming to be premium', () {
      // The board clears `premium_only` when it opens an unanswered request to
      // everybody, so the card must stop making a claim that is no longer
      // true — the same flag drives both.
      final label = pill(
        FeedRequestModel.fromJson(request(premiumOnly: false)),
        AppConfig.fromJson(config(name: 'Jperger')),
      );
      expect(label, 'Photographer Request');
    });

    test('switching the tier off takes the name off the cards', () {
      // Winding the feature down should not leave cards advertising a tier
      // nobody can join or answer.
      final label = pill(
        FeedRequestModel.fromJson(request(premiumOnly: true)),
        AppConfig.fromJson(config(name: 'Jperger', enabled: false)),
      );
      expect(label, 'Photographer Request');
    });

    test('a server that sends no name still reads sensibly', () {
      final label = pill(
        FeedRequestModel.fromJson(request(premiumOnly: true)),
        AppConfig.fromJson(config()),
      );
      expect(label, 'Premium Request');
    });
  });
}
