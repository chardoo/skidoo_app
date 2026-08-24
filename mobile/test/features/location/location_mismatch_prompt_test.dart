import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/location/data/models/place.dart';
import 'package:jperg_app/features/location/data/repositories/location_repository.dart';
import 'package:jperg_app/features/location/presentation/location_mismatch_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers from memory. Records the saves so a test can prove the prompt asks
/// rather than applies.
class _FakeRepo extends LocationRepository {
  _FakeRepo({this.ctx, this.throwOnContext = false});

  final LocationContext? ctx;
  final bool throwOnContext;

  final saved = <Place>[];
  int contextCalls = 0;

  @override
  Future<LocationContext?> context() async {
    contextCalls++;
    if (throwOnContext) throw Exception('offline');
    return ctx;
  }

  @override
  Future<LocationContext?> setLocation(Place place) async {
    saved.add(place);
    return ctx;
  }

  @override
  Future<List<Place>> countries() async =>
      const [Place(countryCode: 'KE', country: 'Kenya')];

  @override
  Future<List<Place>> search(String query, {String? countryCode}) async =>
      const [];
}

LocationContext _mismatched({String detected = 'KE'}) => LocationContext(
      hasLocation: true,
      locationMismatch: true,
      location: 'Accra',
      countryCode: 'GH',
      detectedCountryCode: detected,
    );

/// A shell that asks once when it mounts — which is what the real one does,
/// from the guest check in initState. Deliberately not a Builder: that runs on
/// every rebuild, and registering a fresh post-frame callback each time would
/// fire the prompt several times per launch.
class _Shell extends StatefulWidget {
  const _Shell({required this.repo, required this.prefs, super.key});

  final _FakeRepo repo;
  final SharedPreferences prefs;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        LocationMismatchPrompt.maybeShow(
          context, repo: widget.repo, prefs: widget.prefs,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('shell'));
}

