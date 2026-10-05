import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/photographers/presentation/widgets/location_parts.dart';

/// A studio's location is one "City, Country" column, and it used to be typed
/// into one box. The box is now a city field and a country dropdown, so the
/// value has to come apart on the way in and go back together on the way out.
///
/// What is already stored is whatever people wrote. None of it can be
/// rejected — it is somebody's profile — so the rule is that anything the
/// parse cannot confidently place stays in the city, where it remains visible
/// and editable rather than being silently dropped.
void main() {
  group('reading a stored location', () {
    test('splits the ordinary "City, Country"', () {
      expect(cityOf('Accra, Ghana'), 'Accra');
      expect(countryCodeOf('Accra, Ghana'), 'GH');
    });

    test('keeps a multi-part city whole', () {
      expect(cityOf('East Legon, Accra, Ghana'), 'East Legon, Accra');
      expect(countryCodeOf('East Legon, Accra, Ghana'), 'GH');
    });

    test('reads a country however it was cased, and as a code', () {
      expect(countryCodeOf('Accra, ghana'), 'GH');
      expect(countryCodeOf('Accra, GH'), 'GH');
      expect(countryCodeOf('Accra, gh'), 'GH');
    });

    test('a bare country is the country, with no city', () {
      expect(cityOf('Ghana'), '');
      expect(countryCodeOf('Ghana'), 'GH');
    });

    test('a bare city is the city, with no country', () {
      expect(cityOf('Accra'), 'Accra');
      expect(countryCodeOf('Accra'), isNull);
    });

    // The one that would quietly destroy data: a comma that is not a
    // city/country boundary. Guessing here would drop "Oxford Street".
    test('a comma that is not a country boundary keeps the whole string', () {
      expect(cityOf('Osu, Oxford Street'), 'Osu, Oxford Street');
      expect(countryCodeOf('Osu, Oxford Street'), isNull);
    });

    test('an empty location is simply empty', () {
      expect(cityOf(''), '');
      expect(countryCodeOf(''), isNull);
    });
  });

  group('writing it back', () {
    test('joins the two halves the way they are stored', () {
      expect(composeLocation(city: 'Accra', countryCode: 'GH'), 'Accra, Ghana');
    });

    test('a city with no country yet is not given a stray comma', () {
      expect(composeLocation(city: 'Accra'), 'Accra');
    });

    test('a country with no city is just the country', () {
      expect(composeLocation(city: '', countryCode: 'GH'), 'Ghana');
    });

    test('nothing chosen is an empty string, not ", "', () {
      expect(composeLocation(city: ''), '');
    });

    test('whitespace does not survive the trip', () {
      expect(composeLocation(city: '  Accra  ', countryCode: 'GH'),
          'Accra, Ghana');
    });
  });

  group('a round trip', () {
    // Editing a profile and saving it without touching the location must not
    // change it. Anything that fails here rewrites real profiles on save.
    for (final stored in [
      'Accra, Ghana',
      'East Legon, Accra, Ghana',
      'Accra',
      'Ghana',
      '',
    ]) {
      test('"$stored" survives being read and written back', () {
        expect(
          composeLocation(
            city: cityOf(stored),
            countryCode: countryCodeOf(stored),
          ),
          stored.trim(),
        );
      });
    }

    // Not identity, deliberately: a typed country is normalised to the list's
    // spelling, which is the whole point of the dropdown.
    test('a typed country is normalised on the way back out', () {
      const stored = 'Accra, gh';
      expect(
        composeLocation(
          city: cityOf(stored),
          countryCode: countryCodeOf(stored),
        ),
        'Accra, Ghana',
      );
    });
  });
}
