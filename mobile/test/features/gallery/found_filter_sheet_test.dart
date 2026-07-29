import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/data/datasources/found_remote_data_source.dart';
import 'package:skidoo_app/features/gallery/domain/repositories/found_repository.dart';
import 'package:skidoo_app/features/gallery/domain/usecases/get_found_photos_usecase.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_filter_options.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_filters.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_filter_sheet.dart';

/// Serves a count per selection, after a controllable delay, so the in-flight
/// window can be inspected.
class _FakeRepo implements FoundRepository {
  _FakeRepo(this.countFor, {this.delay = const Duration(milliseconds: 100)});

  final int Function(FoundFilters) countFor;
  final Duration delay;
  final photographers = <FoundFilterOption>[
    const FoundFilterOption(id: 'ph-1', label: 'Daniella Daniels', count: 19),
    const FoundFilterOption(id: 'ph-2', label: 'Kofi Mensah', count: 7),
  ];

  /// Photographers the next response should expose; defaults to all.
  List<FoundFilterOption>? visiblePhotographers;

  /// Facet counts, keyed by api value. The server computes these over the
  /// unfiltered set, so they are the same on every response — this client's
  /// photos being entirely private is the real data that makes "Public" zero.
  final visibility = <FoundFilterOption>[
    const FoundFilterOption(id: 'all', label: 'All', count: 39),
    const FoundFilterOption(id: 'public', label: 'Public', count: 0),
    const FoundFilterOption(id: 'private', label: 'Private', count: 39),
  ];

  /// The selection the most recent lookup was made with.
  FoundFilters? lastFilters;

  @override
  Future<FoundFilterOptions> getFilterOptions(FoundFilters filters) async {
    lastFilters = filters;
    await Future<void>.delayed(delay);
    return FoundFilterOptions(
      matchingCount: countFor(filters),
      totalCount: 48,
      visibility: visibility,
      photographers: visiblePhotographers ?? photographers,
    );
  }

  @override
  Future<FoundAlbumsPage> getAlbums({
    FoundFilters filters = FoundFilters.none,
    int page = 1,
    int limit = 25,
    int previewLimit = 6,
  }) =>
      throw UnimplementedError();

  @override
  Future<FoundPhotosPage> getPhotos({
    FoundFilters filters = FoundFilters.none,
    int page = 1,
    int limit = 25,
  }) =>
      throw UnimplementedError();
}

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

/// Advances past the sheet's 250 ms debounce, then lets the response settle.
Future<void> settleAfterDebounce(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 300));
  await t.pumpAndSettle();
}

