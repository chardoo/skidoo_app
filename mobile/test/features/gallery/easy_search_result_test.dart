import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/data/datasources/found_remote_data_source.dart';
import 'package:jperg_app/features/gallery/data/event_scan.dart';
import 'package:jperg_app/features/gallery/domain/repositories/found_repository.dart';
import 'package:jperg_app/features/gallery/domain/usecases/get_found_photos_usecase.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filters.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/event_scan_result_page.dart';
import 'package:jperg_app/services/auth_service.dart';

/// What the shared result screen says while an easy search is running.
///
/// Two signals were built into the search and left unrendered first time
/// round, and both matter for the same reason: this search has no index to
/// shortcut it, so on a large album the counters sit still for a long time
/// while real work happens, and it may not reach the end of the album at all.
///
/// A search driven entirely by hand — no HTTP — so the screen is the only
/// thing under test.
class _FakeSearch implements LiveSearch {
  @override
  final ValueNotifier<int> mineCount = ValueNotifier<int>(0);
  @override
  final ValueNotifier<int> publicCount = ValueNotifier<int>(0);
  @override
  final ValueNotifier<bool> isRunning = ValueNotifier<bool>(true);
  @override
  final ValueNotifier<Object?> error = ValueNotifier<Object?>(null);
  @override
  final ValueNotifier<String?> eventName = ValueNotifier<String?>(null);
  @override
  final ValueNotifier<({int processed, int total})?> progress =
      ValueNotifier<({int processed, int total})?>(null);
  @override
  final ValueNotifier<bool> truncated = ValueNotifier<bool>(false);

  bool started = false;
  bool cancelled = false;

  @override
  Future<void> start() async => started = true;

  @override
  void cancel() => cancelled = true;

  @override
  void dispose() {}
}

/// An empty Found album set — the screen looks the album up after the search
/// closes, and these tests are about what it says when there is nothing in it.
class _EmptyFoundRepository implements FoundRepository {
  @override
  Future<FoundAlbumsPage> getAlbums({
    FoundFilters filters = FoundFilters.none,
    int page = 1,
    int limit = 25,
    int previewLimit = 6,
  }) async =>
      const FoundAlbumsPage(
        albums: [],
        pagination: FoundPagination(),
        totalPhotos: 0,
        totalEvents: 0,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    if (!sl.isRegistered<Api>()) sl.registerSingleton<Api>(Api());
    if (!sl.isRegistered<GetFoundPhotosUseCase>()) {
      sl.registerSingleton<GetFoundPhotosUseCase>(
        GetFoundPhotosUseCase(_EmptyFoundRepository()),
      );
    }
    if (!sl.isRegistered<AuthService>()) {
      sl.registerSingleton<AuthService>(AuthService());
    }
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<_FakeSearch> pump(
    WidgetTester tester, {
    Future<void> Function(BuildContext)? onSearchComplete,
  }) async {
    // A phone-sized surface. The default test view is 800x600, shorter than
    // any device this ships to, and the scanning orb alone is 260 tall — the
    // overflow that causes is the harness, not the screen.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final search = _FakeSearch();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
          home: EventScanResultPage(
            code: 'CODE-1',
            createSearch: () => search,
            onSearchComplete: onSearchComplete,
          ),
        ),
      ),
    );
    await tester.pump();
    return search;
  }

  /// Lets the page's minimum-orb timer elapse. It runs for 1400ms so a fast
  /// search does not flash its result, and a test that ends before it fires
  /// leaves a pending timer the harness rightly complains about.
  ///
  /// Deliberately not `pumpAndSettle`: while the search is still running the
  /// scanning orb animates forever, and settling on it never returns.
  Future<void> drain(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 1500));

  /// Past the timer *and* through the album lookup that follows it — for the
  /// tests that let the search close and assert on the result state.
  Future<void> drainToResult(WidgetTester tester) async {
    await drain(tester);
    await tester.pump();
  }

  testWidgets('it starts the search it was given', (tester) async {
    final search = await pump(tester);
    expect(search.started, isTrue);
    await drain(tester);
  });

  testWidgets('before the server says, it just says it is working',
      (tester) async {
    await pump(tester);
    expect(find.text('Analyzing event photos'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('once the server reports progress, it shows how far',
      (tester) async {
    // The counts below only move when something is *found*. On an album this
    // person is barely in, this is the only line that moves.
    final search = await pump(tester);

    search.progress.value = (processed: 120, total: 400);
    await tester.pump();

    expect(find.text('Checked 120 of 400 photos'), findsOneWidget);
    expect(find.text('Analyzing event photos'), findsNothing);
    await drain(tester);
  });

  testWidgets('progress keeps up with the server', (tester) async {
    final search = await pump(tester);

    search.progress.value = (processed: 120, total: 400);
    await tester.pump();
    search.progress.value = (processed: 260, total: 400);
    await tester.pump();

    expect(find.text('Checked 260 of 400 photos'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('a capped search does not claim the person is absent',
      (tester) async {
    // "We didn't find you in this event" is the one sentence here that would
    // not be true, and it is the sentence that stops them trying again.
    final search = await pump(tester);
    search.truncated.value = true;
    search.isRunning.value = false;
    // Past the minimum orb time, so the result is allowed to show.
    await drainToResult(tester);

    expect(find.textContaining("didn't find you in this event"), findsNothing);
    expect(find.textContaining('This album is large'), findsOneWidget);
  });

  testWidgets('a complete search still says it looked everywhere',
      (tester) async {
    final search = await pump(tester);
    search.isRunning.value = false;
    await drainToResult(tester);

    expect(find.textContaining("didn't find you in this event"), findsOneWidget);
    expect(find.textContaining('This album is large'), findsNothing);
  });

  group('work that waits for the answer', () {
    // Saving the face is the *extra*; finding the photos is the errand. It used
    // to run before the search, which made somebody wait on an upload to learn
    // whether they were in the album at all.

    testWidgets('does not run while the search is still going', (tester) async {
      var ran = 0;
      await pump(tester, onSearchComplete: (_) async => ran++);

      await drain(tester);

      expect(ran, 0, reason: 'the search has not answered yet');
    });

    testWidgets('runs once the search closes', (tester) async {
      var ran = 0;
      final search = await pump(tester, onSearchComplete: (_) async => ran++);

      search.isRunning.value = false;
      await drainToResult(tester);

      expect(ran, 1);
    });

    testWidgets('does not wait on the orb\'s minimum', (tester) async {
      // The 1400ms hold is cosmetic — it makes a fast search read as work.
      // There is no reason for the follow-up to sit behind an animation.
      var ran = 0;
      final search = await pump(tester, onSearchComplete: (_) async => ran++);

      search.isRunning.value = false;
      await tester.pump();

      expect(ran, 1);
      await drainToResult(tester);
    });

    testWidgets('runs once, not again on retry', (tester) async {
      // Retry builds a fresh search. Enrolling again would upload the same
      // selfies twice.
      var ran = 0;
      final search = await pump(tester, onSearchComplete: (_) async => ran++);

      search.isRunning.value = false;
      await drainToResult(tester);
      search.isRunning.value = true;
      await tester.pump();
      search.isRunning.value = false;
      await drainToResult(tester);

      expect(ran, 1);
    });
  });
}
