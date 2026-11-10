// Conversioni del punto 1 (pdf_conversions.dart): PDF in testo semplice e più
// foto in un PDF, una pagina per foto, e del punto 2: PDF in Word (.docx),
// e del punto 3: PDF in Excel (.xlsx). Solo logica, senza interfaccia.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_cos/pdf_cos.dart' show PdfMatrix;
import 'package:pdf_graphics/pdf_graphics.dart'
    show PdfExtractedRun, PdfReflowBlock;
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

    test('docxParagraphXml: grassetto, corsivo e colore, nell\'ordine di Word',
        () {
      final xml = docxParagraphXml(const DocxParagraph('Titolo',
          fontSize: 14, bold: true, italic: true, color: 0xC00000));
      expect(
          xml,
          contains('<w:rPr><w:b/><w:i/><w:color w:val="C00000"/>'
              '<w:sz w:val="28"/></w:rPr>'));
      // Un colore con zeri davanti resta di sei cifre.
      expect(docxParagraphXml(const DocxParagraph('a', color: 0x0000FF)),
          contains('<w:color w:val="0000FF"/>'));
      expect(docxParagraphXml(const DocxParagraph('a', color: 0x001000)),
          contains('<w:color w:val="001000"/>'));
    });

    test('docxParagraphXml: un paragrafo normale e nero non scrive stili', () {
      final xml = docxParagraphXml(const DocxParagraph('a'));
      expect(xml, isNot(contains('<w:b/>')));
      expect(xml, isNot(contains('<w:i/>')));
      expect(xml, isNot(contains('<w:color')));
      expect(xml, contains('<w:rPr><w:sz w:val="22"/></w:rPr>'));
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

    test('docxTableXml: griglia, bordi, celle vuote e paragrafo dopo', () {
      final xml = docxTableXml(const DocxTable([
        ['Nome', 'Qta', 'Prezzo'],
        ['Mela', '3'],
      ]));
      expect(xml, startsWith('<w:tbl>'));
      expect(xml, endsWith('</w:tbl><w:p/>'));
      expect('<w:gridCol '.allMatches(xml).length, 3);
      expect('<w:tr>'.allMatches(xml).length, 2);
      // La riga corta è completata: 3 celle per riga.
      expect('<w:tc>'.allMatches(xml).length, 6);
      expect(xml, contains('<w:insideV '));
      expect(xml, contains('>Prezzo</w:t>'));
      expect(xml, isNot(contains('<w:pageBreakBefore/>')));
    });

    test('docxTableXml: pagina nuova in un paragrafo prima della tabella', () {
      final xml = docxTableXml(const DocxTable([
        ['a', 'b'],
      ], pageBreakBefore: true));
      expect(xml,
          startsWith('<w:p><w:pPr><w:pageBreakBefore/></w:pPr></w:p><w:tbl>'));
      expect(docxTableXml(const DocxTable([])), '');
    });

    test('buildDocx porta le tabelle tra i paragrafi', () {
      final document = partOf(
          buildDocx(const [
            DocxParagraph('Prima'),
            DocxTable([
              ['x', 'y'],
            ]),
            DocxParagraph('Dopo'),
          ]),
          'word/document.xml');
      expect(document, contains('<w:tbl>'));
      expect(document.indexOf('Prima') < document.indexOf('<w:tbl>'), isTrue);
      expect(document.indexOf('<w:tbl>') < document.indexOf('Dopo'), isTrue);
    });

    test('docxPageElements: la tabella va al suo posto e il suo testo non si ripete',
        () {
      PdfReflowBlock block(String text, PdfRect bounds) => PdfReflowBlock(
          text: text, bounds: bounds, lines: const [], fontSize: 10);
      final tables = [
        PageTable(const PdfRect(49.5, 669.5, 300.5, 710.5), const [
          ['Nome', 'Qta'],
          ['Mela', '3'],
        ]),
      ];
      final elements = docxPageElements([
        block('Listino', const PdfRect(50, 730, 200, 742)),
        block('Nome Qta', const PdfRect(50, 700, 300, 710)),
        block('Fine', const PdfRect(50, 640, 100, 650)),
      ], tables, pageBreak: true);
      expect(elements, hasLength(3));
      expect((elements[0] as DocxParagraph).text, 'Listino');
      expect((elements[0] as DocxParagraph).pageBreakBefore, isTrue);
      expect(elements[1], isA<DocxTable>());
      expect((elements[1] as DocxTable).pageBreakBefore, isFalse);
      expect((elements[2] as DocxParagraph).text, 'Fine');
    });

    test('docxPageElements: senza blocchi sotto, la tabella va in fondo', () {
      final elements = docxPageElements(const [], [
        PageTable(const PdfRect(0, 0, 10, 10), const [
          ['a', 'b'],
        ]),
      ]);
      expect(elements.single, isA<DocxTable>());
    });

    test('docxImageXml: misura in EMU, ridotta alla larghezza del testo', () {
      // 100 x 50 punti = 1270000 x 635000 EMU, senza riduzione.
      final small = docxImageXml(
          DocxImage(Uint8List(0), 'jpeg', 100, 50),
          number: 1);
      expect(small, contains('<wp:extent cx="1270000" cy="635000"/>'));
      expect(small, contains('r:embed="rId1"'));
      expect(small, contains('<w:drawing>'));
      expect(small, contains('name="image1.jpeg"'));
      // Più largo del testo (9638 ventesimi di punto): si riduce, stesse
      // proporzioni.
      final wide = docxImageXml(
          DocxImage(Uint8List(0), 'png', 1000, 500),
          number: 2);
      expect(wide, contains('<wp:extent cx="6120130" cy="3060065"/>'));
      expect(wide, contains('r:embed="rId2"'));
    });

    test('buildDocx: le immagini finiscono in word/media con i collegamenti',
        () {
      final jpeg = Uint8List.fromList([1, 2, 3]);
      final pngBytes = png(2, 2);
      final docx = buildDocx([
        const DocxParagraph('Testo'),
        DocxImage(jpeg, 'jpeg', 100, 50),
        DocxImage(pngBytes, 'png', 30, 30),
      ]);
      final archive = ZipDecoder().decodeBytes(docx);
      expect(archive.findFile('word/media/image1.jpeg')!.content,
          orderedEquals(jpeg));
      expect(archive.findFile('word/media/image2.png')!.content,
          orderedEquals(pngBytes));
      final rels = partOf(docx, 'word/_rels/document.xml.rels');
      expect(rels, contains('Id="rId1"'));
      expect(rels, contains('Target="media/image1.jpeg"'));
      expect(rels, contains('Id="rId2"'));
      expect(rels, contains('Target="media/image2.png"'));
      final types = partOf(docx, '[Content_Types].xml');
      expect(types, contains('Extension="jpeg" ContentType="image/jpeg"'));
      expect(types, contains('Extension="png" ContentType="image/png"'));
      final document = partOf(docx, 'word/document.xml');
      expect(document, contains('r:embed="rId1"'));
      expect(document, contains('r:embed="rId2"'));
      expect(document, contains('xmlns:r='));
      expect(document, contains('xmlns:wp='));
    });

    test('buildDocx senza immagini non scrive word/media né i collegamenti',
        () {
      final docx = buildDocx(const [DocxParagraph('Solo testo')]);
      final names = ZipDecoder().decodeBytes(docx).files.map((f) => f.name);
      expect(names, isNot(contains('word/_rels/document.xml.rels')));
      expect(names.where((n) => n.startsWith('word/media')), isEmpty);
      expect(partOf(docx, '[Content_Types].xml'),
          isNot(contains('image/')));
    });

    test('jpegInfo: dimensioni e canali di un JPEG, null per il resto', () {
      final jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 5)));
      final info = jpegInfo(jpeg);
      expect(info, isNotNull);
      expect(info!.width, 8);
      expect(info.height, 5);
      expect(info.components, 3);
      expect(jpegInfo(png(4, 4)), isNull);
      expect(jpegInfo(Uint8List.fromList([0xFF, 0xD8])), isNull);
      expect(jpegInfo(Uint8List(0)), isNull);
    });

    test('docxPageElements: un\'immagine va tra i blocchi, al suo posto', () {
      PdfReflowBlock block(String text, PdfRect bounds) => PdfReflowBlock(
          text: text, bounds: bounds, lines: const [], fontSize: 10);
      final image = DocxImage(Uint8List(0), 'jpeg', 100, 100);
      final elements = docxPageElements([
        block('Sopra', const PdfRect(50, 740, 200, 750)),
        block('Sotto', const PdfRect(50, 500, 200, 510)),
      ], const [], images: [
        (bounds: const PdfRect(50, 600, 150, 700), image: image),
      ]);
      expect(elements, hasLength(3));
      expect((elements[0] as DocxParagraph).text, 'Sopra');
      expect(elements[1], same(image));
      expect((elements[2] as DocxParagraph).text, 'Sotto');
    });

    test('docxPageElements: un\'immagine in cima a una pagina nuova', () {
      final image = DocxImage(Uint8List(0), 'jpeg', 100, 100);
      final elements = docxPageElements(const [], const [], images: [
        (bounds: const PdfRect(0, 0, 10, 10), image: image),
      ], pageBreak: true);
      expect(elements, hasLength(2));
      expect((elements[0] as DocxParagraph).pageBreakBefore, isTrue);
      expect(elements[1], same(image));
    });

    test('una scansione (solo immagine) resta senza immagini nel Word',
        () async {
      final scan = PdfImageDocument.fromImageBytes([png(40, 30)]);
      final result = await pdfToDocx(PdfDocument.open(scan));
      expect(result.paragraphs, 0);
      expect(result.failedPages, isEmpty);
      final names = ZipDecoder().decodeBytes(result.bytes).files.map((f) => f.name);
      expect(names.where((n) => n.startsWith('word/media')), isEmpty);
      expect(partOf(result.bytes, 'word/document.xml'),
          isNot(contains('<w:drawing>')));
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

    test('findPageTables: una tabella con titolo e riga di testo attorno', () {
      final runs = [
        run('Listino', 50, 120, 730),
        run('Nome', 50, 90, 700),
        run('Qta', 150, 180, 700),
        run('Prezzo', 250, 300, 700),
        run('Mela', 50, 90, 685),
        run('3', 170, 180, 685),
        run('1,50', 270, 300, 685),
        run('Pera', 50, 90, 670),
        run('5', 170, 180, 670),
        run('2,00', 270, 300, 670),
        run('Fine del listino', 50, 150, 640),
      ];
      final tables = findPageTables(runs);
      expect(tables, hasLength(1));
      expect(tables.single.grid, [
        ['Nome', 'Qta', 'Prezzo'],
        ['Mela', '3', '1,50'],
        ['Pera', '5', '2,00'],
      ]);
      final zone = tables.single.zone;
      expect(zone.contains(70, 705), isTrue);
      expect(zone.contains(70, 735), isFalse);
      expect(zone.contains(70, 645), isFalse);
    });

    test('findPageTables: una riga sola o testo lungo non sono tabelle', () {
      expect(
          findPageTables([
            run('Nome', 50, 90, 700),
            run('Qta', 150, 180, 700),
          ]),
          isEmpty);
      final long = 'parola ' * 12;
      expect(
          findPageTables([
            run(long, 50, 250, 700),
            run(long, 300, 500, 700),
            run(long, 50, 250, 685),
            run(long, 300, 500, 685),
          ]),
          isEmpty);
    });

    test('pageCellRows: le celle conoscono il bordo alto e basso', () {
      final rows = pageCellRows([
        run('A', 50, 60, 700),
        run('B', 150, 160, 700),
      ]);
      expect(rows.single.first.top, 710);
      expect(rows.single.first.bottom, 700);
    });

    test('pageSheetRows: una pagina di testo va in una colonna sola', () {
      // Righe con rientri diversi: con le colonne finirebbero sparpagliate.
      final rows = pageSheetRows([
        run('Titolo della pagina', 50, 150, 700),
        run('prima riga di testo', 50, 150, 685),
        run('riga rientrata', 80, 160, 670),
        run('ultima riga', 50, 110, 655),
      ]);
      expect(rows, [
        ['Titolo della pagina'],
        ['prima riga di testo'],
        ['riga rientrata'],
        ['ultima riga'],
      ]);
    });

    test('pageSheetRows: una pagina quasi tutta tabella resta a colonne', () {
      final runs = [
        run('Nome', 50, 90, 700),
        run('Qta', 150, 180, 700),
        run('Mela', 50, 90, 685),
        run('3', 170, 180, 685),
        run('Pera', 50, 90, 670),
        run('5', 170, 180, 670),
      ];
      expect(pageSheetRows(runs), pageGrid(runs));
      expect(pageSheetRows(runs), [
        ['Nome', 'Qta'],
        ['Mela', '3'],
        ['Pera', '5'],
      ]);
    });

    test('pageSheetRows: testo con una tabella in mezzo, al suo posto', () {
      final rows = pageSheetRows([
        run('Relazione', 50, 120, 760),
        run('Un primo paragrafo di testo', 50, 200, 745),
        run('Un secondo paragrafo di testo', 50, 200, 730),
        run('Ecco i dati:', 50, 110, 715),
        run('Nome', 50, 90, 700),
        run('Qta', 150, 180, 700),
        run('Mela', 50, 90, 685),
        run('3', 170, 180, 685),
        run('Pera', 50, 90, 670),
        run('5', 170, 180, 670),
        run('Fine della relazione', 50, 170, 640),
        run('Firma', 50, 90, 625),
      ]);
      expect(rows, [
        ['Relazione'],
        ['Un primo paragrafo di testo'],
        ['Un secondo paragrafo di testo'],
        ['Ecco i dati:'],
        ['Nome', 'Qta'],
        ['Mela', '3'],
        ['Pera', '5'],
        ['Fine della relazione'],
        ['Firma'],
      ]);
    });

    test('pageSheetRows: senza testo è vuota', () {
      expect(pageSheetRows(const []), isEmpty);
    });

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

    test('con una zona contano solo i pezzi di testo dentro la zona', () {
      final runs = [
        run('Fuori', 50, 90, 760),
        run('Voce', 50, 80, 700),
        run('Importo', 200, 250, 700),
        run('Pane', 50, 80, 685),
        run('1,50', 225, 250, 685),
        run('Piè di pagina', 50, 150, 40),
      ];
      // La tabella sta tra y 680 e 715; il titolo e il piè di pagina restano fuori.
      final grid = pageGrid(runs, zone: const PdfRect(40, 680, 300, 715));
      expect(grid, [
        ['Voce', 'Importo'],
        ['Pane', '1,50'],
      ]);
      // Senza zona entrano tutti i pezzi.
      expect(pageGrid(runs).length, 4);
      // Una zona senza testo dà una griglia vuota.
      expect(pageGrid(runs, zone: const PdfRect(400, 300, 500, 400)), isEmpty);
    });

    test('xlsxZoneFileName: titolo e pagina', () {
      expect(xlsxZoneFileName('Report.pdf', 1), 'Report (pagina 2).xlsx');
      expect(xlsxZoneFileName('   ', 0), 'documento (pagina 1).xlsx');
    });

    test('pdfZoneToXlsx: la pagina intera porta il testo, una zona vuota no',
        () {
      final doc = PdfDocument.open(buildClassicPdf());
      final whole = pdfZoneToXlsx(doc, 0, doc.page(0).cropBox);
      expect(whole.sheets, 1);
      expect(whole.cells, greaterThan(0));
      final xml = partOf(whole.bytes, 'xl/worksheets/sheet1.xml');
      expect(xml, contains('Hello, world!'));
      expect(partOf(whole.bytes, 'xl/workbook.xml'), contains('name="Zona"'));

      final empty = pdfZoneToXlsx(doc, 0, const PdfRect(-500, -500, -400, -400));
      expect(empty.cells, 0);
      expect(empty.sheets, 0);
      expect(empty.bytes, isEmpty);
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
