/// How money is written on screen.
///
/// Prices reach this app from three places that all produce different
/// precision: a shopkeeper typing, a CSV import, and the OCR label scanner.
/// A cost derived as `mrp * 0.82` lands as 61.499999999999994, and showing
/// that is bad in a label and worse in an editable field, where the user has
/// to delete it by hand before they can type their own.
///
/// Rupees are rounded to paise, and whole amounts lose the decimals: ₹75,
/// not ₹75.00. A price tag does not write the zeros either.
String formatAmount(double value) {
  final rounded = double.parse(value.toStringAsFixed(2));
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(2);
}

/// [formatAmount] with the currency symbol.
String formatRupees(double value) => '₹${formatAmount(value)}';
