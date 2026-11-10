// Conversioni del punto 1 (pdf_conversions.dart): PDF in testo semplice e più
// foto in un PDF, una pagina per foto. Solo logica, senza interfaccia.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';

import 'package:dart_pdf_editor_app/pdf_conversions.dart';

Uint8List png(int width, int height) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

void main() {
  group('testo semplice', () {
    test('le pagine si separano con una riga vuota e il testo finisce a capo',
        () {
      expect(joinPageTexts(['Uno\nDue', '  Tre  ']), 'Uno\nDue\n\nTre\n');
      expect(joinPageTexts(const []), '');
    });

    test('a capo di Windows e vecchio Mac diventano a capo normali', () {
      expect(cleanPageText('a\r\nb\rc'), 'a\nb\nc');
    });

    test('plainTextHasContent: falso per spazi e a capo', () {
      expect(plainTextHasContent(''), isFalse);
      expect(plainTextHasContent(' \n\t\n'), isFalse);
      expect(plainTextHasContent('a'), isTrue);
    });

    test('textExportFileName toglie .pdf e mette .txt', () {
      expect(textExportFileName('Report.pdf'), 'Report.txt');
      expect(textExportFileName('REPORT.PDF'), 'REPORT.txt');
      expect(textExportFileName('a.b.pdf'), 'a.b.txt');
      expect(textExportFileName('foto'), 'foto.txt');
      expect(textExportFileName('   '), 'documento.txt');
    });

    test('pdfToPlainText legge il testo di una pagina', () async {
      final pages = <int>[];
      final result = await pdfToPlainText(
        PdfDocument.open(buildClassicPdf()),
        onPage: (page, count) => pages.add(page * 10 + count),
      );
      expect(result.text, contains('Hello, world!'));
      expect(result.failedPages, isEmpty);
      expect(pages, [1]);
    });

    test('pdfToPlainText mette una riga vuota tra le pagine', () async {
      final two =
          PdfMerger.merge([buildClassicPdf(), buildClassicPdf()]);
      final result = await pdfToPlainText(PdfDocument.open(two));
      expect(result.text, contains('Hello, world!\n\nHello, world!'));
      expect(result.text.endsWith('\n'), isTrue);
    });

    test('un PDF senza testo (una scansione) non ha contenuto', () async {
      final blank = PdfBlankDocument.create(pageCount: 2);
      final result = await pdfToPlainText(PdfDocument.open(blank));
      expect(plainTextHasContent(result.text), isFalse);
      expect(result.failedPages, isEmpty);
    });
  });

  group('foto in PDF', () {
    test('A4: una pagina per foto, per traverso se la foto è larga', () {
      final result = photosToPdf([png(40, 20), png(20, 40)], PhotoPdfPage.a4);
      expect(result.pages, 2);
      expect(result.skipped, 0);
      final doc = PdfDocument.open(result.bytes);
      expect(doc.pageCount, 2);
      expect(doc.page(0).mediaBox.width, closeTo(841.89, 0.05));
      expect(doc.page(0).mediaBox.height, closeTo(595.28, 0.05));
      expect(doc.page(1).mediaBox.width, closeTo(595.28, 0.05));
      expect(doc.page(1).mediaBox.height, closeTo(841.89, 0.05));
    });

    test('misura della foto: pagina larga come un A4 con le proporzioni '
        'della foto', () {
      final result = photosToPdf([png(600, 300)], PhotoPdfPage.photoSize);
      final doc = PdfDocument.open(result.bytes);
      expect(doc.pageCount, 1);
      expect(doc.page(0).mediaBox.width, closeTo(595.28, 0.5));
      expect(doc.page(0).mediaBox.height, closeTo(297.64, 0.5));
    });

    test('l\'ordine delle foto è l\'ordine delle pagine', () {
      final result = photosToPdf(
          [png(20, 40), png(40, 20), png(20, 40)], PhotoPdfPage.a4);
      final doc = PdfDocument.open(result.bytes);
      expect(doc.pageCount, 3);
      expect(doc.page(0).mediaBox.width, lessThan(doc.page(0).mediaBox.height));
      expect(doc.page(1).mediaBox.width, greaterThan(doc.page(1).mediaBox.height));
      expect(doc.page(2).mediaBox.width, lessThan(doc.page(2).mediaBox.height));
    });

    test('una foto non leggibile o un PDF si salta e si conta', () {
      final result = photosToPdf([
        png(20, 40),
        Uint8List.fromList([1, 2, 3]),
        buildClassicPdf(),
      ], PhotoPdfPage.a4);
      expect(result.pages, 1);
      expect(result.skipped, 2);
      expect(PdfDocument.open(result.bytes).pageCount, 1);
    });

    test('nessuna foto leggibile: errore', () {
      expect(
        () => photosToPdf([Uint8List.fromList([1, 2, 3])], PhotoPdfPage.a4),
        throwsFormatException,
      );
      expect(() => photosToPdf(const [], PhotoPdfPage.a4), throwsFormatException);
    });
  });
}
