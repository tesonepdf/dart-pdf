// Conversioni del punto 1 (pdf_conversions.dart): PDF in testo semplice e più
// foto in un PDF, una pagina per foto, e del punto 2: PDF in Word (.docx),
// e del punto 3: PDF in Excel (.xlsx). Solo logica, senza interfaccia.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_cos/pdf_cos.dart' show PdfMatrix;
import 'package:pdf_graphics/pdf_graphics.dart' show PdfExtractedRun;
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

  group('PDF in Excel (.xlsx)', () {
    // Un pezzo di testo alto 10 punti, con il bordo in basso a [bottom].
    PdfExtractedRun run(String text, double left, double right, double bottom) =>
        PdfExtractedRun(
          text: text,
          startIndex: 0,
          transform: PdfMatrix.identity,
          width: right - left,
          bounds: PdfRect(left, bottom, right, bottom + 10),
        );

    String partOf(Uint8List xlsx, String name) {
      final file = ZipDecoder().decodeBytes(xlsx).findFile(name);
      expect(file, isNotNull, reason: 'manca $name');
      return utf8.decode(file!.content as List<int>);
    }

    test('parseSpreadsheetNumber: formato italiano e inglese', () {
      expect(parseSpreadsheetNumber('1.234,56'), 1234.56);
      expect(parseSpreadsheetNumber('1,234.56'), 1234.56);
      expect(parseSpreadsheetNumber('12,5'), 12.5);
      expect(parseSpreadsheetNumber('12.5'), 12.5);
      expect(parseSpreadsheetNumber('1.234'), 1234);
      expect(parseSpreadsheetNumber('0.123'), 0.123);
      expect(parseSpreadsheetNumber('1,234,567'), 1234567);
      expect(parseSpreadsheetNumber('1.234.567,8'), 1234567.8);
      expect(parseSpreadsheetNumber('2026'), 2026);
    });

    test('parseSpreadsheetNumber: segni, parentesi e valute', () {
      expect(parseSpreadsheetNumber('-3'), -3);
      expect(parseSpreadsheetNumber('\u22123'), -3);
      expect(parseSpreadsheetNumber('(45)'), -45);
      expect(parseSpreadsheetNumber('€ 12,50'), 12.5);
      expect(parseSpreadsheetNumber('12,50 €'), 12.5);
      expect(parseSpreadsheetNumber(r'$9.99'), 9.99);
    });

    test('parseSpreadsheetNumber: resta testo ciò che non è un numero', () {
      for (final text in [
        '',
        'abc',
        '007',
        '12%',
        '10.11.2026',
        '1.5.2',
        '1234567890123456',
        '12 345',
      ]) {
        expect(parseSpreadsheetNumber(text), isNull, reason: text);
      }
    });

    test('xlsxColumnName: A, Z, AA, ZZ, AAA', () {
      expect(xlsxColumnName(0), 'A');
      expect(xlsxColumnName(25), 'Z');
      expect(xlsxColumnName(26), 'AA');
      expect(xlsxColumnName(701), 'ZZ');
      expect(xlsxColumnName(702), 'AAA');
    });

    test('xlsxExportFileName toglie .pdf e mette .xlsx', () {
      expect(xlsxExportFileName('Report.pdf'), 'Report.xlsx');
      expect(xlsxExportFileName('   '), 'documento.xlsx');
    });

    test('una tabella: righe dall\'altezza, colonne dagli spazi larghi', () {
      final grid = pageGrid([
        run('Spesa', 50, 90, 730),
        run('Voce', 50, 80, 700),
        run('Importo', 200, 250, 700),
        run('Pane', 50, 80, 685),
        run('1,50', 225, 250, 685), // numero allineato a destra
        run('Latte', 50, 85, 670),
        run('12,25', 220, 250, 670),
      ]);
      expect(grid, [
        ['Spesa', ''],
        ['Voce', 'Importo'],
        ['Pane', '1,50'],
        ['Latte', '12,25'],
      ]);
    });

    test('parole vicine restano nella stessa cella', () {
      final grid = pageGrid([
        run('Costo', 50, 80, 700),
        run('totale', 83, 120, 700),
        run('9', 300, 310, 700),
      ]);
      expect(grid, [
        ['Costo totale', '9'],
      ]);
    });

    test('due o più spazi dentro un pezzo di testo separano le celle', () {
      final grid = pageGrid([
        run('Nome   Qtà', 0, 100, 700),
        run('Mela   3', 0, 70, 685),
      ]);
      expect(grid.length, 2);
      expect(grid[0], ['Nome', 'Qtà']);
      expect(grid[1], ['Mela', '3']);
    });

    test('pezzi con la base un poco diversa stanno nella stessa riga', () {
      final grid = pageGrid([
        run('A', 50, 60, 700),
        run('B', 200, 210, 702),
      ]);
      expect(grid, [
        ['A', 'B'],
      ]);
    });

    test('senza testo la griglia è vuota; una sola colonna se non ci sono tabelle',
        () {
      expect(pageGrid(const []), isEmpty);
      final grid = pageGrid([
        run('Primo paragrafo', 50, 150, 700),
        run('Secondo paragrafo', 50, 160, 685),
      ]);
      expect(grid, [
        ['Primo paragrafo'],
        ['Secondo paragrafo'],
      ]);
    });

    test('xlsxSheetXml: numeri veri, testo scappato, celle vuote saltate', () {
      final xml = xlsxSheetXml(const XlsxSheet('Pagina 1', [
        ['Tom & Jerry', '1.234,56', ''],
        ['', '12', 'x'],
      ]));
      expect(xml, contains('<c r="A1" t="inlineStr">'));
      expect(xml, contains('Tom &amp; Jerry'));
      expect(xml, contains('<c r="B1"><v>1234.56</v></c>'));
      expect(xml, contains('<c r="B2"><v>12</v></c>'));
      expect(xml, contains('<c r="C2" t="inlineStr">'));
      expect(xml, isNot(contains('r="C1"')));
      expect(xml, isNot(contains('r="A2"')));
      expect(xml, contains('<cols>'));
    });

    test('buildXlsx: le parti del file e una scheda per ogni foglio', () {
      final xlsx = buildXlsx(const [
        XlsxSheet('Pagina 1', [
          ['a', '1'],
        ]),
        XlsxSheet('Pagina 3', [
          ['b'],
        ]),
      ]);
      expect(xlsx[0], 0x50);
      expect(xlsx[1], 0x4B);
      final names = ZipDecoder().decodeBytes(xlsx).files.map((f) => f.name);
      expect(
          names,
          containsAll([
            '[Content_Types].xml',
            '_rels/.rels',
            'xl/workbook.xml',
            'xl/_rels/workbook.xml.rels',
            'xl/worksheets/sheet1.xml',
            'xl/worksheets/sheet2.xml',
          ]));
      final workbook = partOf(xlsx, 'xl/workbook.xml');
      expect(workbook, contains('name="Pagina 1"'));
      expect(workbook, contains('name="Pagina 3"'));
      expect(partOf(xlsx, '[Content_Types].xml'),
          contains('/xl/worksheets/sheet2.xml'));
      expect(partOf(xlsx, 'xl/_rels/workbook.xml.rels'),
          contains('worksheets/sheet2.xml'));
    });

    test('buildXlsx senza schede non è valido', () {
      expect(() => buildXlsx(const []), throwsArgumentError);
    });

    test('pdfToXlsx porta il testo di una pagina', () async {
      final pages = <int>[];
      final result = await pdfToXlsx(
        PdfDocument.open(buildClassicPdf()),
        onPage: (page, count) => pages.add(page * 10 + count),
      );
      expect(result.sheets, 1);
      expect(result.cells, greaterThan(0));
      expect(result.failedPages, isEmpty);
      expect(pages, [1]);
      expect(partOf(result.bytes, 'xl/worksheets/sheet1.xml'),
          contains('Hello, world!'));
    });

    test('un PDF senza testo (una scansione) non ha celle né file', () async {
      final blank = PdfBlankDocument.create(pageCount: 2);
      final result = await pdfToXlsx(PdfDocument.open(blank));
      expect(result.cells, 0);
      expect(result.sheets, 0);
      expect(result.bytes, isEmpty);
    });
  });
}
