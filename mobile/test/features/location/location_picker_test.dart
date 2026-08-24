import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/location/data/models/place.dart';
import 'package:jperg_app/features/location/data/repositories/location_repository.dart';
import 'package:jperg_app/features/location/presentation/widgets/location_picker_sheet.dart';

/// A repository that answers from memory. Every call the sheet makes is
/// overridden, so nothing here reaches the network or the shared Dio.
class _FakeRepo extends LocationRepository {
  _FakeRepo({this.results = const [], this.countryList});

  final List<Place> results;
  final List<Place>? countryList;

  /// What each search was asked for, so a test can prove the debounce
  /// collapsed a burst of typing into one call.
  final queries = <String>[];

  @override
  Future<List<Place>> countries() async =>
      countryList ??
      const [
        Place(countryCode: 'GH', country: 'Ghana'),
        Place(countryCode: 'KE', country: 'Kenya'),
        Place(countryCode: 'NG', country: 'Nigeria'),
      ];

  @override
  Future<List<Place>> search(String query, {String? countryCode}) async {
    queries.add('$query@${countryCode ?? '*'}');
    return results;
  }
}

const _accra = Place(
  id: 2306104, name: 'Accra', admin1: 'Greater Accra Region',
  countryCode: 'GH', country: 'Ghana', lat: 5.55602, lon: -0.1969,
);
const _kumasi = Place(
  id: 2298890, name: 'Kumasi', admin1: 'Ashanti Region',
  countryCode: 'GH', country: 'Ghana', lat: 6.68848, lon: -1.62443,
);

Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(body: child),
      ),
    );

/// Pumps the sheet as a real modal so the pop value can be read — which is the
/// whole contract of the picker.
Future<Place?> _openPicker(WidgetTester tester, _FakeRepo repo) async {
  Place? chosen;
  await tester.pumpWidget(_host(Builder(builder: (context) {
    return ElevatedButton(
      onPressed: () async {
        chosen = await showModalBottomSheet<Place>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => LocationPickerSheet(repo: repo),
        );
      },
      child: const Text('open'),
    );
  })));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return chosen;
}

