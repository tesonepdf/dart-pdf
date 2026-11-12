// Togli spazio vuoto (strip_remove.dart): la pagina nuova, piu' stretta o piu'
// larga, fatta con la parte a sinistra e quella a destra della striscia.
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart' show PdfTextExtractor;
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';

import 'package:dart_pdf_editor_app/strip_remove.dart';

void main() {
  final source = PdfDocument.open(buildClassicPdf());
  final page = source.page(0);
  final size = pdfRegionDisplaySize(page.cropBox, page.rotation);

  ({double width, double height}) sizeOf(List<int> bytes) {
    final doc = PdfDocument.open(Uint8List.fromList(bytes));
    expect(doc.pageCount, 1);
    final p = doc.page(0);
    return pdfRegionDisplaySize(p.cropBox, p.rotation);
  }

  group('misure', () {
    test('la larghezza della striscia e del risultato', () {
      const strip = Rect.fromLTRB(0.25, 0, 0.75, 1);
      expect(stripWidthPt(600, strip), closeTo(300, 0.001));
      expect(stripResultWidth(600, strip, 0), closeTo(300, 0.001));
      expect(stripResultWidth(600, strip, 10), closeTo(310, 0.001));
      expect(stripResultWidth(600, strip, 400), closeTo(700, 0.001));
    });

    test('il titolo della scheda toglie .pdf e dice la pagina', () {
      expect(stripTabTitle('Cartellino.pdf', 0),
          'Cartellino (pag. 1 regolata).pdf');
      expect(stripTabTitle('', 2), 'documento (pag. 3 regolata).pdf');
    });
  });

  group('nel PDF', () {
    test('togliendo tutta la striscia la pagina si stringe', () {
      const strip = Rect.fromLTRB(0.25, 0, 0.75, 1);
      final out = removePageStrip(
          source: source, page: 0, strip: strip, gap: 0);
      final s = sizeOf(out);
      expect(s.width, closeTo(size.width * 0.5, 0.5));
      expect(s.height, closeTo(size.height, 0.5));
    });

    test('lasciando uno spazio la pagina e\' piu\' larga di tanto', () {
      const strip = Rect.fromLTRB(0.25, 0, 0.75, 1);
      final out = removePageStrip(
          source: source, page: 0, strip: strip, gap: 20);
      expect(sizeOf(out).width, closeTo(size.width * 0.5 + 20, 0.5));
    });

    test('con uno spazio piu\' grande della striscia la pagina si allarga',
        () {
      const strip = Rect.fromLTRB(0.4, 0, 0.5, 1);
      final out = removePageStrip(
          source: source, page: 0, strip: strip, gap: size.width * 0.4);
      expect(sizeOf(out).width, closeTo(size.width * 1.3, 1));
    });

    test('una striscia fino al bordo lascia solo l\'altra parte', () {
      const strip = Rect.fromLTRB(0, 0, 0.4, 1);
      final out = removePageStrip(
          source: source, page: 0, strip: strip, gap: 0);
      expect(sizeOf(out).width, closeTo(size.width * 0.6, 0.5));
    });

    test('il testo resta nella pagina nuova', () {
      const strip = Rect.fromLTRB(0.9, 0, 0.95, 1);
      final out = removePageStrip(
          source: source, page: 0, strip: strip, gap: 0);
      final doc = PdfDocument.open(Uint8List.fromList(out));
      expect(PdfTextExtractor.extract(doc, 0).text, contains('Hello'));
    });

    test('se non resta niente lo dice', () {
      expect(
        () => removePageStrip(
            source: source,
            page: 0,
            strip: const Rect.fromLTRB(0, 0, 1, 1),
            gap: 0),
        throwsFormatException,
      );
    });
  });
}
