import 'dart:io';

void main() {
  final file = File('lib/services/fire_report_pdf_generator.dart');
  String content = file.readAsStringSync();
  
  // 1. Add shapeMalayalam method
  String shaperMethod = """
  static String _shape(String text) {
    if (text.isEmpty) return text;
    // Split vowels
    text = text.replaceAll('\\u0D4A', '\\u0D46\\u0D3E');
    text = text.replaceAll('\\u0D4B', '\\u0D47\\u0D3E');
    text = text.replaceAll('\\u0D4C', '\\u0D46\\u0D57');
    // Pre-base vowels reordering
    final regex = RegExp(r'((?:[\\u0D15-\\u0D39]\\u0D4D)*[\\u0D15-\\u0D39])([\\u0D46\\u0D47\\u0D48])');
    text = text.replaceAllMapped(regex, (m) => '\${m.group(2)}\${m.group(1)}');
    return text;
  }
""";

  content = content.replaceFirst('class FireReportPdfGenerator {', 'class FireReportPdfGenerator {\n$shaperMethod');
  
  // 2. Change font to AnjaliOldLipi
  content = content.replaceAll('assets/fonts/NotoSansMalayalam-Regular.ttf', 'assets/fonts/AnjaliOldLipi.ttf');
  
  // 3. Wrap all pw.Text(...) calls with _shape(...) for their text argument.
  content = content.replaceAllMapped(RegExp(r'pw\.Text\(([^,]+),'), (m) {
    String inner = m.group(1)!;
    // if it's already shaped or empty, skip
    if (inner.startsWith('_shape')) return m.group(0)!;
    return 'pw.Text(_shape($inner),';
  });

  file.writeAsStringSync(content);
  print("Done!");
}
