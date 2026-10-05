import 'package:jperg_app/features/settings/data/profile_options.dart';

/// Splitting and rejoining a studio's "City, Country".
///
/// The field was split in the UI, not in the record. `location` is a single
/// column, and the profile, the search index and every card that prints it
/// read it as one line — so the two controls compose back into the same shape
/// on the way out, and parse it back apart on the way in.
///
/// All of this exists because the value used to be typed. What is already
/// stored is whatever people wrote: "Accra, Ghana", "accra gh", "Ghana" with
/// no city at all, "East Legon, Accra, Ghana". None of it can be rejected now
/// — it is somebody's profile — so the parse keeps anything it cannot place
/// as the city rather than dropping it.

/// A country name or ISO code, however it was cased, as a code.
///
/// Null when the text names no country this app offers. "Ghana", "ghana" and
/// "GH" are all in the data and all mean the same country.
String? matchCountry(String raw) {
  final needle = raw.trim().toLowerCase();
  if (needle.isEmpty) return null;
  for (final entry in kCountryOptions.entries) {
    if (entry.key.toLowerCase() == needle ||
        entry.value.toLowerCase() == needle) {
      return entry.key;
    }
  }
  return null;
}

/// The city half of a stored location.
///
/// Split on the *last* comma: "Accra, Ghana" has one, but so does
/// "East Legon, Accra, Ghana", and the country is always the final part. When
/// the part after that comma is not a country the whole string is the city —
/// "Osu, Oxford Street" must not lose half of itself to a guess.
String cityOf(String stored) {
  final at = stored.lastIndexOf(',');
  if (at < 0) {
    // No comma: a bare country name is a country, anything else is a city.
    return matchCountry(stored) == null ? stored.trim() : '';
  }
  final tail = stored.substring(at + 1);
  return matchCountry(tail) == null
      ? stored.trim()
      : stored.substring(0, at).trim();
}

/// The country half of a stored location, as an ISO code, or null.
String? countryCodeOf(String stored) {
  final at = stored.lastIndexOf(',');
  if (at < 0) return matchCountry(stored);
  return matchCountry(stored.substring(at + 1));
}

/// The two halves back into the one line that gets stored.
String composeLocation({required String city, String? countryCode}) {
  final trimmedCity = city.trim();
  final country = countryCode == null ? '' : kCountryOptions[countryCode] ?? '';
  if (trimmedCity.isEmpty) return country;
  if (country.isEmpty) return trimmedCity;
  return '$trimmedCity, $country';
}
