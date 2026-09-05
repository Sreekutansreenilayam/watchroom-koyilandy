String shapeMalayalam(String text) {
  text = text.replaceAll('\u0D4A', '\u0D46\u0D3E');
  text = text.replaceAll('\u0D4B', '\u0D47\u0D3E');
  text = text.replaceAll('\u0D4C', '\u0D46\u0D57');
  final regex = RegExp(r'((?:[\u0D15-\u0D39]\u0D4D)*[\u0D15-\u0D39])([\u0D46\u0D47\u0D48])');
  return text.replaceAllMapped(regex, (m) => '${m.group(2)}${m.group(1)}');
}

void main() {
  String normal = "കേരള";
  String formatted = shapeMalayalam(normal);
  print('Normal: $normal');
  print('Formatted: $formatted');
  print('Chars: ${formatted.runes.map((e) => e.toRadixString(16)).join(' ')}');
}
