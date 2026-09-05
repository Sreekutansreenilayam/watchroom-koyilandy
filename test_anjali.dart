import 'dart:io';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document();
  final fontData = File('assets/fonts/AnjaliOldLipi.ttf').readAsBytesSync();
  final ttf = pw.Font.ttf(fontData.buffer.asByteData());

  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          children: [
            pw.Text('English text 1234567890', style: pw.TextStyle(font: ttf, fontSize: 20)),
            pw.Text('കേരള അഗ്നിശമനസേനാ', style: pw.TextStyle(font: ttf, fontSize: 20)),
            pw.Text('മീഞ്ചന്ത', style: pw.TextStyle(font: ttf, fontSize: 20)),
            pw.Text('SFRO BIJESH P M', style: pw.TextStyle(font: ttf, fontSize: 20)),
          ],
        );
      },
    ),
  );

  final file = File('test_anjali.pdf');
  await file.writeAsBytes(await pdf.save());
  print("Generated test_anjali.pdf");
}
