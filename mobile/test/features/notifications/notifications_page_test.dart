import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/notifications/data/notification_inbox.dart';
import 'package:jperg_app/features/notifications/data/notification_service.dart';
import 'package:jperg_app/features/notifications/presentation/pages/notifications_page.dart';

/// What the notification list shows.
///
/// The page is pumped over a pre-loaded inbox, which is also what stops it
/// fetching: it only goes to the server when what it holds is stale, and a
/// widget test has no server to go to.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppThemeExtension.dark]),
        home: child,
      ),
    );

AppNotification row({
  required String id,
  String type = 'new_follower',
  String title = 'New follower',
  String body = 'Kwame started following you.',
  bool isRead = false,
  Duration age = const Duration(minutes: 5),
  Map<String, dynamic> data = const {},
}) =>
    AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      isRead: isRead,
      createdAt: DateTime.now().subtract(age),
    );

void main() {
  final inbox = NotificationInbox.instance;

  setUp(() {
    inbox.clear();
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  void seed(List<AppNotification> rows) => inbox.reset(
        rows,
        exhausted: true,
        at: AppCacheSignals.notifications.value,
      );

  testWidgets('every row says when it happened', (t) async {
    seed([
      row(id: '1', age: const Duration(minutes: 5)),
      row(id: '2', age: const Duration(hours: 3)),
      row(id: '3', age: const Duration(days: 2)),
    ]);

    await t.pumpWidget(host(const NotificationsPage()));
    await t.pump();

    expect(find.text('5m'), findsOneWidget);
    expect(find.text('3h'), findsOneWidget);
    expect(find.text('2d'), findsOneWidget);
  });

  testWidgets('the title and the body read as one line', (t) async {
    seed([row(id: '1')]);

    await t.pumpWidget(host(const NotificationsPage()));
    await t.pump();

    // One RichText, not a title widget and a subtitle widget: the title is the
    // opening of the sentence the body finishes. Both halves are in the same
    // span, which is what `findRichText` proves — a title Text and a body Text
    // would be two widgets and this would find neither.
    expect(
      find.textContaining('New follower  Kwame started following you.',
          findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('the tabs are there and switching keeps its own list',
      (t) async {
    seed([row(id: '1')]);
    inbox.reset(
      [row(id: '2', type: 'new_event', title: 'New album')],
      exhausted: true,
      at: AppCacheSignals.notifications.value,
      filter: 'photos',
    );

    await t.pumpWidget(host(const NotificationsPage()));
    await t.pump();

    // The chips scroll horizontally, so only the first few are built on a
    // 390-wide screen — the ones past the edge are reached by scrolling, not
    // by being off-screen in the widget tree.
    for (final label in ['All', 'Photos', 'Bookings']) {
      expect(find.text(label), findsOneWidget);
    }

    await t.tap(find.text('Photos'));
    await t.pump();

    expect(find.textContaining('New album', findRichText: true), findsOneWidget);
    expect(find.textContaining('New follower', findRichText: true), findsNothing);
  });

  testWidgets('a kind with no picture of its own still gets an icon',
      (t) async {
    seed([row(id: '1', type: 'campaign_paused', title: 'Campaign Paused')]);

    await t.pumpWidget(host(const NotificationsPage()));
    await t.pump();

    expect(find.byIcon(Icons.pause_circle_outline_rounded), findsOneWidget);
  });

  testWidgets('unread rows are marked, read rows are not', (t) async {
    seed([row(id: '1', isRead: false), row(id: '2', isRead: true)]);

    await t.pumpWidget(host(const NotificationsPage()));
    await t.pump();

    // The header offers the bulk action only while something is unread.
    expect(find.text('Mark all read'), findsOneWidget);

    inbox.markAllRead();
    await t.pumpWidget(host(const NotificationsPage()));
    await t.pump();

    expect(find.text('Mark all read'), findsNothing);
  });
}
