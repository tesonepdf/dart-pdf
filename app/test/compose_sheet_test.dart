import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_document/pdf_document.dart';

import 'package:dart_pdf_editor_app/compose_sheet.dart';

void main() {
  const pageW = 595.28;
  const pageH = 841.89;

  /// Un PDF A4 di [pages] pagine, già aperto.
  (Uint8List, PdfDocument) source(int pages) {
    final bytes =
        PdfBlankDocument.create(pageSize: PdfPageSize.a4, pageCount: pages);
    return (bytes, PdfDocument.open(bytes));
  }

  SheetCrop crop(
    Uint8List bytes,
    PdfDocument document,
    int page,
    PdfRect region, {
    int rotation = 0,
  }) {
    final box = document.page(page).cropBox;
    return SheetCrop(
      name: 'prova.pdf',
      source: document,
      page: page,
      region: region,
      rotation: rotation,
      sourceBytes: bytes,
      pageSize: pdfRegionDisplaySize(box, rotation),
      fraction: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }

  group('layoutSheetCrops', () {
    test('uno posto per ogni ritaglio, dentro il foglio', () {
      final sizes = [
        for (var i = 0; i < 7; i++) (width: 200.0, height: 120.0),
      ];
      final placed = layoutSheetCrops(sizes);
      expect(placed, hasLength(sizes.length));
      for (var i = 0; i < placed.length; i++) {
        final p = placed[i];
        expect(p.x, greaterThanOrEqualTo(0));
        expect(p.y, greaterThanOrEqualTo(0));
        expect(p.x + sizes[i].width * p.scale, lessThanOrEqualTo(pageW + 0.01));
        expect(
            p.y + sizes[i].height * p.scale, lessThanOrEqualTo(pageH + 0.01));
      }
    });

    test('due ritagli piccoli stanno sullo stesso foglio', () {
      final placed = layoutSheetCrops([
        (width: 150.0, height: 100.0),
        (width: 150.0, height: 100.0),
      ]);
      expect(placed[0].sheet, 0);
      expect(placed[1].sheet, 0);
    });

    test('un ritaglio alto quanto l\'area utile non lascia un foglio vuoto', () {
      final placed = layoutSheetCrops([(width: 100.0, height: 801.89)]);
      expect(placed.single.sheet, 0);
    });

    test('un ritaglio più grande del foglio si riduce per starci', () {
      final placed = layoutSheetCrops([(width: 2000.0, height: 3000.0)]);
      expect(placed.single.scale, lessThan(1));
      expect(2000.0 * placed.single.scale, lessThanOrEqualTo(pageW + 0.01));
      expect(3000.0 * placed.single.scale, lessThanOrEqualTo(pageH + 0.01));
    });

    test('quando non c\'è più spazio si passa a un nuovo foglio', () {
      final placed = layoutSheetCrops([
        for (var i = 0; i < 4; i++) (width: 500.0, height: 500.0),
      ]);
      final sheets = {for (final p in placed) p.sheet};
      expect(sheets.length, greaterThan(1));
    });
  });

  group('regionFromSelection', () {
    const box = PdfRect(0, 0, 200, 100);
    const quarter = Rect.fromLTRB(0, 0, 0.5, 0.5);

    test('pagina dritta: il quarto in alto a sinistra', () {
      final r = regionFromSelection(quarter, box, 0);
      expect(r.left, closeTo(0, 1e-6));
      expect(r.right, closeTo(100, 1e-6));
      expect(r.bottom, closeTo(50, 1e-6));
      expect(r.top, closeTo(100, 1e-6));
    });

    test('pagina ruotata di 90 gradi', () {
      final r = regionFromSelection(quarter, box, 90);
      expect(r.left, closeTo(0, 1e-6));
      expect(r.right, closeTo(100, 1e-6));
      expect(r.bottom, closeTo(0, 1e-6));
      expect(r.top, closeTo(50, 1e-6));
    });

    test('pagina ruotata di 180 gradi', () {
      final r = regionFromSelection(quarter, box, 180);
      expect(r.left, closeTo(100, 1e-6));
      expect(r.right, closeTo(200, 1e-6));
      expect(r.bottom, closeTo(0, 1e-6));
      expect(r.top, closeTo(50, 1e-6));
    });

    test('pagina ruotata di 270 gradi', () {
      final r = regionFromSelection(quarter, box, 270);
      expect(r.left, closeTo(100, 1e-6));
      expect(r.right, closeTo(200, 1e-6));
      expect(r.bottom, closeTo(50, 1e-6));
      expect(r.top, closeTo(100, 1e-6));
    });
  });

  group('composeSheets', () {
    test('metà alta di un PDF e metà bassa di un altro: un solo foglio', () {
      final (bytesA, docA) = source(1);
      final (bytesB, docB) = source(1);
      final box = docA.page(0).cropBox;
      final half = box.height / 2;
      final result = composeSheets([
        crop(bytesA, docA, 0,
            PdfRect(box.left, box.bottom + half, box.right, box.top)),
        crop(bytesB, docB, 0,
            PdfRect(box.left, box.bottom, box.right, box.bottom + half)),
      ]);
      expect(PdfDocument.open(result).pageCount, 1);
    });

    test('più ritagli grandi vanno su più fogli', () {
      final (bytes, doc) = source(3);
      final box = doc.page(0).cropBox;
      final result = composeSheets([
        for (var i = 0; i < 3; i++) crop(bytes, doc, i, box),
      ]);
      expect(PdfDocument.open(result).pageCount, 3);
    });

    test('un ritaglio ruotato di un quarto di giro si compone', () {
      final (bytes, doc) = source(1);
      final box = doc.page(0).cropBox;
      final crops = [crop(bytes, doc, 0, box)];
      for (var turns = 0; turns < 4; turns++) {
        final result = composeSheets(
          crops,
          placements: [SheetPlacement(0, 20, 20, 0.5, turns)],
        );
        expect(PdfDocument.open(result).pageCount, 1);
      }
    });

    test('lo stesso ritaglio posto due volte non rompe il file', () {
      final (bytes, doc) = source(1);
      final box = doc.page(0).cropBox;
      final c = crop(bytes, doc, 0, box);
      final result = composeSheets(
        [c, c],
        placements: const [
          SheetPlacement(0, 10, 10, 0.3),
          SheetPlacement(0, 300, 400, 0.3, 2),
        ],
      );
      expect(PdfDocument.open(result).pageCount, 1);
    });
  });
}
