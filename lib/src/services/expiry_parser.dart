/// Turns the expiry text OCR reads off a label into a real date.
///
/// The OCR service returns whatever matched the label — `11/2027`,
/// `05/11/2027`, `NOV 2027` — as a string. A string is enough to show the
/// user, but not enough to answer "what expires in the next 30 days", which
/// is the only reason to scan an expiry at all. That question is asked of
/// `batch.expiry_date`, a real `DateTime` column, so the string has to become
/// a date somewhere. It happens here rather than in the OCR service so it can
/// be tested without ML Kit or a device.
///
/// Returns `null` when the text cannot be read as a date. A null expiry is
/// honest — the batch still records its number, and nothing claims a date it
/// does not have.
library;

const _monthNames = <String, int>{
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// Parses an OCR expiry string into the last instant the goods are good for.
///
/// A label that says `11/2027` means "good through November 2027", not
/// "expires on the 1st", so a month-and-year expiry resolves to the **last**
/// day of that month. Resolving it to the first would retire stock up to a
/// month early.
DateTime? parseLabelExpiry(String? raw) {
  if (raw == null) return null;
  final text = raw.trim();
  if (text.isEmpty) return null;

  // Month name: NOV 2027, NOV/27, NOV-2027
  final named = RegExp(r'^([A-Za-z]{3})[\s\/\-\.]+([0-9]{2,4})$').firstMatch(text);
  if (named != null) {
    final month = _monthNames[named.group(1)!.toLowerCase()];
    if (month == null) return null;
    return _endOfMonth(_fullYear(int.parse(named.group(2)!)), month);
  }

  final parts = text.split(RegExp(r'[\/\-\.]')).where((p) => p.isNotEmpty).toList();

  // MM/YYYY — good through the end of that month.
  if (parts.length == 2) {
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    if (month == null || year == null || month < 1 || month > 12) return null;
    return _endOfMonth(_fullYear(year), month);
  }

  // DD/MM/YYYY. Indian labels print day first, which is also what the rest of
  // the app formats. Where the day is impossible but the month is not, the
  // label was printed MM/DD and the two are swapped rather than rejected.
  if (parts.length == 3) {
    var day = int.tryParse(parts[0]);
    var month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (month > 12 && day <= 12) {
      final swap = day;
      day = month;
      month = swap;
    }
    if (month < 1 || month > 12 || day < 1) return null;
    final full = _fullYear(year);
    if (day > _daysInMonth(full, month)) return null;
    return DateTime(full, month, day, 23, 59, 59);
  }

  return null;
}

/// `27` means 2027, not year 27. Labels print expiries in the future, so a
/// bare two-digit year is always this century.
int _fullYear(int year) => year < 100 ? 2000 + year : year;

/// Day 0 of the following month is the last day of this one.
int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime _endOfMonth(int year, int month) =>
    DateTime(year, month, _daysInMonth(year, month), 23, 59, 59);
