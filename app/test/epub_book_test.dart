// Libri .epub (epub_book.dart): testo dei capitoli, lettura dello zip,
// impaginazione e PDF.
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart' show PdfTextExtractor;

import 'package:dart_pdf_editor_app/epub_book.dart';

Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, text) => archive.addFile(
      ArchiveFile.bytes(name, Uint8List.fromList(utf8.encode(text)))));
  return ZipEncoder().encodeBytes(archive);
}

const _container = '<?xml version="1.0"?><container><rootfiles>'
    '<rootfile full-path="OEBPS/content.opf" '
    'media-type="application/oebps-package+xml"/></rootfiles></container>';

String _opf(List<(String id, String href)> items, List<String> spine) =>
    '<package><metadata><dc:title>Il mio libro</dc:title></metadata><manifest>'
    '${[for (final (id, href) in items) '<item id="$id" href="$href" media-type="application/xhtml+xml"/>'].join()}'
    '<item id="img" href="img/c.png" media-type="image/png"/>'
    '</manifest><spine>'
    '${[for (final id in spine) '<itemref idref="$id"/>'].join()}'
    '</spine></package>';

String _page(String body) => '<html><body>$body</body></html>';

Uint8List _book() => _zip({
      'mimetype': 'application/epub+zip',
      'META-INF/container.xml': _container,
      'OEBPS/content.opf': _opf(
          [('c1', 'text/cap%201.xhtml'), ('c2', 'text/cap2.xhtml')],
          ['c1', 'c2']),
      'OEBPS/text/cap 1.xhtml':
          _page('<h1>Capitolo uno</h1><p>Testo del primo capitolo.</p>'),
      'OEBPS/text/cap2.xhtml':
          _page('<h1>Capitolo due</h1><p>Testo del secondo.</p>'),
    });

double _fake(String text, double size, bool bold) => text.length * size * 0.5;

