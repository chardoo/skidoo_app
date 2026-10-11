/// What `main` reads before it can draw anything.
///
/// The startup batch is a `Future.wait<Object?>` whose results are pulled back
/// out by hand-counted index — `results[0] as bool`, `results[1] as String`.
/// That is a shared mutable counter disguised as code, and it is edited by
/// whoever adds a thing to prime.
///
/// It broke exactly that way. Two entries were inserted into the middle of the
/// list, every index below them shifted by two, and `results[8] as bool` met
/// the null of a `Future<void>`. The throw landed in `main`, before `runApp`,
/// so the app painted nothing at all — a black screen with no second frame and
/// no error surface to show it on.
///
/// Nothing here can check that a *given* index still holds what its author
/// thought. What it can do is keep the blast radius from growing: the values
/// whose absence is fatal are read by name, not by position.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/main.dart').readAsStringSync();

  /// The batch, from the opening of `Future.wait` to its closing `]);`.
  String batch() {
    final start = source.indexOf('Future.wait<Object?>([');
    expect(start, isNot(-1), reason: 'the startup batch moved');
    final end = source.indexOf(']);', start);
    return source.substring(start, end);
  }

  group('the routing decision is read by name', () {
    test('the wizard marker is not pulled out by index', () {
      // This is the one that black-screened. A null cast to a non-nullable
      // type, in main, before runApp.
      expect(source, contains('await onboardingStepFuture'));
      expect(source, isNot(matches(RegExp(r'results\[\d+\] as OnboardingStep'))));
    });

    test('nor is the guest flag', () {
      expect(source, contains('await isGuestFuture'));
      // `results[N] as bool` is still used for two older flags, which is the
      // pattern this one left — it is pinned here so the two that decide the
      // first route cannot quietly rejoin it.
      final guestByIndex = RegExp(r'isGuest = results\[\d+\]');
      expect(source, isNot(matches(guestByIndex)));
    });

    test('both are still started before the batch, not after it', () {
      // The point of the batch is one round of storage reads on the stretch
      // where the screen is still the OS launch image. Awaiting these after it
      // would put them in series behind it.
      final started = source.indexOf('final onboardingStepFuture');
      final batchStart = source.indexOf('Future.wait<Object?>([');
      final awaited = source.indexOf('await onboardingStepFuture');

      expect(started, lessThan(batchStart), reason: 'started too late to overlap');
      expect(awaited, greaterThan(batchStart));
    });
  });

  group('the batch and its readers still agree', () {
    /// `lib/main.dart` with its comments removed.
    ///
    /// The scan below looks for `results[N]`, and the note explaining this
    /// very bug quotes `results[7]` and `results[8]` — so reading the raw file
    /// finds indices that no longer exist in the code.
    String code() => source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    /// How many entries the batch has.
    ///
    /// Counted by commas at the list's own depth rather than by line, because
    /// the first entry — the jailbreak probe — spans eight lines and a
    /// per-line count silently misses it, which makes the whole assertion
    /// weaker than it looks.
    int entryCount() {
      final list = batch().substring('Future.wait<Object?>(['.length);
      var depth = 0;
      var entries = 0;
      for (final rune in list.runes) {
        final char = String.fromCharCode(rune);
        if (char == '(' || char == '[' || char == '{') depth++;
        if (char == ')' || char == ']' || char == '}') depth--;
        if (char == ',' && depth == 0) entries++;
      }
      return entries;
    }

    test('the batch is longer than one line can tell', () {
      // Guards the counter itself: if this ever reads as a handful, the
      // depth tracking has broken and the assertion below means nothing.
      expect(entryCount(), greaterThanOrEqualTo(8));
    });

    test('every index read exists in the list', () {
      final entries = entryCount();
      final read = RegExp(r'results\[(\d+)\]')
          .allMatches(code())
          .map((m) => int.parse(m.group(1)!))
          .toList();

      expect(read, isNotEmpty, reason: 'the batch is read by index somewhere');
      for (final index in read) {
        expect(index, lessThan(entries),
            reason: 'results[$index] is past the end of a $entries-entry list');
      }
    });

    test('and nothing casts a void entry to a value', () {
      // `prime…()` returns Future<void>; its slot is null. The crash was
      // `null as bool` against one of those.
      for (final primed in ['primeRole', 'primeProfileUrl', 'primeName', 'primeUserId']) {
        expect(batch(), contains('$primed()'),
            reason: 'if this moved, the indices below it did too');
      }
    });
  });
}
