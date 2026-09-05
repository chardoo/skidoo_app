import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/presentation/feed_promos.dart';

/// What a boost buys, past the top of the board.
///
/// The sheet sells "appear at the top of photographer feeds" and "priority
/// placement in discovery". The server's ordering delivers the first half — a
/// boosted request is the first one dealt — and delivered the whole of it,
/// which meant a boost was one card in one scroll and then gone. This is the
/// other half: it comes back round.
FeedRequestModel req(String id, {bool boosted = false}) =>
    FeedRequestModel.fromJson({
      'id': id,
      'title': id,
      'is_boosted': boosted,
    });

List<String> deal(List<FeedRequestModel> pool, int slots) => [
      for (var i = 0; i < slots; i++) requestInSlot(pool, i)?.id ?? '—',
    ];

void main() {
  test('nothing boosted deals the board in order, once each', () {
    // The behaviour the feed had before boosts existed, unchanged: a slot past
    // the end of the list holds nothing rather than wrapping.
    final pool = [req('a'), req('b'), req('c')];

    expect(deal(pool, 5), ['a', 'b', 'c', '—', '—']);
  });

  test('a boosted request comes back round; the rest are dealt once', () {
    final pool = [req('boost', boosted: true), req('a'), req('b')];

    expect(deal(pool, 6), ['boost', 'a', 'boost', 'b', 'boost', 'boost']);
  });

  test('two boosted requests take turns rather than one hogging the rota', () {
    final pool = [
      req('b1', boosted: true),
      req('b2', boosted: true),
      req('a'),
    ];

    final dealt = deal(pool, 4);
    expect(dealt[0], 'b1');
    expect(dealt[1], 'a');
    expect(dealt[2], 'b2');
    // The unboosted one is spent, so the paid-for slots carry on.
    expect(dealt[3], 'b1');
  });

  test('an all-boosted board still fills every slot', () {
    final pool = [req('b1', boosted: true), req('b2', boosted: true)];

    expect(deal(pool, 4), ['b1', 'b2', 'b1', 'b2']);
  });

  test('an empty board fills nothing', () {
    expect(requestInSlot(const [], 0), isNull);
    expect(requestInSlot([req('a')], -1), isNull);
  });

  test('the following feed is quieter than Explore', () {
    // Same config, twice the gap between interruptions: the people you
    // followed are what you came to that feed for.
    final explore = FeedPromos(onChanged: () {});
    final following = FeedPromos(onChanged: () {}, intervalScale: 2);

    expect(following.requestsInterval, explore.requestsInterval * 2);
    expect(following.adsInterval, explore.adsInterval * 2);

    explore.dispose();
    following.dispose();
  });
}
