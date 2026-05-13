/// Exchange rates returned by GET /config/rates.
/// base is always "GHS" — meaning 1 GHS = rates[currency] units of that currency.
class ExchangeRates {
  const ExchangeRates({
    this.base = 'GHS',
    this.rates = const {},
  });

  final String base;
  final Map<String, double> rates;

  factory ExchangeRates.fromJson(Map<String, dynamic> json) {
    final raw = json['rates'];
    final Map<String, double> parsed = {};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is num) parsed[k.toString()] = v.toDouble();
      });
    }
    return ExchangeRates(
      base: json['base'] as String? ?? 'GHS',
      rates: parsed,
    );
  }

  /// Convert [amount] in [currency] to GHS.
  /// Formula: amount / rate  (since 1 GHS = rate units of currency).
  double toGhs(double amount, String currency) {
    if (currency == 'GHS' || currency.isEmpty) return amount;
    final rate = rates[currency];
    if (rate == null || rate == 0) return amount;
    return amount / rate;
  }

  /// Format a GHS amount with thousand separators and 2 decimal places.
  static String formatGhs(double amount) {
    final rounded = amount.toStringAsFixed(2);
    final parts = rounded.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return 'GHS $intPart.${parts[1]}';
  }

  bool get isEmpty => rates.isEmpty;
}