void main() {
  setUp(LocationRepository.resetCountriesCache);

  group('Place', () {
    test('a country on its own is country-wide and labels as the country', () {
      const ghana = Place(countryCode: 'GH', country: 'Ghana');
      expect(ghana.isCountryWide, isTrue);
      expect(ghana.label, 'Ghana');
      expect(ghana.subtitle, 'Whole country');
    });

    test('a city labels as the city and says where it is', () {
      expect(_accra.isCountryWide, isFalse);
      expect(_accra.label, 'Accra');
      expect(_accra.subtitle, 'Greater Accra Region · Ghana');
    });

    test('two records of the same place are equal', () {
      expect(_accra, equals(Place.fromJson(_accra.toJson())));
      expect(_accra == _kumasi, isFalse);
    });

    test('places without ids fall back to country and name', () {
      const a = Place(countryCode: 'GH', name: 'Nsawam');
      const b = Place(countryCode: 'GH', name: 'nsawam');
      const c = Place(countryCode: 'KE', name: 'Nsawam');
      expect(a, equals(b), reason: 'case is not a different town');
      expect(a == c, isFalse, reason: 'same name, different country');
    });

    test('json round-trips every field the server needs', () {
      final json = _accra.toJson();
      expect(json['country_code'], 'GH');
      expect(json['lat'], 5.55602);
      expect(json['lon'], -0.1969);
      expect(json['id'], 2306104);
    });

    test('a lower-case country code from the wire is normalised', () {
      final place = Place.fromJson({'country_code': 'gh', 'name': 'Accra'});
      expect(place.countryCode, 'GH');
    });
  });

  group('LocationPickerSheet', () {
    testWidgets('opens on the country list', (t) async {
      await _openPicker(t, _FakeRepo());

      expect(find.text('Ghana'), findsOneWidget);
      expect(find.text('Kenya'), findsOneWidget);
      // The town search belongs to the second step — a country has to be
      // chosen before there is any list worth searching.
      expect(find.text('Search a town or city'), findsNothing);
    });

    testWidgets('countries filter on the device', (t) async {
      await _openPicker(t, _FakeRepo());

      await t.enterText(find.byType(TextField).first, 'ken');
      await t.pumpAndSettle();

      expect(find.text('Kenya'), findsOneWidget);
      expect(find.text('Ghana'), findsNothing);
    });

    testWidgets('choosing a country moves to the town search', (t) async {
      await _openPicker(t, _FakeRepo());
      await t.tap(find.text('Ghana'));
      await t.pumpAndSettle();

      expect(find.text('Search a town or city'), findsOneWidget);
      expect(find.text('Anywhere in Ghana'), findsOneWidget);
    });

    testWidgets('the whole country is a real answer, not a way out', (t) async {
      Place? chosen;
      await t.pumpWidget(_host(Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            chosen = await showModalBottomSheet<Place>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => LocationPickerSheet(repo: _FakeRepo()),
            );
          },
          child: const Text('open'),
        );
      })));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ghana'));
      await t.pumpAndSettle();
      await t.tap(find.text('Anywhere in Ghana'));
      await t.pumpAndSettle();

      expect(chosen, isNotNull);
      expect(chosen!.countryCode, 'GH');
      expect(chosen!.isCountryWide, isTrue);
    });

    testWidgets('a search is scoped to the chosen country', (t) async {
      final repo = _FakeRepo(results: const [_accra]);
      await _openPicker(t, repo);
      await t.tap(find.text('Ghana'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField).first, 'accra');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();

      expect(repo.queries, ['accra@GH']);
      expect(find.text('Accra'), findsOneWidget);
      expect(find.text('Greater Accra Region · Ghana'), findsOneWidget);
    });

    testWidgets('typing a word is one request, not one per letter', (t) async {
      final repo = _FakeRepo(results: const [_accra]);
      await _openPicker(t, repo);
      await t.tap(find.text('Ghana'));
      await t.pumpAndSettle();

      final field = find.byType(TextField).first;
      for (final partial in ['ac', 'acc', 'accr', 'accra']) {
        await t.enterText(field, partial);
        await t.pump(const Duration(milliseconds: 80));
      }
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();

      expect(repo.queries, ['accra@GH'],
          reason: 'the debounce should collapse the burst into the last query');
    });

    testWidgets('a query under the floor never reaches the provider', (t) async {
      final repo = _FakeRepo();
      await _openPicker(t, repo);
      await t.tap(find.text('Ghana'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField).first, 'a');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();

      expect(repo.queries, isEmpty);
      expect(find.textContaining('Type at least'), findsOneWidget);
    });

    testWidgets('nothing found says so and points at the country', (t) async {
      await _openPicker(t, _FakeRepo(results: const []));
      await t.tap(find.text('Ghana'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField).first, 'zzzqqq');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();

      expect(find.textContaining('Nothing matched'), findsOneWidget);
    });

    testWidgets('picking a town returns the whole resolved record', (t) async {
      Place? chosen;
      await t.pumpWidget(_host(Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            chosen = await showModalBottomSheet<Place>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) =>
                  LocationPickerSheet(repo: _FakeRepo(results: const [_accra])),
            );
          },
          child: const Text('open'),
        );
      })));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ghana'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'accra');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      await t.tap(find.text('Accra'));
      await t.pumpAndSettle();

      // The coordinates are the point: a name cannot be measured from.
      expect(chosen, isNotNull);
      expect(chosen!.lat, 5.55602);
      expect(chosen!.lon, -0.1969);
      expect(chosen!.countryCode, 'GH');
    });

    testWidgets('back returns to the countries', (t) async {
      await _openPicker(t, _FakeRepo());
      await t.tap(find.text('Ghana'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.arrow_back_rounded));
      await t.pumpAndSettle();

      expect(find.text('Kenya'), findsOneWidget);
      expect(find.text('Search a town or city'), findsNothing);
    });

    testWidgets('a country list that fails to load is not a crash', (t) async {
      await _openPicker(t, _FakeRepo(countryList: const []));
      expect(find.text('No countries match that'), findsOneWidget);
    });
  });

  group('LocationChips', () {
    testWidgets('says plainly what no targeting means', (t) async {
      await t.pumpWidget(_host(LocationChips(
        places: const [],
        onAdd: () {},
        onRemove: (_) {},
      )));

      expect(find.text('Everywhere'), findsOneWidget);
      expect(find.text('Add a location'), findsOneWidget);
    });

    testWidgets('shows a chip per place and can remove one', (t) async {
      Place? removed;
      await t.pumpWidget(_host(LocationChips(
        places: const [_accra, _kumasi],
        onAdd: () {},
        onRemove: (p) => removed = p,
      )));

      expect(find.text('Accra'), findsOneWidget);
      expect(find.text('Kumasi'), findsOneWidget);
      expect(find.text('Add another'), findsOneWidget);

      await t.tap(find.bySemanticsLabel('Remove Kumasi'));
      expect(removed, equals(_kumasi));
    });

    testWidgets('add is reachable', (t) async {
      var added = false;
      await t.pumpWidget(_host(LocationChips(
        places: const [],
        onAdd: () => added = true,
        onRemove: (_) {},
      )));

      // By its text rather than its semantics label: the two are the same
      // words here, so they merge into one node and the label no longer
      // matches on its own.
      await t.tap(find.text('Add a location'));
      expect(added, isTrue);
    });
  });
}
