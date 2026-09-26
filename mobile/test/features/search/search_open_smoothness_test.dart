import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/search/presentation/bloc/search_bloc.dart';
import 'package:jperg_app/features/search/presentation/pages/search_page.dart';

/// Opening search from the feed.
///
/// The screen used to do all of its work while the route was still sliding:
/// the bloc asked for recents *and* for the "You may like" grid the moment it
/// was created, so a network call and a screenful of photographs to decode
/// landed in the middle of the transition's frame budget. It stuttered on
/// every open.
///
/// What is pinned here is the order: nothing expensive, and no keyboard, until
/// the page has actually arrived. The animation is the feature, and it is the
/// one thing a widget test can hold still long enough to check.

class _RecordingBloc extends Bloc<SearchEvent, SearchState>
    implements SearchBloc {
  _RecordingBloc() : super(const SearchState());

  final seen = <SearchEvent>[];

  @override
  void add(SearchEvent event) => seen.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A host with a real route to push through, so `ModalRoute.of` resolves and
/// the transition genuinely takes time.
Widget host(GlobalKey<NavigatorState> nav) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        navigatorKey: nav,
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: const Scaffold(body: Center(child: Text('feed'))),
      ),
    );

void main() {
  late _RecordingBloc bloc;

  setUp(() {
    bloc = _RecordingBloc();
    GetIt.I.registerFactory<SearchBloc>(() => bloc);
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 2, 844 * 2);
    view.devicePixelRatio = 2;
  });

  tearDown(() async {
    await GetIt.I.reset();
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  bool asked<T>() => bloc.seen.any((e) => e is T);

  testWidgets('the suggestion grid is not fetched during the transition',
      (t) async {
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(host(nav));
    await t.pumpAndSettle();

    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const SearchPage(),
    ));
    // One frame in: the route is building and beginning to slide.
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));

    expect(asked<SearchRecentsRequested>(), isTrue,
        reason: 'recents are cheap and are what the screen opens on');
    expect(asked<SearchYouMayLikeRequested>(), isFalse,
        reason: 'a network call and a grid of photos, mid-slide');

    await t.pumpAndSettle();

    expect(asked<SearchYouMayLikeRequested>(), isTrue,
        reason: 'and asked for once the page has landed');
  });

  testWidgets('the keyboard is not raised under a moving page', (t) async {
    // Focusing during the push raises the keyboard while the route is still
    // sliding, and the scaffold resizing under a moving page is the other half
    // of what made this feel rough.
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(host(nav));
    await t.pumpAndSettle();

    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const SearchPage(),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));

    final field = find.byType(EditableText);
    expect(field, findsOneWidget);
    expect(t.widget<EditableText>(field).focusNode.hasFocus, isFalse,
        reason: 'mid-transition');

    await t.pumpAndSettle();

    expect(t.widget<EditableText>(field).focusNode.hasFocus, isTrue,
        reason: 'and straight into the field once it has arrived — every '
            'search on a phone works this way');
  });

  testWidgets('a pre-filled search lands on results, not on the keyboard',
      (t) async {
    // Opened on somebody's behalf — an access code from the unlock sheet. The
    // answer is on screen; raising the keyboard over it would be wrong.
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(host(nav));
    await t.pumpAndSettle();

    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const SearchPage(initialQuery: 'graduation'),
    ));
    await t.pumpAndSettle();

    expect(t.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
        isFalse);
    expect(asked<SearchYouMayLikeRequested>(), isTrue);
  });
}
