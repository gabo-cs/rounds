import 'package:flutter/services.dart';
import 'package:rounds/data/models/currency.dart';

/// Groups an amount as it is typed: `1000000` becomes `1.000.000` under
/// [Currency.cop], `1,000,000` under [Currency.usd].
///
/// Reformatting on every keystroke moves the text under the cursor, so the
/// caret is restored by counting *significant characters* (digits and the
/// decimal separator) rather than by raw offset — otherwise editing anywhere
/// but the end throws the caret across a separator.
class CurrencyInputFormatter extends TextInputFormatter {
  const CurrencyInputFormatter(this.currency);

  final Currency currency;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final caretInInput =
        newValue.selection.end.clamp(0, newValue.text.length);
    final significantBeforeCaret =
        _countSignificant(newValue.text.substring(0, caretInInput));

    final formatted = _format(newValue.text);
    if (formatted == null) return oldValue;

    // Walk the formatted text until as many significant characters have passed
    // as sat before the caret, so the caret keeps its place in the number.
    var seen = 0;
    var caret = formatted.length;
    for (var i = 0; i < formatted.length; i++) {
      if (seen == significantBeforeCaret) {
        caret = i;
        break;
      }
      if (_isSignificant(formatted[i])) seen++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  /// Returns null when the input can't be interpreted, which leaves the field
  /// unchanged rather than discarding what the user typed.
  String? _format(String input) {
    final buffer = StringBuffer();
    var seenDecimal = false;
    for (final char in input.split('')) {
      if (_isDigit(char)) {
        buffer.write(char);
      } else if (_isDecimalSeparator(char) && !seenDecimal) {
        seenDecimal = true;
        buffer.write('.');
      }
    }
    final digits = buffer.toString();
    if (digits.isEmpty) return '';

    final parts = digits.split('.');
    final whole = parts.first;
    // Kept as typed rather than padded: padding would fight the caret while
    // the user is still entering cents.
    final fraction = parts.length > 1
        ? parts[1].substring(0, parts[1].length.clamp(0, Currency.maxDecimals))
        : null;

    final grouped = _group(whole);
    if (fraction == null) {
      // A trailing separator has to survive, or typing one is impossible.
      return seenDecimal ? '$grouped${currency.decimalSeparator}' : grouped;
    }
    return '$grouped${currency.decimalSeparator}$fraction';
  }

  String _group(String digits) {
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (trimmed.isEmpty) return '0';
    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i > 0 && (trimmed.length - i) % 3 == 0) {
        buffer.write(currency.groupSeparator);
      }
      buffer.write(trimmed[i]);
    }
    return buffer.toString();
  }

  int _countSignificant(String text) =>
      text.split('').where(_isSignificant).length;

  bool _isSignificant(String char) => _isDigit(char) || _isDecimalSeparator(char);

  bool _isDigit(String char) => char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39;

  // Both separators are accepted on input: phone keypads offer whichever the
  // system locale prefers, which need not match the chosen currency.
  bool _isDecimalSeparator(String char) =>
      char == currency.decimalSeparator ||
      (currency.groupSeparator != char && (char == '.' || char == ','));
}
