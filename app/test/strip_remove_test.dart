// Togli spazio vuoto (strip_remove.dart): la pagina nuova, piu' stretta o piu'
// larga, fatta con la parte a sinistra e quella a destra della striscia; e,
// con la striscia orizzontale, piu' bassa o piu' alta, con la parte sopra e
// quella sotto.
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

    test('lo spessore della striscia dipende dall\'orientamento', () {
      const strip = Rect.fromLTRB(0.25, 0.1, 0.75, 0.4);
      expect(stripThicknessPt(600, 800, strip), closeTo(300, 0.001));
      expect(stripThicknessPt(600, 800, strip, horizontal: true),
          closeTo(240, 0.001));
    });

    test('girare la selezione la porta di un quarto di giro attorno al centro',
        () {
      // Pagina quadrata: larghezza e altezza si scambiano, il centro resta.
      final turned =
          rotateStripSelection(const Rect.fromLTRB(0.4, 0.1, 0.5, 0.9), 1);
      expect(turned.center.dx, closeTo(0.45, 0.001));
      expect(turned.center.dy, closeTo(0.5, 0.001));
      expect(turned.width, closeTo(0.8, 0.001));
      expect(turned.height, closeTo(0.1, 0.001));
    });

    test('girare tiene conto della forma della pagina (misure vere uguali)',
        () {
      // Pagina alta il doppio: 0.1 di larghezza = 0.05 di altezza in punti.
      const aspect = 0.5;
      const sel = Rect.fromLTRB(0.4, 0.2, 0.5, 0.6);
      final turned = rotateStripSelection(sel, aspect);
      // Larghezza vera prima: 0.1 * W; altezza vera dopo: 0.1 * W / H * H.
      expect(turned.height * 1.0, closeTo(sel.width * aspect, 0.001));
      expect(turned.width, closeTo(sel.height / aspect, 0.001));
    });

    test('la selezione girata resta dentro la pagina', () {
      final turned =
          rotateStripSelection(const Rect.fromLTRB(0.9, 0.0, 1.0, 1.0), 1);
      expect(turned.left, greaterThanOrEqualTo(0));
      expect(turned.top, greaterThanOrEqualTo(0));
      expect(turned.right, lessThanOrEqualTo(1.0 + 1e-9));
      expect(turned.bottom, lessThanOrEqualTo(1.0 + 1e-9));
    });

    test('due giri riportano la selezione dov\'era', () {
      const sel = Rect.fromLTRB(0.3, 0.2, 0.4, 0.5);
      final back = rotateStripSelection(rotateStripSelection(sel, 0.7), 0.7);
      expect(back.left, closeTo(sel.left, 0.001));
      expect(back.top, closeTo(sel.top, 0.001));
      expect(back.right, closeTo(sel.right, 0.001));
      expect(back.bottom, closeTo(sel.bottom, 0.001));
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

    test('la pagina sistemata prende il posto di quella vecchia', () {
      // Come fa l'app: una sola modifica, cosi' Annulla e Ripeti funzionano.
      final adjusted = PdfDocument.open(removePageStrip(
          source: source,
          page: 0,
          strip: const Rect.fromLTRB(0.25, 0, 0.75, 1),
          gap: 0));
      final doc = PdfDocument.open(buildClassicPdf());
      final before = doc.pageCount;
      PdfEditor(doc)
        ..appendPagesFrom(adjusted, at: 1, outlines: false)
        ..removePage(0);
      expect(doc.pageCount, before);
      final p = doc.page(0);
      final s = pdfRegionDisplaySize(p.cropBox, p.rotation);
      expect(s.width, closeTo(size.width * 0.5, 0.5));
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

  group('striscia orizzontale', () {
    test('togliendo tutta la fascia la pagina si abbassa', () {
      const strip = Rect.fromLTRB(0, 0.25, 1, 0.75);
      final out = removePageStrip(
          source: source, page: 0, strip: strip, gap: 0, horizontal: true);
      final s = sizeOf(out);
      expect(s.height, closeTo(size.height * 0.5, 0.5));
      expect(s.width, closeTo(size.width, 0.5));
    });

    test('lasciando uno spazio la pagina e\' piu\' alta di tanto', () {
      const strip = Rect.fromLTRB(0, 0.25, 1, 0.75);
      final out = removePageStrip(
          source: source, page: 0, strip: strip, gap: 20, horizontal: true);
      expect(sizeOf(out).height, closeTo(size.height * 0.5 + 20, 0.5));
    });

    test('con uno spazio piu\' grande della fascia la pagina si allarga', () {
      const strip = Rect.fromLTRB(0, 0.4, 1, 0.5);
      final out = removePageStrip(
          source: source,
          page: 0,
          strip: strip,
          gap: size.height * 0.4,
          horizontal: true);
      expect(sizeOf(out).height, closeTo(size.height * 1.3, 1));
    });

    test('conta solo l\'altezza del rettangolo, non la larghezza', () {
      const wide = Rect.fromLTRB(0, 0.25, 1, 0.75);
      const narrow = Rect.fromLTRB(0.4, 0.25, 0.5, 0.75);
      final a = removePageStrip(
          source: source, page: 0, strip: wide, gap: 0, horizontal: true);
      final b = removePageStrip(
          source: source, page: 0, strip: narrow, gap: 0, horizontal: true);
      expect(sizeOf(a).height, closeTo(sizeOf(b).height, 0.001));
      expect(sizeOf(a).width, closeTo(sizeOf(b).width, 0.001));
    });

    test('una fascia fino al bordo lascia solo l\'altra parte', () {
      const strip = Rect.fromLTRB(0, 0, 1, 0.4);
      final out = removePageStrip(
          source: source, page: 0, strip: strip, gap: 0, horizontal: true);
      expect(sizeOf(out).height, closeTo(size.height * 0.6, 0.5));
    });

    test('il testo resta nella pagina nuova', () {
      const strip = Rect.fromLTRB(0, 0.95, 1, 1);
      final out = removePageStrip(
          source: source, page: 0, strip: strip, gap: 0, horizontal: true);
      final doc = PdfDocument.open(Uint8List.fromList(out));
      expect(PdfTextExtractor.extract(doc, 0).text, contains('Hello'));
    });

    test('la pagina sistemata prende il posto di quella vecchia', () {
      final adjusted = PdfDocument.open(removePageStrip(
          source: source,
          page: 0,
          strip: const Rect.fromLTRB(0, 0.25, 1, 0.75),
          gap: 0,
          horizontal: true));
      final doc = PdfDocument.open(buildClassicPdf());
      final before = doc.pageCount;
      PdfEditor(doc)
        ..appendPagesFrom(adjusted, at: 1, outlines: false)
        ..removePage(0);
      expect(doc.pageCount, before);
      final p = doc.page(0);
      final s = pdfRegionDisplaySize(p.cropBox, p.rotation);
      expect(s.height, closeTo(size.height * 0.5, 0.5));
    });

    test('se non resta niente lo dice', () {
      expect(
        () => removePageStrip(
            source: source,
            page: 0,
            strip: const Rect.fromLTRB(0, 0, 1, 1),
            gap: 0,
            horizontal: true),
        throwsFormatException,
      );
    });
  });
}
