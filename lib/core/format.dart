/// ₦184,250.00 style formatting without pulling in intl.
String formatNaira(num value, {bool decimals = false, bool signed = false}) {
  final negative = value < 0;
  final abs = value.abs();
  final whole = abs.truncate();
  final digits = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  var out = '₦$buf';
  if (decimals) {
    final cents = ((abs - whole) * 100).round().toString().padLeft(2, '0');
    out = '$out.$cents';
  }
  if (negative) return '-$out';
  if (signed) return '+$out';
  return out;
}

String formatShortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
