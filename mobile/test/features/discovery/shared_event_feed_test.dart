import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/features/discovery/data/datasources/discovery_remote_data_source.dart';
import 'package:jperg_app/features/discovery/presentation/pages/shared_event_feed_page.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// A shared event opens as the feed draws it, not as its album.
///
/// The album is the right screen for browsing a shoot you already know about
/// and the wrong one for arriving at a post somebody sent you: it opens on a
/// wall of crops, with the photographer, the caption, the reactions and the
/// soundtrack all one level away. The card is what the sender was looking at
/// when they decided to share it.
///
/// The card itself needs a DiscoveryBloc, a theme extension, screen metrics and
/// network images, none of which is what could plausibly break here. What could
/// is the fetch — that the page asks for the event by the id in the link — and
/// the routing, which the source guard at the bottom pins.
class _FakeSource implements DiscoveryRemoteDataSource {
  _FakeSource({this.error});

  final Object? error;
  final asked = <String>[];

  /// Never resolves on the success path. That is the state the page is in for
  /// as long as the fetch is in flight, and it keeps the real card — which
  /// wants a DiscoveryBloc, a soundtrack and a network image — out of a test
  /// about fetching.
  @override
  Future<EventDiscovery> getEventById(String eventId) {
    asked.add(eventId);
    if (error != null) return Future<EventDiscovery>.error(error!);
    return Completer<EventDiscovery>().future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

Widget host(SharedEventFeedPage page) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: page,
      ),
    );

void main() {
  testWidgets('it fetches the event named in the link', (t) async {
    final source = _FakeSource();

    await t.pumpWidget(host(
      SharedEventFeedPage(eventId: 'evt-1', dataSource: source),
    ));
    await t.pump();

    expect(source.asked, ['evt-1']);
    // And it says it is working while it waits.
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
  });

  testWidgets('it says so when the event will not load', (t) async {
    // A link can name something deleted, or arrive with no connection. A blank
    // black screen is the one outcome worse than an error.
    await t.pumpWidget(host(SharedEventFeedPage(
      eventId: 'gone',
      dataSource: _FakeSource(error: Exception('404')),
    )));
    await t.pump();
    await t.pump();

    expect(find.byType(AppErrorView), findsOneWidget);
  });

  test('an event already in hand is not fetched again', () {
    // Sharing from a card the app is already showing should not go back to the
    // server for something it is holding. Read from source rather than pumped:
    // supplying the event builds the real card, which wants a DiscoveryBloc and
    // a network image and is not what this is about.
    final source = File(
      'lib/features/discovery/presentation/pages/shared_event_feed_page.dart',
    ).readAsStringSync();

    expect(source, contains('if (_event == null) _load();'));
  });

  test('the event deep link routes to the feed card, not the album', () {
    // A source guard, because the alternative is mounting the whole resolver
    // with a navigator, a service locator and a live link stream to assert one
    // constructor call. This is the line that changed, and this is what would
    // silently revert.
    final source = File(
      'lib/core/deep_links/deep_link_service.dart',
    ).readAsStringSync();

    // The resolver's event branch, from its own log line to its return —
    // `case DeepLinkKind.event:` also appears in the fall-through list above,
    // where it carries no body at all.
    final start = source.indexOf('opening event ');
    final body = source.substring(start, source.indexOf('return;', start));

    expect(body, contains('SharedEventFeedPage'));
    expect(
      body,
      isNot(contains('SearchEventPhotosPage')),
      reason: 'an event link opens the feed card; the album is a tap away on it',
    );
  });

  test('a photo deep link still opens the photo itself', () {
    // Unchanged, and worth holding: a link to one image opens that image, full
    // screen, inside its album so it can be swiped like any other.
    final source = File(
      'lib/core/deep_links/deep_link_service.dart',
    ).readAsStringSync();

    final start = source.indexOf('opening album ');
    final body = source.substring(start, source.indexOf('return;', start));

    expect(body, contains('openPictureId'));
  });
}
