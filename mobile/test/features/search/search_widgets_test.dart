import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/search/domain/entities/search_models.dart';
import 'package:skidoo_app/features/search/presentation/bloc/search_bloc.dart';
import 'package:skidoo_app/features/search/presentation/widgets/recent_searches_list.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_event_row_tile.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_idle_view.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_photo_grid.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_photographer_row_tile.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_results_list.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_tag_row_tile.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_top_bar.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_type_chips.dart';
import 'package:skidoo_app/features/search/presentation/widgets/section_header.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

Widget host(AppThemeExtension ext, Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(
          brightness: ext == AppThemeExtension.dark
              ? Brightness.dark
              : Brightness.light,
          extensions: [ext],
        ),
        home: Scaffold(body: child),
      ),
    );

Color colourOf(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style!.color!;

/// No cover URL on purpose: the tile's fallback renders without reaching for
/// the network, which a widget test has no business doing.
SearchEventRow eventRow({int photoCount = 108}) => SearchEventRow.fromJson({
      'id': 'evt-1',
      'eventName': 'Praise Reloaded 2026',
      'photoCount': photoCount,
      'photographer': const {
        'name': 'Efo Reloaded',
        'specialty': 'Arts & Culture',
        'followerCount': 1024,
      },
    });

Photo gridPhoto(int i) => Photo.fromMap({
      'id': 'pic-$i',
      'url': 'https://cdn/$i.jpg',
      'width': 400,
      'height': 400,
      'event': {'id': 'evt-1', 'eventName': 'Reloaded'},
    });

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  group('rows', () {
    testWidgets('an event row shows its photo count', (t) async {
      await t.pumpWidget(host(AppThemeExtension.dark,
          SearchEventRowTile(event: eventRow(), onTap: () {})));

      expect(find.text('Praise Reloaded 2026'), findsOneWidget);
      expect(find.text('108 photos'), findsOneWidget);
      // The design's affordance for "this opens a grid".
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('an event with no public photos falls back to its photographer',
        (t) async {
      // "0 photos" would read as broken; the photographer line is true either
      // way and is what the design shows on the first row.
      await t.pumpWidget(host(AppThemeExtension.dark,
          SearchEventRowTile(event: eventRow(photoCount: 0), onTap: () {})));

      expect(find.text('Arts & Culture · 1K followers'), findsOneWidget);
    });

    testWidgets('a photographer row reads "specialty · followers"', (t) async {
      await t.pumpWidget(host(
        AppThemeExtension.dark,
        SearchPhotographerRowTile(
          photographer: SearchPhotographerRow.fromJson(const {
            'id': 'ph-1',
            'name': 'Efo Reloaded',
            'specialty': 'Arts & Culture',
            'followerCount': 1024,
          }),
          onTap: () {},
        ),
      ));

      expect(find.text('Efo Reloaded'), findsOneWidget);
      expect(find.text('Arts & Culture · 1K followers'), findsOneWidget);
    });

    testWidgets('a tag row shows the label and a compact post count',
        (t) async {
      await t.pumpWidget(host(
        AppThemeExtension.dark,
        SearchTagRowTile(
          tag: SearchTagRow.fromJson(
              const {'tag': 'reloaded', 'label': '#reloaded', 'postCount': 100000}),
          onTap: () {},
        ),
      ));

      expect(find.text('#reloaded'), findsOneWidget);
      expect(find.text('100K posts'), findsOneWidget);
    });
  });

  group('recent searches', () {
    testWidgets('each row carries its own ✕', (t) async {
      final removed = <String>[];
      await t.pumpWidget(host(
        AppThemeExtension.dark,
        RecentSearchesList(
          queries: const ['Praise Reloaded', 'Telecel Music Awards'],
          onTap: (_) {},
          onRemove: removed.add,
        ),
      ));

      await t.tap(
          find.bySemanticsLabel('Remove Praise Reloaded from recent searches'));
      expect(removed, ['Praise Reloaded']);
    });

    testWidgets('the store keeps more than the screen shows', (t) async {
      await t.pumpWidget(host(
        AppThemeExtension.dark,
        RecentSearchesList(
          queries: List.generate(10, (i) => 'query $i'),
          onTap: (_) {},
          onRemove: (_) {},
          maxVisible: 3,
        ),
      ));

      expect(find.text('query 2'), findsOneWidget);
      expect(find.text('query 3'), findsNothing);
    });
  });

  group('composed views lay out', () {
    testWidgets('the idle screen stacks recents over the suggestion grid',
        (t) async {
      await t.pumpWidget(host(
        AppThemeExtension.dark,
        SearchIdleView(
          state: SearchState(
            recents: const ['Praise Reloaded'],
            youMayLike: [for (var i = 0; i < 9; i++) gridPhoto(i)],
            youMayLikeCursor: 30,
          ),
          onRecentTap: (_) {},
          onRecentRemove: (_) {},
          onRefresh: () {},
          onPhotoTap: (_, __) {},
        ),
      ));

      expect(find.text('Praise Reloaded'), findsOneWidget);
      expect(find.text('You may like'), findsOneWidget);
      expect(find.byType(SearchPhotoTile), findsWidgets);
    });

    testWidgets('the results list renders the active chip\'s rows', (t) async {
      await t.pumpWidget(host(
        AppThemeExtension.dark,
        SearchResultsList(
          state: SearchState(
            query: 'Reloaded',
            status: SearchStatus.success,
            activeType: SearchResultType.tags,
            total: 2,
            events: SearchSection<SearchEventRow>(
              items: [eventRow()],
              count: 1,
            ),
            tags: SearchSection<SearchTagRow>(
              items: [
                SearchTagRow.fromJson(
                    const {'tag': 'reloaded', 'postCount': 100000}),
              ],
              count: 1,
            ),
          ),
          onEventTap: (_) {},
          onPhotographerTap: (_) {},
          onTagTap: (_) {},
        ),
      ));

      expect(find.text('#reloaded'), findsOneWidget);
      // The events section is populated in state but not active — it must not
      // leak into the list under the Tags chip.
      expect(find.text('Praise Reloaded 2026'), findsNothing);
    });
  });

  // One theme per test: pumping two themes into the same tree reuses the
  // element and the second theme doesn't take, which passes for the wrong
  // reason.
  for (final (name, ext) in [
    ('dark', AppThemeExtension.dark),
    ('light', AppThemeExtension.light),
  ]) {
    group('$name mode', () {
      testWidgets('the active chip is the accent, the rest are not', (t) async {
        await t.pumpWidget(host(
          ext,
          SearchTypeChips(
            types: SearchResultType.values,
            selected: SearchResultType.events,
            onSelected: (_) {},
          ),
        ));

        expect(colourOf(t, 'Events'), ext.accentGold);
        expect(colourOf(t, 'Photographers'), ext.greetingColor);
        expect(colourOf(t, 'Tags'), ext.greetingColor);
      });

      testWidgets('row text follows the theme rather than a fixed white',
          (t) async {
        // The regression this guards: white-on-white in light mode, which is
        // what happens when a row borrows the feed's over-media treatment.
        await t.pumpWidget(
            host(ext, SearchEventRowTile(event: eventRow(), onTap: () {})));

        expect(colourOf(t, 'Praise Reloaded 2026'), ext.greetingColor);
        expect(colourOf(t, '108 photos'), ext.searchHintColor);
      });

      testWidgets('the query field sits on the theme\'s own fill', (t) async {
        await t.pumpWidget(host(
          ext,
          SearchTopBar(
            controller: TextEditingController(),
            focusNode: FocusNode(),
            onChanged: (_) {},
            onSubmitted: (_) {},
            onBack: () {},
          ),
        ));

        final decorated = t.widgetList<Container>(find.byType(Container)).first;
        final decoration = decorated.decoration! as BoxDecoration;
        expect(decoration.color, ext.searchFieldFill);
      });

      testWidgets('the You-may-like refresh is the accent', (t) async {
        await t.pumpWidget(host(
          ext,
          SectionHeader(
            title: 'You may like',
            actionIcon: Icons.refresh_rounded,
            onAction: () {},
          ),
        ));

        final icon = t.widget<Icon>(find.byIcon(Icons.refresh_rounded));
        expect(icon.color, ext.accentGold);
      });
    });
  }
}
