import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Stamps a patient label bar at the bottom of a PNG image.
Future<Uint8List> stampPatientLabel(Uint8List imageBytes, String label) async {
  final codec = await ui.instantiateImageCodec(imageBytes);
  final frame = await codec.getNextFrame();
  final src = frame.image;
  final w = src.width.toDouble();
  final h = src.height.toDouble();
  const barH = 72.0;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(src, Offset.zero, Paint());
  canvas.drawRect(
    Rect.fromLTWH(0, h - barH, w, barH),
    Paint()..color = const Color(0xE60E3A29),
  );

  final tp = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        color: Color(0xFFD4D1C7),
        fontSize: 30,
        fontWeight: FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout(maxWidth: w - 24);
  tp.paint(canvas, Offset(14, h - barH / 2 - tp.height / 2));

  final picture = recorder.endRecording();
  final img = await picture.toImage(src.width, src.height);
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  if (bd == null) return imageBytes; // fallback: return original if encoding fails
  return bd.buffer.asUint8List();
}
