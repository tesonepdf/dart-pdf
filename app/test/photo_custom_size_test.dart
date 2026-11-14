import 'dart:typed_data';

import 'package:dart_pdf_editor_app/image_to_pdf.dart';
import 'package:dart_pdf_editor_app/standard_sizes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_document/pdf_document.dart';

Uint8List _png(int w, int h) =>
    Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));

void main() {
  test('misura scelta a mano che sta su un A4: foglio A4, foto a misura vera',
      () {
    const size = StandardSize(
        'custom', 'Misura scelta', StandardSizeGroup.other, 100, 150);
    // 800 x 1200 pixel a 100 x 150 mm sono 203,2 dpi
    expect(photoDpi(800, 1200, null, size: size), closeTo(203.2, 0.01));
    final pdf = imageBytesToPdf(_png(800, 1200), size: size);
    final page = PdfDocument.open(pdf).page(0);
    expect(page.cropBox.width, closeTo(595.28, 0.5));
    expect(page.cropBox.height, closeTo(841.89, 0.5));
  });

  test('misura scelta piu\' grande di un A4: il foglio si fa grande quanto serve',
      () {
    const size = StandardSize(
        'custom', 'Misura scelta', StandardSizeGroup.other, 400, 600);
    final pdf = imageBytesToPdf(_png(800, 1200), size: size);
    final page = PdfDocument.open(pdf).page(0);
    expect(page.cropBox.width, closeTo(mmToPoints(400) + 2 * 28.35, 0.5));
    expect(page.cropBox.height, closeTo(mmToPoints(600) + 2 * 28.35, 0.5));
  });
}