void main() {
  late _FakeRepo repo;

  setUp(() {
    // A phone-shaped viewport: at the 800x600 default, ScreenUtil's `.w`
    // scales by ~2x and the chips wrap far enough down the sheet that taps
    // stop landing on them.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  void register(_FakeRepo r) {
    repo = r;
    if (sl.isRegistered<GetFoundPhotosUseCase>()) {
      sl.unregister<GetFoundPhotosUseCase>();
    }
    sl.registerSingleton<GetFoundPhotosUseCase>(GetFoundPhotosUseCase(r));
  }

  tearDown(() {
    if (sl.isRegistered<GetFoundPhotosUseCase>()) {
      sl.unregister<GetFoundPhotosUseCase>();
    }
  });

  testWidgets('the count is the server\'s, and only shown once it matches '
      'the current selection', (t) async {
    register(_FakeRepo((f) {
      if (f.visibility == FoundVisibility.private) return 5;
      if (f.dateRange == FoundDateRange.thisMonth) return 12;
      return 48;
    }));

    await t.pumpWidget(host(
      const FoundFilterSheet(initial: FoundFilters.none),
    ));
    await t.pumpAndSettle();

    // Nothing selected — the design's resting state carries no number.
    expect(find.text('Show photos'), findsOneWidget);

    await t.tap(find.text('This month'));
    await t.pump();
    // In flight: must NOT be showing a number yet, and must never show a
    // number belonging to a different selection.
    expect(find.textContaining('Show 48'), findsNothing);
    expect(find.text('Show photos'), findsOneWidget);

    await settleAfterDebounce(t);
    expect(find.text('Show 12 photos'), findsOneWidget);

    // Changing the selection must drop the now-stale 12 immediately — this is
    // the regression: it used to keep displaying the previous count.
    await t.tap(find.text('Private'));
    await t.pump();
    expect(find.text('Show 12 photos'), findsNothing);

    await settleAfterDebounce(t);
    expect(find.text('Show 5 photos'), findsOneWidget);
  });

  testWidgets('singular photo is not pluralised', (t) async {
    register(_FakeRepo((f) => 1));

    await t.pumpWidget(host(
      const FoundFilterSheet(initial: FoundFilters.none),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('This month'));
    await settleAfterDebounce(t);

    expect(find.text('Show 1 photo'), findsOneWidget);
  });

  testWidgets('a failed lookup drops the count rather than keeping a stale one',
      (t) async {
    register(_FakeRepo((f) => f.isActive ? 12 : 48));

    await t.pumpWidget(host(
      const FoundFilterSheet(initial: FoundFilters.none),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('This month'));
    await settleAfterDebounce(t);
    expect(find.text('Show 12 photos'), findsOneWidget);

    // Next lookup fails. Tapped via "Private" rather than "Public": the fake
    // reports zero public photos for this client, which makes that chip inert
    // by design — see the zero-count test below.
    register(_FakeRepo((f) => throw Exception('boom')));
    await t.tap(find.text('Private'));
    await settleAfterDebounce(t);

    expect(find.textContaining('Show 12'), findsNothing);
    expect(find.text('Show photos'), findsOneWidget);
  });

  testWidgets('a selected photographer dropped by the server stays removable',
      (t) async {
    register(_FakeRepo((f) => f.photographerIds.isEmpty ? 48 : 19));

    await t.pumpWidget(host(
      const FoundFilterSheet(initial: FoundFilters.none),
    ));
    await t.pumpAndSettle();

    await t.tap(find.text('Daniella Daniels'));
    await t.pump();
    // The server now recomputes the list and no longer returns her.
    repo.visiblePhotographers = [repo.photographers[1]];
    await settleAfterDebounce(t);

    // Still on screen, so the user can switch the filter back off.
    expect(find.text('Daniella Daniels'), findsOneWidget);
    expect(find.text('Show 19 photos'), findsOneWidget);
  });

  testWidgets('photographers accumulate — selecting a second keeps the first',
      (t) async {
    register(_FakeRepo((f) => 48 - f.photographerIds.length));

    await t.pumpWidget(host(
      const FoundFilterSheet(initial: FoundFilters.none),
    ));
    await t.pumpAndSettle();

    await t.tap(find.text('Daniella Daniels'));
    await settleAfterDebounce(t);
    // The server recomputes its list against date/visibility and can drop a
    // photographer the user has selected — the case most likely to lose one.
    repo.visiblePhotographers = [repo.photographers[1]];
    await t.tap(find.text('Kofi Mensah'));
    await settleAfterDebounce(t);

    for (final name in ['Daniella Daniels', 'Kofi Mensah']) {
      expect(
        t.getSemantics(find.text(name)),
        isSemantics(isSelected: true),
        reason: '$name should still read as selected',
      );
    }
    // Both ids must reach the query — a set, not a last-write-wins field.
    expect(repo.lastFilters?.photographerIds, {'ph-1', 'ph-2'});
  });

  testWidgets('chip counts come from the server, and a zero one is inert',
      (t) async {
    register(_FakeRepo((f) => f.visibility == FoundVisibility.private ? 39 : 0));

    await t.pumpWidget(host(
      const FoundFilterSheet(initial: FoundFilters.none),
    ));
    await t.pumpAndSettle();

    // Facet counts render beside their chip, not folded into the label.
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('19'), findsOneWidget); // Daniella's photographer count

    // "Public" matches nothing for this client, so tapping it does nothing —
    // no draft change, so the CTA stays in its resting state.
    await t.tap(find.text('Public'));
    await settleAfterDebounce(t);
    expect(find.text('Show photos'), findsOneWidget);

    // The neighbouring chip with a real count still works.
    await t.tap(find.text('Private'));
    await settleAfterDebounce(t);
    expect(find.text('Show 39 photos'), findsOneWidget);
  });

  testWidgets('contextual counts are withheld in flight; global ones hold',
      (t) async {
    register(_FakeRepo((f) => f.isActive ? 12 : 48));

    await t.pumpWidget(host(
      const FoundFilterSheet(initial: FoundFilters.none),
    ));
    await t.pumpAndSettle();
    expect(find.text('19'), findsOneWidget);

    await t.tap(find.text('This month'));
    await t.pump();

    // Photographer counts are computed against the date/visibility selection,
    // so they belong to the selection the user just left — withheld, exactly
    // like the CTA's number.
    expect(find.text('19'), findsNothing);
    expect(find.text('Show photos'), findsOneWidget);
    // Visibility counts are computed over the unfiltered set precisely so they
    // hold still while the user experiments. Blanking them would be a lie in
    // the other direction.
    expect(find.text('39'), findsWidgets);

    // And the hairline runs through the debounce window rather than leaving a
    // 250 ms gap where the numbers are simply gone.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await settleAfterDebounce(t);
    expect(find.text('19'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
