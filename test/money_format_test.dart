// Prices reach this app from a shopkeeper typing, a CSV import and the OCR
// label scanner, and only the first of those produces clean numbers.
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/ui/money_format.dart';

void main() {
  test('whole rupees lose the decimals, the way a price tag does', () {
    expect(formatAmount(75), '75');
    expect(formatAmount(0), '0');
    expect(formatAmount(420), '420');
    expect(formatRupees(620), '₹620');
  });

  test('paise are kept, to exactly two places', () {
    expect(formatAmount(61.5), '61.50');
    expect(formatAmount(12.25), '12.25');
    expect(formatRupees(9.99), '₹9.99');
  });

  test('float noise never reaches the screen', () {
    // The case that put 61.49999999999999 into an editable price field: a
    // cost derived as 75 * 0.82 and stored as a double.
    expect(formatAmount(75 * 0.82), '61.50');
    expect(formatAmount(0.1 + 0.2), '0.30');
    expect(formatAmount(1.005), isNot(contains('99')));
  });

  test('more precision than paise is rounded away, not truncated', () {
    expect(formatAmount(10.999), '11');
    expect(formatAmount(10.994), '10.99');
    expect(formatAmount(10.996), '11');
  });

  test('a negative amount keeps its sign', () {
    // Nothing writes one today, but a margin shown as a loss would.
    expect(formatAmount(-12.5), '-12.50');
    expect(formatAmount(-40), '-40');
  });
}
