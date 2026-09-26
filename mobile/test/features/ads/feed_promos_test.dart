import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/presentation/feed_promos.dart';

/// What a boost buys, past the top of the board — and what it does not.
///
/// The sheet sells "appear at the top of photographer feeds" and "priority
/// placement in discovery". A boost therefore decides *which* request is dealt
/// and how soon: boosted ones come first, so on a scroll that only ever
/// reaches two or three request slots, they are the ones seen.
///
/// It does not buy the same card twice. It used to: boosted requests took
/// every other slot and cycled, and once the unboosted ran out they took every
/// slot — so a board with one boosted request showed that request over and
/// over down a single scroll. Reach across sessions is what a campaign buys
/// and what pacing is for; volume inside one scroll is just the same card
/// again.
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
  test('the board is dealt in order, once each', () {
    // A slot past the end holds nothing rather than wrapping.
    final pool = [req('a'), req('b'), req('c')];

    expect(deal(pool, 5), ['a', 'b', 'c', '—', '—']);
  });

  test('boosted requests come first, and still only once', () {
    final pool = [req('a'), req('boost', boosted: true), req('b')];

    expect(deal(pool, 5), ['boost', 'a', 'b', '—', '—']);
  });

  test('two boosted requests are both dealt before the rest', () {
    final pool = [
      req('a'),
      req('b1', boosted: true),
      req('b2', boosted: true),
    ];

    expect(deal(pool, 4), ['b1', 'b2', 'a', '—']);
  });

  test('a single boosted request does not fill the feed with itself', () {
    // The reported bug, at its smallest: one boosted request and nothing else
    // on the board used to mean that card in every request slot.
    final pool = [req('boost', boosted: true)];

    expect(deal(pool, 4), ['boost', '—', '—', '—']);
  });

  test('an all-boosted board is still dealt once each', () {
    final pool = [req('b1', boosted: true), req('b2', boosted: true)];

    expect(deal(pool, 4), ['b1', 'b2', '—', '—']);
  });

  test('what another feed already showed is not dealt again', () {
    // "Once per launch" spans both feeds and every refresh: the ledger is what
    // Explore and Following both read, so swapping between them does not deal
    // the board from the top again.
    final pool = [req('b1', boosted: true), req('a'), req('b')];

    expect(
      [for (var i = 0; i < 3; i++) requestInSlot(pool, i, seen: {'b1'})?.id ?? '—'],
      ['a', 'b', '—'],
    );
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