void main() {
  group('testo', () {
    test('le entità si sciolgono, quelle sconosciute restano', () {
      expect(decodeEntities('a &amp; b &lt;c&gt; &#232; &#xE8; &foo;'),
          'a & b <c> è è &foo;');
    });

    test('virgolette e trattini diventano semplici, le lettere accentate no',
        () {
      expect(pdfSafeText('\u201Cciao\u201D \u2013 perché\u2026 l\u2019'),
          '"ciao" - perché... l\'');
      expect(pdfSafeText('5\u20AC \u65E5'), '5EUR ?');
    });

    test('un capitolo diventa titoli e paragrafi', () {
      final blocks = htmlToBlocks('<html><head><title>T</title>'
          '<style>p{}</style></head><body><h1>Capitolo &#232; uno</h1>'
          '<p>Primo <em>paragrafo</em>&nbsp;con &amp; e '
          '&#x2019;virgolette&#x2019;.<br/>Seconda riga</p>'
          '<ul><li>uno</li><li>due</li></ul></body></html>');
      expect(blocks, [
        const EpubBlock('Capitolo è uno', level: 1, chapterStart: true),
        const EpubBlock("Primo paragrafo con & e 'virgolette'."),
        const EpubBlock('Seconda riga'),
        const EpubBlock('- uno'),
        const EpubBlock('- due'),
      ]);
    });

    test('una pagina senza testo dà solo il blocco immagine', () {
      expect(htmlToBlocks('<html><body><img src="a.png"/></body></html>'), [
        const EpubBlock('', imageSrc: 'a.png', chapterStart: true),
      ]);
      expect(htmlToBlocks('<html><body><p>  </p></body></html>'), isEmpty);
    });

    test('corsivo solo se tutto il paragrafo è in corsivo', () {
      final blocks = htmlToBlocks(
          '<p><i>tutto corsivo</i></p><p>un po\' <em>sì</em> e un po\' no</p>');
      expect(blocks.map((b) => b.italic), [true, false]);
    });

    test('le note vanno in fondo al capitolo con livello 4', () {
      final blocks = htmlToBlocks('<h1>T</h1>'
          '<aside epub:type="footnote"><p>nota uno</p></aside>'
          '<p>corpo</p>');
      expect(blocks.map((b) => (b.text, b.level)),
          [('T', 1), ('corpo', 0), ('nota uno', 4)]);
    });

    test('cirillico e greco si traslitterano, il cinese no', () {
      expect(pdfSafeText('Привет Щука'), 'Privet Shchuka');
      expect(pdfSafeText('Ελλάδα'), 'Ellada');
      expect(pdfSafeText('日'), '?');
    });

    test('i percorsi dentro lo zip si risolvono', () {
      expect(resolveEpubPath('OEBPS/', '../Text/a%20b.xhtml#x'),
          'Text/a b.xhtml');
      expect(resolveEpubPath('', 'content.opf'), 'content.opf');
    });
  });

  group('lo zip', () {
    test('legge titolo e capitoli nell\'ordine del libro', () {
      final content = readEpub(_book());
      expect(content.title, 'Il mio libro');
      expect(content.chapters, 2);
      expect(content.blocks, [
        const EpubBlock('Capitolo uno', level: 1, chapterStart: true),
        const EpubBlock('Testo del primo capitolo.'),
        const EpubBlock('Capitolo due', level: 1, chapterStart: true),
        const EpubBlock('Testo del secondo.'),
      ]);
    });

    test('un file che non è un libro, o senza testo, dà errore', () {
      expect(() => readEpub(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<FormatException>()));
      expect(() => readEpub(_zip({'a.txt': 'x'})),
          throwsA(isA<FormatException>()));
      final empty = _zip({
        'META-INF/container.xml': _container,
        'OEBPS/content.opf': _opf([('c1', 'c1.xhtml')], ['c1']),
        'OEBPS/c1.xhtml': _page('<img src="a.png"/>'),
      });
      expect(() => readEpub(empty), throwsA(isA<FormatException>()));
    });
  });

  group('impaginazione', () {
    test('le righe vanno a capo', () {
      expect(wrapEpubText('uno due tre', 40, 10, false, _fake),
          ['uno due', 'tre']);
      expect(wrapEpubText('abcdefghijkl', 40, 10, false, _fake),
          ['abcdefgh', 'ijkl']);
    });

    test('un capitolo nuovo comincia su una pagina nuova', () {
      final pages = layoutEpub([
        const EpubBlock('Uno', level: 1, chapterStart: true),
        const EpubBlock('testo'),
        const EpubBlock('Due', level: 1, chapterStart: true),
        const EpubBlock('altro'),
      ], _fake);
      expect(pages.length, 2);
      expect([for (final l in pages[0]) l.text], ['Uno', 'testo']);
      expect([for (final l in pages[1]) l.text], ['Due', 'altro']);
    });

    test('un testo lungo occupa più pagine e resta dentro i margini', () {
      final pages = layoutEpub([
        const EpubBlock('Titolo', level: 1, chapterStart: true),
        for (var i = 0; i < 200; i++) EpubBlock('paragrafo $i'),
      ], _fake);
      expect(pages.length, greaterThan(1));
      for (final page in pages) {
        expect(page, isNotEmpty);
        for (final line in page) {
          expect(line.y, greaterThanOrEqualTo(56));
          expect(line.y, lessThanOrEqualTo(epubPageHeight - 56));
        }
      }
    });
  });

  group('nel PDF', () {
    test('ogni capitolo è una pagina e il testo si legge', () {
      final result = epubToPdf(_book());
      expect(result.pages, 2);
      expect(result.chapters, 2);
      expect(result.title, 'Il mio libro');
      final doc = PdfDocument.open(result.bytes);
      expect(doc.pageCount, 2);
      expect(PdfTextExtractor.extract(doc, 0).text, contains('Capitolo uno'));
      expect(PdfTextExtractor.extract(doc, 1).text, contains('Capitolo due'));
    });

    test('il titolo della scheda', () {
      expect(epubTitle('Il nome della rosa.epub'), 'Il nome della rosa.pdf');
      expect(epubTitle('.EPUB'), 'libro.pdf');
    });
  });
}
