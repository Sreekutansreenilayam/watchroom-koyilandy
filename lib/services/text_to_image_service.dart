import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class TextToImageService {
  /// Converts a given text string to a high-resolution PNG byte array
  /// using Flutter's native TextPainter to ensure perfect shaping (e.g. for Malayalam).
  static Future<Uint8List> convertTextToImage(String text, {
    double fontSize = 32, // Generate at higher scale for crisp PDF printing
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.black,
    TextAlign textAlign = TextAlign.left,
  }) async {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          // By not specifying a font family, it uses the system default which supports Malayalam
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
    );

    textPainter.layout();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Draw the text on the transparent canvas
    textPainter.paint(canvas, Offset.zero);
    
    final picture = recorder.endRecording();
    
    // Convert to image
    final img = await picture.toImage(
      textPainter.width.toInt(), 
      textPainter.height.toInt()
    );
    
    // Convert image to PNG bytes
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
