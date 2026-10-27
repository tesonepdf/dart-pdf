import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';
import 'package:test/test.dart';

void main() {
  test('detects skewed rules in PNG and JPEG page images', () {
    final image = img.Image(width: 1000, height: 800, numChannels: 3)
      ..clear(img.ColorRgb8(255, 255, 255));
    for (final startY in [150, 350, 550]) {
      for (var x = 50; x < 950; x++) {
        final y = startY + ((x - 500) * 0.035).round();
        for (var dy = -1; dy <= 1; dy++) {
          image.setPixel(x, y + dy, img.ColorRgb8(0, 0, 0));
        }
      }
    }

    final encodedImages = [
      Uint8List.fromList(img.encodePng(image)),
      Uint8List.fromList(img.encodeJpg(image, quality: 100)),
    ];
    for (final bytes in encodedImages) {
      final document =
          PdfDocument.open(PdfImageDocument.fromImageBytes([bytes]));
      final fields = PdfLineFieldDetector.detect(document, 0);

      expect(
        fields.any((field) => field.width > 700 && field.slope < -0.02),
        isTrue,
      );
    }
  });
}
