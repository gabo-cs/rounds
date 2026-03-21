import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _compactFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

extension DoubleFormatExtensions on double {
  String get asCurrency => _currencyFormat.format(this);

  String get asCurrencyCompact {
    if (this == truncateToDouble()) return _compactFormat.format(this);
    return _currencyFormat.format(this);
  }
}
