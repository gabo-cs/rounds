import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds/core/utils/currency_input_formatter.dart';
import 'package:rounds/data/models/currency.dart';

void main() {
  group('format', () {
    test('groups thousands with the right separator', () {
      expect(Currency.cop.format(1000000), r'$1.000.000');
      expect(Currency.usd.format(1000000), r'$1,000,000');
      expect(Currency.cop.format(1500), r'$1.500');
      expect(Currency.usd.format(1500), r'$1,500');
    });

    test('shows decimals only when the amount has them', () {
      // A Colombian bill is always whole, so trailing zeros would be noise —
      // but real cents must never be hidden.
      expect(Currency.cop.format(150000), r'$150.000');
      expect(Currency.cop.format(150000.5), r'$150.000,50');
      expect(Currency.usd.format(42), r'$42');
      expect(Currency.usd.format(42.5), r'$42.50');
    });

    test('leaves small amounts ungrouped', () {
      expect(Currency.cop.format(999), r'$999');
      expect(Currency.usd.format(0), r'$0');
    });

    test('formatBare omits the symbol, for fields that draw their own', () {
      expect(Currency.cop.formatBare(1000000), '1.000.000');
      expect(Currency.usd.formatBare(1234.5), '1,234.50');
    });
  });

  group('parse', () {
    test('round-trips its own formatting', () {
      for (final currency in Currency.values) {
        for (final amount in [0.0, 999.0, 1500.0, 42.5, 1000000.0, 150000.5]) {
          expect(
            currency.parse(currency.format(amount)),
            amount,
            reason: '${currency.name} / $amount',
          );
        }
      }
    });

    test('returns null for an empty or unparseable string', () {
      expect(Currency.cop.parse(''), isNull);
      expect(Currency.cop.parse('  '), isNull);
      expect(Currency.cop.parse('abc'), isNull);
    });

    test('reads a partly typed value', () {
      // The formatter reformats on every keystroke, so parse sees intermediate
      // states like a trailing separator.
      expect(Currency.usd.parse('1,234.'), 1234);
      expect(Currency.cop.parse('1.234'), 1234);
    });
  });

  group('CurrencyInputFormatter', () {
    /// Types [input] one character at a time, as the field would.
    TextEditingValue type(Currency currency, String input) {
      final formatter = CurrencyInputFormatter(currency);
      var value = TextEditingValue.empty;
      for (final char in input.split('')) {
        final offset = value.selection.end.clamp(0, value.text.length);
        final typed = TextEditingValue(
          text: value.text.replaceRange(offset, offset, char),
          selection: TextSelection.collapsed(offset: offset + 1),
        );
        value = formatter.formatEditUpdate(value, typed);
      }
      return value;
    }

    test('groups as each digit is typed', () {
      expect(type(Currency.cop, '1000000').text, '1.000.000');
      expect(type(Currency.usd, '1000000').text, '1,000,000');
    });

    test('regroups progressively, never showing a raw run of digits', () {
      final formatter = CurrencyInputFormatter(Currency.cop);
      var value = TextEditingValue.empty;
      final seen = <String>[];
      for (final char in '1234567'.split('')) {
        value = formatter.formatEditUpdate(
          value,
          TextEditingValue(
            text: value.text + char,
            selection: TextSelection.collapsed(offset: value.text.length + 1),
          ),
        );
        seen.add(value.text);
      }
      expect(seen, ['1', '12', '123', '1.234', '12.345', '123.456', '1.234.567']);
    });

    test('leaves the caret at the end while typing', () {
      final value = type(Currency.cop, '1000000');

      expect(value.selection.baseOffset, value.text.length);
    });

    test('keeps the caret next to the digit just typed mid-string', () {
      // Insert a 9 after "1" in "1.000" → "19.000", caret after the 9.
      final formatter = CurrencyInputFormatter(Currency.cop);
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '1.000',
          selection: TextSelection.collapsed(offset: 1),
        ),
        const TextEditingValue(
          text: '19.000',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );

      expect(result.text, '19.000');
      expect(result.selection.baseOffset, 2);
    });

    test('accepts a decimal separator and caps the cents', () {
      expect(type(Currency.usd, '1234.567').text, '1,234.56');
      expect(type(Currency.cop, '1234,5').text, '1.234,5');
    });

    test('keeps a trailing separator so cents can be typed at all', () {
      expect(type(Currency.usd, '12.').text, '12.');
    });

    test('ignores a second decimal separator', () {
      expect(type(Currency.usd, '1.2.3').text, '1.23');
    });

    test('drops leading zeros', () {
      expect(type(Currency.cop, '007').text, '7');
    });

    test('strips characters that are not part of a number', () {
      expect(type(Currency.cop, r'1a2$3').text, '123');
    });

    test('produces text its own currency can parse back', () {
      expect(Currency.cop.parse(type(Currency.cop, '1500000').text), 1500000);
      expect(Currency.usd.parse(type(Currency.usd, '1234.56').text), 1234.56);
    });
  });
}
