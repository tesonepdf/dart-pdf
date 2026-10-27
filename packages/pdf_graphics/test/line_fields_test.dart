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

  test('detects dotted rules under uneven lighting and blur', () {
    final image = img.Image(width: 1000, height: 800, numChannels: 3);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final shade = (175 + 75 * x / image.width).round();
        image.setPixel(x, y, img.ColorRgb8(shade, shade, shade));
      }
    }

    for (var x = 100; x < 900; x += 5) {
      final y = 400 + ((x - 500) * 0.035).round();
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = 0; dx < 3; dx++) {
          image.setPixel(x + dx, y + dy, img.ColorRgb8(65, 65, 65));
        }
      }
    }

    final blurred = img.gaussianBlur(image, radius: 1);
    final bytes = Uint8List.fromList(img.encodeJpg(blurred, quality: 75));
    final document = PdfDocument.open(PdfImageDocument.fromImageBytes([bytes]));
    final fields = PdfLineFieldDetector.detect(document, 0);

    expect(fields.any((field) => field.width > 600), isTrue);
  });
}
