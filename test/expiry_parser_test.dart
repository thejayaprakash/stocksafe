// Reading a date off a label.
//
// The OCR feature is advertised as "MRP, Expiry, Pack" and the app has an
// "Expiring Soon" tab driven by batch.expiry_date. Between the two sits this
// parser: if it returns null the scan is decorative, and if it returns the
// wrong day stock is retired early or late.
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/services/expiry_parser.dart';

void main() {
  group('Month and year', () {
    test('resolves to the last day, not the first', () {
      // "11/2027" on a packet means good through November, so the 30th.
      // The 1st would throw away a month of shelf life.
      expect(parseLabelExpiry('11/2027'), DateTime(2027, 11, 30, 23, 59, 59));
    });

    test('handles February in a leap year', () {
      expect(parseLabelExpiry('02/2028'), DateTime(2028, 2, 29, 23, 59, 59));
      expect(parseLabelExpiry('02/2027'), DateTime(2027, 2, 28, 23, 59, 59));
    });

    test('two-digit years are this century', () {
      expect(parseLabelExpiry('11/27'), DateTime(2027, 11, 30, 23, 59, 59));
    });

    test('accepts the separators labels actually use', () {
      for (final text in ['11/2027', '11-2027', '11.2027']) {
        expect(parseLabelExpiry(text), DateTime(2027, 11, 30, 23, 59, 59),
            reason: text);
      }
    });
  });

  group('Day, month and year', () {
    test('reads day first, as Indian labels print it', () {
      expect(parseLabelExpiry('05/11/2027'), DateTime(2027, 11, 5, 23, 59, 59));
    });

    test('swaps when the day is impossible but the month is not', () {
      // 25/12 cannot be month 25, so the label was printed MM/DD.
      expect(parseLabelExpiry('25/12/2027'), DateTime(2027, 12, 25, 23, 59, 59));
    });

    test('rejects a day that does not exist in that month', () {
      expect(parseLabelExpiry('31/11/2027'), isNull);
      expect(parseLabelExpiry('30/02/2027'), isNull);
    });
  });

  group('Month names', () {
    test('reads three-letter months in any case', () {
      expect(parseLabelExpiry('NOV 2027'), DateTime(2027, 11, 30, 23, 59, 59));
      expect(parseLabelExpiry('nov/2027'), DateTime(2027, 11, 30, 23, 59, 59));
      expect(parseLabelExpiry('Nov-27'), DateTime(2027, 11, 30, 23, 59, 59));
    });

    test('rejects something that is not a month', () {
      expect(parseLabelExpiry('XYZ 2027'), isNull);
    });
  });

  group('Refuses rather than guesses', () {
    test('null, empty and whitespace', () {
      expect(parseLabelExpiry(null), isNull);
      expect(parseLabelExpiry(''), isNull);
      expect(parseLabelExpiry('   '), isNull);
    });

    test('nonsense months', () {
      expect(parseLabelExpiry('13/2027'), isNull);
      expect(parseLabelExpiry('00/2027'), isNull);
    });

    test('text that is not a date at all', () {
      for (final text in ['BEST BEFORE', '2027', 'B2026A', '1/2/3/4']) {
        expect(parseLabelExpiry(text), isNull, reason: text);
      }
    });
  });

  group('The expiry window can actually see the result', () {
    test('a near expiry falls inside a 30-day window', () {
      final soon = DateTime.now().add(const Duration(days: 10));
      final parsed = parseLabelExpiry('${soon.day}/${soon.month}/${soon.year}');
      expect(parsed, isNotNull);
      expect(parsed!.isBefore(DateTime.now().add(const Duration(days: 30))), isTrue);
    });

    test('a far expiry does not', () {
      final parsed = parseLabelExpiry('11/2027');
      expect(parsed!.isAfter(DateTime.now().add(const Duration(days: 30))), isTrue);
    });
  });
}