/// Mounts the shell and lets the prompt settle.
///
/// [key] goes on the MaterialApp, not on the shell. A relaunch has to discard
/// the Navigator too: pumping a new tree over the old one preserves Navigator
/// state, so a sheet pushed by the previous launch would still be on screen and
/// a test could not tell it apart from a second prompt.
Future<void> _pumpPrompt(
  WidgetTester tester,
  _FakeRepo repo,
  SharedPreferences prefs, {
  Key? key,
}) async {
  // A phone-shaped surface rather than the 800x600 default, matching the
  // design size below. On the default the sheet's buttons fall below the fold
  // and a tap lands on nothing, which is a fact about the test window rather
  // than about the sheet.
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      key: key,
      theme: ThemeData(extensions: const [AppThemeExtension.light]),
      home: _Shell(repo: repo, prefs: prefs),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocationRepository.resetCountriesCache();
  });

  group('when it speaks up', () {
    testWidgets('a real disagreement raises it', (t) async {
      final prefs = await SharedPreferences.getInstance();
      await _pumpPrompt(t, _FakeRepo(ctx: _mismatched()), prefs);

      expect(find.text('Still working in Accra?'), findsOneWidget);
      expect(find.text('Update my location'), findsOneWidget);
      expect(find.text('I am just travelling'), findsOneWidget);
    });

    testWidgets('it explains what being wrong costs', (t) async {
      final prefs = await SharedPreferences.getInstance();
      await _pumpPrompt(t, _FakeRepo(ctx: _mismatched()), prefs);

      // "Update your location" alone reads as housekeeping. This is the reason
      // a board can look empty, and the sheet has to say so.
      expect(find.textContaining('jobs near you will not show up'),
          findsOneWidget);
    });
  });

  group('when it stays quiet', () {
    testWidgets('no disagreement, no prompt', (t) async {
      final prefs = await SharedPreferences.getInstance();
      await _pumpPrompt(
        t,
        _FakeRepo(ctx: const LocationContext(
          hasLocation: true,
          locationMismatch: false,
          location: 'Accra',
          countryCode: 'GH',
          detectedCountryCode: 'GH',
        )),
        prefs,
      );
      expect(find.text('Still working in Accra?'), findsNothing);
    });

    testWidgets('an account with no location is left to the empty state',
        (t) async {
      final prefs = await SharedPreferences.getInstance();
      await _pumpPrompt(
        t,
        _FakeRepo(ctx: const LocationContext(
          hasLocation: false,
          locationMismatch: false,
        )),
        prefs,
      );
      expect(find.textContaining('Still working'), findsNothing);
    });

    testWidgets('a country that could not be detected is not a mismatch',
        (t) async {
      final prefs = await SharedPreferences.getInstance();
      await _pumpPrompt(
        t,
        _FakeRepo(ctx: const LocationContext(
          hasLocation: true,
          locationMismatch: true,
          location: 'Accra',
          countryCode: 'GH',
          detectedCountryCode: null,
        )),
        prefs,
      );
      expect(find.textContaining('Still working'), findsNothing);
    });

    testWidgets('a request that fails never interrupts the launch', (t) async {
      final prefs = await SharedPreferences.getInstance();
      await _pumpPrompt(t, _FakeRepo(throwOnContext: true), prefs);

      expect(find.text('shell'), findsOneWidget);
      expect(find.textContaining('Still working'), findsNothing);
    });
  });

  group('rate limiting', () {
    testWidgets('it does not ask twice in the same week', (t) async {
      final prefs = await SharedPreferences.getInstance();

      await _pumpPrompt(t, _FakeRepo(ctx: _mismatched()), prefs,
          key: const ValueKey('launch-1'));
      expect(find.textContaining('Still working'), findsOneWidget);

      // Dismiss, then relaunch. A fresh key so the shell really remounts —
      // the same type would otherwise reuse its State and never re-run
      // initState.
      await t.tap(find.text('I am just travelling'));
      await t.pumpAndSettle();
      await _pumpPrompt(t, _FakeRepo(ctx: _mismatched()), prefs,
          key: const ValueKey('launch-2'));

      expect(find.textContaining('Still working'), findsNothing,
          reason: 'a prompt on every launch is one people stop reading');
    });

    testWidgets('swiping it away still counts as having been asked', (t) async {
      final prefs = await SharedPreferences.getInstance();

      await _pumpPrompt(t, _FakeRepo(ctx: _mismatched()), prefs,
          key: const ValueKey('launch-1'));
      expect(find.textContaining('Still working'), findsOneWidget);

      // Straight to a relaunch — no button was pressed, the sheet was
      // dismissed. A prompt that only records the answers it likes reappears
      // forever for anyone who swipes.
      await _pumpPrompt(t, _FakeRepo(ctx: _mismatched()), prefs,
          key: const ValueKey('launch-2'));
      expect(find.textContaining('Still working'), findsNothing);
    });

    testWidgets('a week later it asks again', (t) async {
      final eightDaysAgo = DateTime.now()
          .subtract(const Duration(days: 8))
          .millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'location_prompt_dismissed_KE': eightDaysAgo,
      });
      final prefs = await SharedPreferences.getInstance();

      await _pumpPrompt(t, _FakeRepo(ctx: _mismatched()), prefs);
      expect(find.textContaining('Still working'), findsOneWidget);
    });

    testWidgets('a different country asks again immediately', (t) async {
      SharedPreferences.setMockInitialValues({
        'location_prompt_dismissed_KE': DateTime.now().millisecondsSinceEpoch,
      });
      final prefs = await SharedPreferences.getInstance();

      // Dismissed for Kenya; now they turn up in Nigeria, which is news.
      await _pumpPrompt(t, _FakeRepo(ctx: _mismatched(detected: 'NG')), prefs);
      expect(find.textContaining('Still working'), findsOneWidget);
    });
  });

  group('it asks rather than applies', () {
    testWidgets('dismissing changes nothing', (t) async {
      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeRepo(ctx: _mismatched());
      await _pumpPrompt(t, repo, prefs);

      await t.tap(find.text('I am just travelling'));
      await t.pumpAndSettle();

      // Somebody on a job abroad has not moved, and rewriting their working
      // location would break the thing this exists to protect.
      expect(repo.saved, isEmpty);
    });

    testWidgets('updating opens the picker rather than guessing', (t) async {
      final prefs = await SharedPreferences.getInstance();
      await _pumpPrompt(t, _FakeRepo(ctx: _mismatched()), prefs);

      await t.tap(find.text('Update my location'));
      await t.pumpAndSettle();

      // The detected country is a hint, not an answer — they pick.
      expect(find.text('Where do you work?'), findsOneWidget);
    });
  });
}
