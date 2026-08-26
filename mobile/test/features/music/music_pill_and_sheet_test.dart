import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/music/domain/entities/music_track.dart';
import 'package:jperg_app/features/music/presentation/widgets/feed_music_pill.dart';
import 'package:jperg_app/features/music/presentation/widgets/music_track_sheet.dart';

/// The pill, and where it now leads.
///
/// It used to be a mute button and nothing else: somebody who liked what they
/// heard had nowhere to go with that. Tapping the label now opens a sheet that
/// hands over to the provider — but the pill was also the *only* mute control
/// on the feed, so the two live side by side and the tests below hold that
/// line. Losing mute would leave somebody scrolling in public with no way to
/// silence it.
const _track = MusicTrack(
  id: 't1',
  title: 'Excess Love',
  artist: 'Mercy Chinwo',
  streamUrl: 'https://audio.example/excess.mp3',
  pageUrl: 'https://audiomack.com/mercychinwo/song/excess-love',
);

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension.dark],
          splashFactory: NoSplash.splashFactory,
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  group('the pill', () {
    testWidgets('names the track and credits the provider', (tester) async {
      await tester.pumpWidget(host(FeedMusicPill(
        track: _track,
        muted: false,
        onToggleMute: () {},
        onOpenTrack: () {},
      )));

      expect(find.textContaining('Excess Love'), findsOneWidget);
      expect(find.text('powered by'), findsOneWidget);
      expect(find.text('Audiomack'), findsOneWidget);
    });

    testWidgets('the note mutes, and does not open the sheet', (tester) async {
      var muteTaps = 0;
      var openTaps = 0;
      await tester.pumpWidget(host(FeedMusicPill(
        track: _track,
        muted: false,
        onToggleMute: () => muteTaps++,
        onOpenTrack: () => openTaps++,
      )));

      await tester.tap(find.byIcon(Icons.music_note_rounded));
      await tester.pump();

      expect(muteTaps, 1);
      expect(openTaps, 0, reason: 'the icon is the sound control, not a link');
    });

    testWidgets('the label opens the sheet, and does not mute', (tester) async {
      var muteTaps = 0;
      var openTaps = 0;
      await tester.pumpWidget(host(FeedMusicPill(
        track: _track,
        muted: false,
        onToggleMute: () => muteTaps++,
        onOpenTrack: () => openTaps++,
      )));

      await tester.tap(find.text('Audiomack'));
      await tester.pump();

      expect(openTaps, 1);
      expect(muteTaps, 0, reason: 'tapping the credit must not silence it');
    });

    testWidgets('shows a struck-through speaker once muted', (tester) async {
      await tester.pumpWidget(host(FeedMusicPill(
        track: _track,
        muted: true,
        onToggleMute: () {},
        onOpenTrack: () {},
      )));

      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.music_note_rounded), findsNothing);
    });
  });

  group('the sheet', () {
    Future<void> open(WidgetTester tester, {MusicTrack track = _track}) async {
      await tester.pumpWidget(host(Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => MusicTrackSheet.show(context, track),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('says what is playing and who by', (tester) async {
      await open(tester);

      expect(find.text('Excess Love'), findsOneWidget);
      expect(find.text('Mercy Chinwo'), findsOneWidget);
    });

    testWidgets('warns before sending anyone out of the app', (tester) async {
      // The warning is the feature. Leaving on an unannounced tap loses people
      // the feed they were scrolling.
      await open(tester);

      expect(
        find.textContaining("redirected to Audiomack"),
        findsOneWidget,
      );
      expect(find.text('Listen on Audiomack'), findsOneWidget);
    });

    testWidgets('offers staying as a real answer', (tester) async {
      await open(tester);

      expect(find.text('Stay here'), findsOneWidget);

      await tester.tap(find.text('Stay here'));
      await tester.pumpAndSettle();

      expect(find.text('Excess Love'), findsNothing);
    });

    testWidgets('falls back to "Music" for a track with no title',
        (tester) async {
      // title and artist are both free-form on a JSON column the client does
      // not control — see MusicTrack.label for the same reasoning.
      await open(
        tester,
        track: const MusicTrack(
          id: 't2',
          title: '',
          artist: '',
          streamUrl: 'https://audio.example/x.mp3',
        ),
      );

      expect(find.text('Music'), findsOneWidget);
    });
  });
}
