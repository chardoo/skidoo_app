/// A place, resolved.
///
/// Targeting used to be a list of names — seven hardcoded cities in the
/// campaign wizard, nothing at all on requests — compared by substring against
/// whatever a photographer had typed into their profile. Two strings sharing
/// letters is not a location: it cannot be gated on, and it cannot be measured
/// from.
///
/// So what the app sends and stores is the whole record the search returned:
/// the provider's id, the ISO country code the hard filter reads, and the
/// coordinates the distance ranking reads. Never the text somebody typed.
class Place {
  const Place({
    required this.countryCode,
    this.id,
    this.name,
    this.admin1,
    this.country,
    this.lat,
    this.lon,
  });

  /// The geocoding provider's id. Stable, and what de-duplication keys on —
  /// two towns can share a name inside one country.
  final int? id;

  /// "Accra". Null when this targets a whole country rather than a place in it.
  final String? name;

  /// "Greater Accra Region" — what tells two identically named towns apart.
  final String? admin1;

  /// ISO 3166-1 alpha-2. The one field that is never optional: content aimed
  /// at a country it does not carry cannot be filtered, and the server drops
  /// any target without it.
  final String countryCode;

  /// "Ghana". Display only — the server re-derives it from the code rather
  /// than trusting what is sent.
  final String? country;

  final double? lat;
  final double? lon;

  /// True when this is a country as a whole. It gates, it just does not rank —
  /// there is no point to measure a distance to.
  bool get isCountryWide => name == null || name!.isEmpty;

  /// What a chip shows: "Accra" for a place, "Ghana" for a country.
  String get label => isCountryWide ? (country ?? countryCode) : name!;

  /// The line under it — enough to tell two Accras apart.
  String get subtitle {
    if (isCountryWide) return 'Whole country';
    return [
      if (admin1 != null && admin1!.isNotEmpty) admin1!,
      if (country != null && country!.isNotEmpty) country!,
    ].join(' · ');
  }

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: (json['id'] as num?)?.toInt(),
        name: json['name'] as String?,
        admin1: json['admin1'] as String?,
        countryCode: (json['country_code'] as String? ?? '').toUpperCase(),
        country: json['country'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lon: (json['lon'] as num?)?.toDouble(),
      );

  /// Sent back verbatim. The server re-validates and re-derives anyway, but
  /// round-tripping the whole record keeps the two sides describing one place.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'admin1': admin1,
        'country_code': countryCode,
        'country': country,
        'lat': lat,
        'lon': lon,
      };

  /// Two entries are the same place when they are the same country and the
  /// same point in it. Keyed on the id where there is one, because a name can
  /// repeat and an id cannot.
  Object get identity => id ?? '$countryCode:${(name ?? '').toLowerCase()}';

  @override
  bool operator ==(Object other) =>
      other is Place && other.identity == identity;

  @override
  int get hashCode => identity.hashCode;
}
