import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/data/saved_photos.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_action_rail.dart';
import 'package:jperg_app/models/photos/Photo.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Every action on this rail is behind [requireAccount], which sends a guest
/// to sign-up instead of acting. A token is all that gate wants.
class _SignedIn extends AuthService {
  @override
  Future<String> getToken() async => 'a-token';
}

/// Bookmarking a photo answers on the tap, the way liking one does.
///
/// [SavedPhotos.toggle] has always been optimistic — it flips the glyph before
/// it writes and rolls it back if the write fails — but the rail also passed
/// its in-flight flag as `busy`, and a busy [MediaRailAction] *replaces* the
/// glyph with a spinner. So the flip was real and invisible: tap, the bookmark
/// vanishes for a round trip, then comes back filled. On a slow connection it
/// read as the app thinking about it.
///
/// The heart never did this. It flips in `setState` and lets the server catch
/// up, which is the behaviour these pin for the bookmark.
///
/// The store here is held open deliberately: everything worth asserting
/// happens *between* the tap and the server's answer, which is exactly the
/// window a stub that returns immediately skips over.
class _HeldStore implements SavedPhotoStore {
  final _writes = <Completer<void>>[];

  /// Lets the pending write finish.
  void release() {
    for (final c in _writes) {
      if (!c.isCompleted) c.complete();
    }
    _writes.clear();
  }

  /// Fails the pending write instead, to exercise the rollback.
  void fail() {
    for (final c in _writes) {
      if (!c.isCompleted) c.completeError(Exception('nope'));
    }
    _writes.clear();
  }

  Future<void> _held() {
    final completer = Completer<void>();
    _writes.add(completer);
    return completer.future;
  }

  @override
  Future<List<String>> savedIds() async => const [];
  @override
  Future<void> save(String pictureId) => _held();
  @override
  Future<void> unsave(String pictureId) => _held();
}

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

Photo photo() => Photo.fromMap({
      'id': 'pic-1',
      'url': 'https://cdn.example.com/pic-1.jpg',
      'price': 0,
      'likeCount': 206,
      'commentCount': 10,
      'event': const {'id': 'evt-1', 'eventName': 'Praise Reloaded 2026'},
    });

/// The resting bookmark is the supplied SVG; the filled one is the icon font.
Finder get _restingBookmark => find.byWidgetPredicate(
    (w) => w is AppSvgIcon && w.asset == AppIcons.save,
    description: 'the resting bookmark glyph');

Finder get _filledBookmark => find.byIcon(Icons.bookmark_rounded);

void main() {
  late _HeldStore store;

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;

    store = _HeldStore();
    GetIt.I.registerSingleton<SavedPhotos>(SavedPhotos(store));
    GetIt.I.registerSingleton<AuthService>(_SignedIn());
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    GetIt.I.reset();
  });

  testWidgets('the bookmark fills on the tap, before the server answers',
      (t) async {
    await t.pumpWidget(host(FoundActionRail(photo: photo())));
    await t.pump();
    expect(_restingBookmark, findsOneWidget);

    await t.tap(_restingBookmark);
    // Two pumps: `requireAccount` awaits the stored token before it runs the
    // action, so the flip lands a microtask after the tap rather than in it.
    await t.pump();
    await t.pump();

    // The write has not come back yet — this is the frame that used to show a
    // spinner where the bookmark had been.
    expect(_filledBookmark, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    store.release();
    await t.pumpAndSettle();
    expect(_filledBookmark, findsOneWidget);
  });

  testWidgets('no spinner ever replaces it', (t) async {
    await t.pumpWidget(host(FoundActionRail(photo: photo())));
    await t.pump();

    await t.tap(_restingBookmark);

    // Every frame of the write, not just the first: `pump` once per frame
    // rather than settling, so a spinner that appeared late would be caught.
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'frame $i drew a loader over the bookmark');
    }

    store.release();
    await t.pumpAndSettle();
  });

  testWidgets('a failed write puts the bookmark back', (t) async {
    // The flip is a promise the server can still break. Rolling back is what
    // makes an optimistic glyph honest rather than merely fast.
    await t.pumpWidget(host(FoundActionRail(photo: photo())));
    await t.pump();

    await t.tap(_restingBookmark);
    await t.pump();
    await t.pump();
    expect(_filledBookmark, findsOneWidget);

    store.fail();
    await t.pumpAndSettle();

    expect(_restingBookmark, findsOneWidget);
    expect(_filledBookmark, findsNothing);
  });

  testWidgets('tapping again un-saves it, just as immediately', (t) async {
    await t.pumpWidget(host(FoundActionRail(photo: photo())));
    await t.pump();

    await t.tap(_restingBookmark);
    await t.pump();
    await t.pump();
    store.release();
    await t.pumpAndSettle();
    expect(_filledBookmark, findsOneWidget);

    await t.tap(_filledBookmark);
    await t.pump();
    await t.pump();

    expect(_restingBookmark, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    store.release();
    await t.pumpAndSettle();
  });
}
