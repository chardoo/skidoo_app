/// When returning to the Found tab asks the server again, and when it does not.
///
/// Tapping Found refetched the whole list every single time. The activation
/// hook exists to re-resolve the *gate* — somebody may have deleted their face
/// on another device, and the tab lives in the home IndexedStack for the whole
/// session so nothing else would ever ask — but that check shared a method
/// with the fetch and dragged a round trip along behind it. At roughly 280ms
/// each, that is a visible reload of a list that had not moved.
///
/// Asserted against the source. The behaviour is a decision taken across
/// `didChangeDependencies`, a bloc dispatch and two listeners; driving it
/// needs a signed-in session, a service locator and a network layer, none of
/// which is where the bug was. What the bug was is one method doing two jobs.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const feed = 'lib/features/gallery/presentation/found/found_feed.dart';
  final source = File(feed).readAsStringSync();

  /// The file with doc comments stripped — several of them quote the old
  /// behaviour to explain why it changed.
  final code = source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  group('a visit to the tab', () {
    test('re-resolves the gate', () {
      // This half must stay. It is cheap, local, and the only thing that
      // notices a face deleted somewhere else.
      expect(code, contains('_checkAccess()'));
      expect(code, contains('TickerMode.valuesOf(context).enabled'));
    });

    test('does not fetch unless something changed', () {
      // The guard, and the three things that are a real reason to ask again.
      expect(code, contains('_needsFetch'));
      expect(code, contains('_fetchedFor == null'));
      expect(code, contains('_fetchedFor != access'));
      expect(code, contains('_fetchedRevision'));
    });

    test('the activation hook does not dispatch a fetch of its own', () {
      // Everything between `didChangeDependencies` and the end of `dispose`.
      final start = code.indexOf('void didChangeDependencies()');
      final end = code.indexOf('Future<void> _checkAccess(');
      expect(start, isNot(-1));
      expect(end, greaterThan(start));
      final activation = code.substring(start, end);

      expect(activation, isNot(contains('FoundPhotosRequested')));
      expect(activation, isNot(contains('_reload(')));
    });
  });

  group('what still refetches', () {
    test('a scan that wrote new rows', () {
      // Making the blanket refresh conditional means subscribing to the thing
      // it was accidentally covering: a live search bumps this signal, and
      // nothing in this tab was listening to it.
      expect(code, contains('AppCacheSignals.foundPhotos.addListener'));
      expect(code, contains('AppCacheSignals.foundPhotos.removeListener'));
      expect(code, contains('_onFoundPhotosChanged'));
    });

    test('and the listener is removed again', () {
      final start = code.indexOf('void dispose()');
      final end = code.indexOf('}', code.indexOf('super.dispose()'));
      final dispose = code.substring(start, end);
      expect(dispose, contains('foundPhotos.removeListener'));
      expect(dispose, contains('hasAddedFaces.removeListener'));
    });

    test('pull-to-refresh and the review screen ask directly', () {
      // `_reload()` with no argument is unconditional, which is what these
      // want: somebody who pulled the list down is asking for a round trip.
      expect(code, contains('onRefresh:'));
      expect(code, contains('_reload();'));
    });

    test('enrolling or deleting a face moves the gate', () {
      expect(code, contains('AuthService.hasAddedFaces.addListener'));
    });
  });

  group('one question, one round trip', () {
    test('a finished scan does not fetch twice', () {
      // It used to re-resolve access (which fetched) and then fetch again, so
      // every scan paid for two round trips to ask one question.
      final start = code.indexOf('Future<void> _scanCode(');
      final end = code.indexOf('Future<void> _openFilters(');
      expect(start, isNot(-1));
      expect(end, greaterThan(start));
      final scan = code.substring(start, end);

      expect(scan, contains('_checkAccess(force: true)'));
      // The second dispatch is gone.
      expect(scan, isNot(contains('_reload();')));
    });

    test('the revision is recorded before the request, not after', () {
      // A bump landing while a fetch is in flight must not be mistaken for one
      // that fetch covered.
      final start = code.indexOf('void _reload(');
      final body = code.substring(start, code.indexOf('}', start));
      expect(
        body.indexOf('_fetchedRevision'),
        lessThan(body.indexOf('FoundPhotosRequested')),
      );
    });
  });
}
