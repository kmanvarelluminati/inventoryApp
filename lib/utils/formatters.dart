String formatCurrency(double value) {
  return '₹${value.toStringAsFixed(2)}';
}

String formatNullableCurrency(double? value) {
  if (value == null) {
    return '-';
  }
  return formatCurrency(value);
}

String formatDate(DateTime date) {
  return '${date.year}-${_pad2(date.month)}-${_pad2(date.day)}';
}

String formatDateTime(String isoTimestamp) {
  DateTime parsed;
  try {
    parsed = DateTime.parse(isoTimestamp);
  } catch (_) {
    return isoTimestamp;
  }
  return '${parsed.year}-${_pad2(parsed.month)}-${_pad2(parsed.day)} '
      '${_pad2(parsed.hour)}:${_pad2(parsed.minute)}';
}

String _pad2(int value) => value.toString().padLeft(2, '0');
