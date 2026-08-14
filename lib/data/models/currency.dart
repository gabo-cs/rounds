import 'package:intl/intl.dart';

/// The currency amounts are entered and displayed in.
///
/// Only the symbol and the punctuation really differ — but that punctuation
/// is the whole point: a Colombian bill reads `$1.500.000`, the same figure
/// in dollars reads `$1,500,000`, in reais `R$1.500.000`.
///
/// Symbol placement is deliberately not taken from the locale. `es_CO`
/// formats currency as `1.000.000 $`, which is correct by CLDR and not how
/// anyone writes it here, so the grouping comes from the locale and the
/// symbol is prefixed by hand.
///
/// [localeName] only drives the separators, so every currency maps onto one
/// of two locales guaranteed to exist in intl's data: `es_CO` for
/// dot-grouping, `en_US` for comma-grouping. Naming a currency's real locale
/// (`es_MX`, `pt_BR`…) would risk intl silently falling back to plain `es`
/// and flipping the separators.
enum Currency {
  cop(symbol: r'$', localeName: 'es_CO', groupSeparator: '.', decimalSeparator: ','),
  usd(symbol: r'$', localeName: 'en_US', groupSeparator: ',', decimalSeparator: '.'),
  eur(symbol: '€', localeName: 'es_CO', groupSeparator: '.', decimalSeparator: ','),
  mxn(symbol: r'$', localeName: 'en_US', groupSeparator: ',', decimalSeparator: '.'),
  brl(symbol: r'R$', localeName: 'es_CO', groupSeparator: '.', decimalSeparator: ','),
  ars(symbol: r'$', localeName: 'es_CO', groupSeparator: '.', decimalSeparator: ','),
  clp(symbol: r'$', localeName: 'es_CO', groupSeparator: '.', decimalSeparator: ','),
  pen(symbol: 'S/', localeName: 'en_US', groupSeparator: ',', decimalSeparator: '.');

  const Currency({
    required this.symbol,
    required this.localeName,
    required this.groupSeparator,
    required this.decimalSeparator,
  });

  final String symbol;
  final String localeName;
  final String groupSeparator;
  final String decimalSeparator;

  /// The ISO code shown in Settings — universal, so it needs no translation.
  String get code => name.toUpperCase();

  /// Amounts are stored as a plain double, so a value either has cents or it
  /// doesn't. Showing `,00` on every Colombian bill would be noise, and hiding
  /// real cents would be wrong — so the decimals appear only when they exist.
  static const maxDecimals = 2;

  NumberFormat get _whole => NumberFormat('#,##0', localeName);
  NumberFormat get _withDecimals => NumberFormat('#,##0.00', localeName);

  /// The amount as it appears in the UI, symbol included: `$1.500.000`.
  String format(double amount) => '$symbol${formatBare(amount)}';

  /// The amount without the symbol, for text fields that show their own.
  String formatBare(double amount) => _hasCents(amount)
      ? _withDecimals.format(amount)
      : _whole.format(amount);

  /// Parse what the user typed. Tolerates a partly-formatted string, since the
  /// input formatter reformats on every keystroke.
  double? parse(String input) {
    final cleaned = input
        .replaceAll(symbol, '')
        .replaceAll(groupSeparator, '')
        .replaceAll(decimalSeparator, '.')
        .trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  // Rounded to the digits actually shown, so 42.999 counts as having cents
  // while 42.00000001 (a double artefact) does not.
  bool _hasCents(double amount) {
    const scale = 100;
    return (amount * scale).round() % scale != 0;
  }
}
