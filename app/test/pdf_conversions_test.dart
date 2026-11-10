// Conversioni del punto 1 (pdf_conversions.dart): PDF in testo semplice e più
// foto in un PDF, una pagina per foto, e del punto 2: PDF in Word (.docx).
// Solo logica, senza interfaccia.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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

  group('PDF in Word (.docx)', () {
    String partOf(Uint8List docx, String name) {
      final archive = ZipDecoder().decodeBytes(docx);
      final file = archive.findFile(name);
      expect(file, isNotNull, reason: 'manca $name');
      return utf8.decode(file!.content as List<int>);
    }

    test('docxExportFileName toglie .pdf e mette .docx', () {
      expect(docxExportFileName('Report.pdf'), 'Report.docx');
      expect(docxExportFileName('foto'), 'foto.docx');
      expect(docxExportFileName('   '), 'documento.docx');
    });

    test('xmlSafeText: & < > in forma XML, controlli e surrogati spaiati via',
        () {
      expect(xmlSafeText('a & b < c > d'), 'a &amp; b &lt; c &gt; d');
      expect(xmlSafeText('a\u0000b\u0008c\u000Bd'), 'abcd');
      expect(xmlSafeText('x\tY\nZ'), 'x\tY\nZ');
      expect(xmlSafeText('a\uD800b'), 'ab');
      expect(xmlSafeText('a\uDC00b'), 'ab');
      expect(xmlSafeText('\u{1F600}'), '\u{1F600}');
    });

    test('docxParagraphXml: corpo in mezzi punti, elenco rientrato, a capo', () {
      final xml = docxParagraphXml(
          const DocxParagraph('Uno\nDue', fontSize: 12, isListItem: true));
      expect(xml, contains('<w:sz w:val="24"/>'));
      expect(xml, contains('<w:ind w:left="360"/>'));
      expect(xml, contains('<w:br/>'));
      expect(xml, contains('>Uno</w:t>'));
      expect(xml, contains('>Due</w:t>'));
      // Corpo fuori misura: tenuto tra 6 e 72 punti.
      expect(docxParagraphXml(const DocxParagraph('a', fontSize: 500)),
          contains('<w:sz w:val="144"/>'));
      expect(docxParagraphXml(const DocxParagraph('a', fontSize: 1)),
          contains('<w:sz w:val="12"/>'));
    });

    test('buildDocx: le tre parti, con il testo scappato bene', () {
      final docx = buildDocx(const [
        DocxParagraph('Tom & Jerry <3'),
        DocxParagraph('Pagina due', pageBreakBefore: true),
      ]);
      // Un .docx è uno zip che comincia con "PK".
      expect(docx[0], 0x50);
      expect(docx[1], 0x4B);
      final names = ZipDecoder().decodeBytes(docx).files.map((f) => f.name);
      expect(names,
          containsAll(['[Content_Types].xml', '_rels/.rels', 'word/document.xml']));
      final document = partOf(docx, 'word/document.xml');
      expect(document, contains('Tom &amp; Jerry &lt;3'));
      expect(document, contains('<w:pageBreakBefore/>'));
      expect(partOf(docx, '_rels/.rels'), contains('word/document.xml'));
      expect(partOf(docx, '[Content_Types].xml'),
          contains('wordprocessingml.document.main+xml'));
    });

    test('buildDocx senza paragrafi è comunque un documento valido', () {
      final document = partOf(buildDocx(const []), 'word/document.xml');
      expect(document, contains('<w:body><w:p/>'));
    });

    test('pdfToDocx porta il testo di una pagina', () async {
      final pages = <int>[];
      final result = await pdfToDocx(
        PdfDocument.open(buildClassicPdf()),
        onPage: (page, count) => pages.add(page * 10 + count),
      );
      expect(result.paragraphs, greaterThan(0));
      expect(result.failedPages, isEmpty);
      expect(pages, [1]);
      final document = partOf(result.bytes, 'word/document.xml');
      expect(document, contains('Hello, world!'));
      expect(document, isNot(contains('<w:pageBreakBefore/>')));
    });

    test('pdfToDocx: ogni pagina dopo la prima comincia su una pagina nuova',
        () async {
      final two = PdfMerger.merge([buildClassicPdf(), buildClassicPdf()]);
      final result = await pdfToDocx(PdfDocument.open(two));
      final document = partOf(result.bytes, 'word/document.xml');
      expect('Hello, world!'.allMatches(document).length, 2);
      expect('<w:pageBreakBefore/>'.allMatches(document).length, 1);
    });

    test('un PDF senza testo (una scansione) non ha paragrafi', () async {
      final blank = PdfBlankDocument.create(pageCount: 2);
      final result = await pdfToDocx(PdfDocument.open(blank));
      expect(result.paragraphs, 0);
      expect(result.failedPages, isEmpty);
    });
  });
}
