import 'package:dart_pdf_editor_app/apply_photo_size.dart';
import 'package:dart_pdf_editor_app/standard_sizes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_document/pdf_document.dart' show PdfRect;

void main() {
  const landscape = PdfRect(0, 0, 200, 100); // 2:1, in orizzontale

  test('stesse proporzioni: la foto entra nella misura e resta centrata', () {
    final r = resizedPhotoRect(
      current: landscape,
      pageRotation: 0,
      choice: const PhotoSizeChoice(
          widthMm: 102, heightMm: 152, keepProportions: true),
    );
    // la misura 10 x 15 si gira in orizzontale (15 x 10) come la foto
    expect(r.width, closeTo(mmToPoints(152), 0.01));
    expect(r.height, closeTo(mmToPoints(152) / 2, 0.01));
    expect((r.left + r.right) / 2, closeTo(100, 0.001));
    expect((r.bottom + r.top) / 2, closeTo(50, 0.001));
  });

  test('misura esatta: prende larghezza e altezza della misura', () {
    final r = resizedPhotoRect(
      current: landscape,
      pageRotation: 0,
      choice: const PhotoSizeChoice(
          widthMm: 102, heightMm: 152, keepProportions: false),
    );
    expect(r.width, closeTo(mmToPoints(152), 0.01));
    expect(r.height, closeTo(mmToPoints(102), 0.01));
  });

  test('una foto in verticale tiene la misura in verticale', () {
    final r = resizedPhotoRect(
      current: const PdfRect(0, 0, 100, 200),
      pageRotation: 0,
      choice: const PhotoSizeChoice(
          widthMm: 152, heightMm: 102, keepProportions: false),
    );
    expect(r.width, closeTo(mmToPoints(102), 0.01));
    expect(r.height, closeTo(mmToPoints(152), 0.01));
  });

  test('pagina ruotata di 90 gradi: larghezza e altezza a schermo scambiate',
      () {
    // nello spazio della pagina 100 x 200, a schermo 200 x 100 (orizzontale)
    final r = resizedPhotoRect(
      current: const PdfRect(0, 0, 100, 200),
      pageRotation: 90,
      choice: const PhotoSizeChoice(
          widthMm: 102, heightMm: 152, keepProportions: false),
    );
    // a schermo 152 x 102, nello spazio della pagina 102 x 152
    expect(r.width, closeTo(mmToPoints(102), 0.01));
    expect(r.height, closeTo(mmToPoints(152), 0.01));
  });
}
