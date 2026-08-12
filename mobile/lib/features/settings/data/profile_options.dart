/// The fixed lists the profile form offers: where you are, what language you
/// read, what time it is where you are, and what you photograph.
///
/// Lifted out of the old settings page so the redesigned Edit Profile screen
/// and the card it replaces cannot drift apart while both exist. Same values,
/// same keys — the keys are what the API stores.

const Map<String, String> kCountryOptions = {
  'GH': 'Ghana',
  'NG': 'Nigeria',
  'KE': 'Kenya',
  'ZA': 'South Africa',
  'EG': 'Egypt',
  'MA': 'Morocco',
  'US': 'United States',
  'CA': 'Canada',
  'GB': 'United Kingdom',
  'IE': 'Ireland',
  'DE': 'Germany',
  'FR': 'France',
  'ES': 'Spain',
  'PT': 'Portugal',
  'IT': 'Italy',
  'NL': 'Netherlands',
  'BE': 'Belgium',
  'CH': 'Switzerland',
  'SE': 'Sweden',
  'NO': 'Norway',
  'DK': 'Denmark',
  'AE': 'United Arab Emirates',
  'SA': 'Saudi Arabia',
  'IN': 'India',
  'CN': 'China',
  'JP': 'Japan',
  'SG': 'Singapore',
  'AU': 'Australia',
  'NZ': 'New Zealand',
  'BR': 'Brazil',
  'MX': 'Mexico',
};

const Map<String, String> kLanguageOptions = {
  'en': 'English',
  'de': 'German',
  'fr': 'French',
  'es': 'Spanish',
  'pt': 'Portuguese',
  'ar': 'Arabic',
};

const Map<String, String> kLocaleOptions = {
  'en_US': 'English (US)',
  'en_GB': 'English (UK)',
  'de_DE': 'German (Germany)',
  'fr_FR': 'French (France)',
  'es_ES': 'Spanish (Spain)',
  'pt_PT': 'Portuguese (Portugal)',
  'it_IT': 'Italian (Italy)',
  'nl_NL': 'Dutch (Netherlands)',
};

const Map<String, String> kTimezoneOptions = {
  'UTC': 'UTC',
  'Africa/Accra': 'Accra',
  'Africa/Lagos': 'Lagos',
  'Africa/Nairobi': 'Nairobi',
  'Africa/Johannesburg': 'Johannesburg',
  'Africa/Cairo': 'Cairo',
  'Europe/London': 'London',
  'Europe/Berlin': 'Berlin',
  'Europe/Paris': 'Paris',
  'Europe/Madrid': 'Madrid',
  'Europe/Rome': 'Rome',
  'Europe/Amsterdam': 'Amsterdam',
  'America/New_York': 'New York',
  'America/Chicago': 'Chicago',
  'America/Denver': 'Denver',
  'America/Los_Angeles': 'Los Angeles',
  'America/Sao_Paulo': 'São Paulo',
  'America/Mexico_City': 'Mexico City',
  'Asia/Dubai': 'Dubai',
  'Asia/Kolkata': 'Kolkata',
  'Asia/Shanghai': 'Shanghai',
  'Asia/Tokyo': 'Tokyo',
  'Asia/Singapore': 'Singapore',
  'Australia/Sydney': 'Sydney',
  'Pacific/Auckland': 'Auckland',
};

/// What somebody photographs, or wants photographed. The chips on the profile
/// form, and the tags the feed is personalised from.
const List<String> kInterestTags = [
  'Portrait',
  'Landscape',
  'Street',
  'Wildlife',
  'Architecture',
  'Sports',
  'Travel',
  'Macro',
  'Fashion',
  'Wedding',
  'Event',
  'Food',
  'Aerial',
  'Night',
  'Documentary',
  'Abstract',
  'Fine Art',
  'Photojournalism',
];
