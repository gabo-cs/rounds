import 'package:intl/intl.dart';

/// The currency amounts are entered and displayed in.
///
/// Only the punctuation really differs — both write the symbol as `$` — but
/// that punctuation is the whole point: a Colombian bill reads `$1.500.000`,
/// the same figure in dollars reads `$1,500,000`.
///
/// Symbol placement is deliberately not taken from the locale. `es_CO` formats
/// currency as `1.000.000 $`, which is correct by CLDR and not how anyone
/// writes it here, so the grouping comes from the locale and the symbol is
/// prefixed by hand.
enum Currency {
  cop(localeName: 'es_CO', groupSeparator: '.', decimalSeparator: ','),
  usd(localeName: 'en_US', groupSeparator: ',', decimalSeparator: '.');

  const Currency({
    required this.localeName,
    required this.groupSeparator,
    required this.decimalSeparator,
  });

  final String localeName;
  final String groupSeparator;
  final String decimalSeparator;

  static const symbol = r'$';

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
