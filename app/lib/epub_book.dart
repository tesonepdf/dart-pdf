import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:pdf_document/pdf_document.dart';

// Libri .epub: un file zip con i capitoli in XHTML. Si legge l'elenco dei
// capitoli (nell'ordine del libro), si estrae il testo, lo si impagina su fogli
// A4 e lo si scrive con il motore (Helvetica) in un PDF nuovo, che si apre in
// una scheda. Solo testo: titoli e paragrafi, senza la grafica del libro.
// Il collegamento al menu è in `editor_screen.dart` (`_openEpub`).

/// I file che si scelgono per aprire un libro.
XTypeGroup epubTypeGroup() => const XTypeGroup(
      label: 'Libri (.epub)',
      extensions: ['epub'],
      mimeTypes: ['application/epub+zip'],
      uniformTypeIdentifiers: ['org.idpf.epub-container', 'public.data'],
    );

/// Chiede un file .epub, o null se si annulla.
Future<XFile?> pickEpubFile() =>
    openFile(acceptedTypeGroups: [epubTypeGroup()]);

// --- Dal capitolo (XHTML) ai blocchi di testo --------------------------------

/// Un pezzo di testo del libro: un titolo (livello 1, 2 o 3) o un paragrafo
/// (livello 0). `chapterStart` è vero per il primo blocco di ogni capitolo: lì
/// l'impaginazione ricomincia da una pagina nuova.
class EpubBlock {
  const EpubBlock(this.text, {this.level = 0, this.chapterStart = false});

  final String text;
  final int level;
  final bool chapterStart;

  @override
  bool operator ==(Object other) =>
      other is EpubBlock &&
      other.text == text &&
      other.level == level &&
      other.chapterStart == chapterStart;

  @override
  int get hashCode => Object.hash(text, level, chapterStart);

  @override
  String toString() => 'EpubBlock($text, level: $level, start: $chapterStart)';
}

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'rsquo': '\u2019',
  'lsquo': '\u2018',
  'rdquo': '\u201D',
  'ldquo': '\u201C',
  'ndash': '\u2013',
  'mdash': '\u2014',
  'hellip': '\u2026',
  'laquo': '\u00AB',
  'raquo': '\u00BB',
  'egrave': '\u00E8',
  'eacute': '\u00E9',
  'agrave': '\u00E0',
  'ograve': '\u00F2',
  'igrave': '\u00EC',
  'ugrave': '\u00F9',
};

/// Sostituisce le entità XML/HTML (`&amp;`, `&#232;`, `&#xE8;`) con i caratteri.
/// Un'entità che non si conosce resta com'è.
String decodeEntities(String text) =>
    text.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'), (m) {
      final body = m.group(1)!;
      if (body.startsWith('#x')) {
        final code = int.tryParse(body.substring(2), radix: 16);
        return code == null || code > 0x10FFFF ? m.group(0)! : String.fromCharCode(code);
      }
      if (body.startsWith('#')) {
        final code = int.tryParse(body.substring(1));
        return code == null || code > 0x10FFFF ? m.group(0)! : String.fromCharCode(code);
      }
      return _namedEntities[body] ?? m.group(0)!;
    });

/// Riduce [text] ai caratteri che Helvetica (WinAnsi) sa scrivere: le
/// virgolette e i trattini "tipografici" diventano quelli semplici, l'a capo
/// e gli spazi strani diventano uno spazio, il resto fuori da Latin-1 diventa
/// `?`. Le lettere accentate (à, è, é, ì, ò, ù...) restano.
String pdfSafeText(String text) {
  final out = StringBuffer();
  for (final code in text.runes) {
    switch (code) {
      case 0x2018 || 0x2019 || 0x201A || 0x2032:
        out.write("'");
      case 0x201C || 0x201D || 0x201E || 0x2033:
        out.write('"');
      case 0x2013 || 0x2014 || 0x2212:
        out.write('-');
      case 0x2026:
        out.write('...');
      case 0x2022 || 0x00B7:
        out.write('-');
      case 0x20AC:
        out.write('EUR');
      case 0x00A0 || 0x2009 || 0x200A || 0x2002 || 0x2003 || 0x202F:
        out.write(' ');
      case 0x200B || 0x200C || 0x200D || 0xFEFF || 0x00AD:
        break;
      case < 0x20 || (>= 0x7F && <= 0x9F):
        out.write(' ');
      case > 0xFF:
        out.write('?');
      default:
        out.writeCharCode(code);
    }
  }
  return out.toString();
}

const _blockTags = {
  'p', 'div', 'section', 'article', 'blockquote', 'ul', 'ol', 'li', 'tr',
  'table', 'pre', 'br', 'hr', 'header', 'footer', 'figure', 'figcaption',
  'dd', 'dt', 'dl', 'aside', 'nav', 'caption', 'h1', 'h2', 'h3', 'h4', 'h5',
  'h6', 'title',
};

/// Il testo di un capitolo XHTML come blocchi (titoli e paragrafi). Gli
/// elenchi hanno un trattino davanti. Immagini, script, stili e intestazione
/// della pagina si saltano. Il primo blocco porta `chapterStart`.
List<EpubBlock> htmlToBlocks(String html) {
  var source = html;
  source = source.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ');
  source = source.replaceAll(
      RegExp(r'<(script|style|head)\b[^>]*>.*?</\1\s*>',
          dotAll: true, caseSensitive: false),
      ' ');
  final blocks = <EpubBlock>[];
  final buffer = StringBuffer();
  var level = 0;
  var pendingBullet = false;

  void flush() {
    final text = pdfSafeText(decodeEntities(buffer.toString()))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    buffer.clear();
    if (text.isEmpty) {
      level = 0;
      return;
    }
    blocks.add(EpubBlock(pendingBullet ? '- $text' : text, level: level));
    level = 0;
    pendingBullet = false;
  }

  var pos = 0;
  for (final m in RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>').allMatches(source)) {
    buffer.write(source.substring(pos, m.start));
    pos = m.end;
    final closing = m.group(1) == '/';
    final tag = m.group(2)!.toLowerCase();
    if (!_blockTags.contains(tag)) continue;
    flush();
    if (!closing) {
      if (tag.length == 2 && tag[0] == 'h' && '123456'.contains(tag[1])) {
        level = int.parse(tag[1]).clamp(1, 3);
      }
      if (tag == 'li') pendingBullet = true;
    }
  }
  buffer.write(source.substring(pos));
  flush();
  if (blocks.isEmpty) return blocks;
  final first = blocks.first;
  blocks[0] = EpubBlock(first.text, level: first.level, chapterStart: true);
  return blocks;
}

// --- Dal libro ai blocchi ---------------------------------------------------

/// Il contenuto di un libro: titolo (se c'è), numero di capitoli e blocchi.
typedef EpubContent = ({String? title, int chapters, List<EpubBlock> blocks});

String _attr(String tag, String name) {
  final m = RegExp('\\b$name\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')',
          caseSensitive: false)
      .firstMatch(tag);
  return m == null ? '' : (m.group(1) ?? m.group(2) ?? '');
}

String _dirOf(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? '' : path.substring(0, i + 1);
}

/// Unisce [base] (la cartella del file OPF) e [href] (può avere `../`, `%20`
/// e `#ancora`) in un percorso dentro lo zip.
String resolveEpubPath(String base, String href) {
  var h = href;
  final hash = h.indexOf('#');
  if (hash >= 0) h = h.substring(0, hash);
  try {
    h = Uri.decodeFull(h);
  } catch (_) {}
  final parts = <String>[];
  for (final p in '$base$h'.replaceAll('\\', '/').split('/')) {
    if (p.isEmpty || p == '.') continue;
    if (p == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else {
      parts.add(p);
    }
  }
  return parts.join('/');
}

String _text(ArchiveFile f) =>
    utf8.decode(f.content as List<int>, allowMalformed: true);

/// Legge il libro: l'OPF indicato da `META-INF/container.xml`, i capitoli
/// nell'ordine dello spine, il testo di ciascuno. Lancia [FormatException] se
/// non è un EPUB leggibile o non ha testo.
EpubContent readEpub(Uint8List epub) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(epub);
  } catch (_) {
    throw const FormatException('non è un file .epub leggibile');
  }
  final byName = <String, ArchiveFile>{
    for (final f in archive.files)
      if (f.isFile) f.name.replaceAll('\\', '/'): f,
  };
  final container = byName['META-INF/container.xml'];
  if (container == null) {
    throw const FormatException('manca META-INF/container.xml');
  }
  final rootfile = RegExp(r'<rootfile\b[^>]*>', caseSensitive: false)
      .firstMatch(_text(container));
  final opfPath = rootfile == null
      ? ''
      : resolveEpubPath('', _attr(rootfile.group(0)!, 'full-path'));
  final opfFile = byName[opfPath];
  if (opfFile == null) throw const FormatException('manca il file del libro (OPF)');
  final opf = _text(opfFile);
  final base = _dirOf(opfPath);

  final manifest = <String, ({String href, String type})>{};
  for (final m in RegExp(r'<item\b[^>]*>', caseSensitive: false).allMatches(opf)) {
    final tag = m.group(0)!;
    manifest[_attr(tag, 'id')] =
        (href: _attr(tag, 'href'), type: _attr(tag, 'media-type'));
  }
  final titleMatch = RegExp(r'<dc:title\b[^>]*>(.*?)</dc:title>',
          dotAll: true, caseSensitive: false)
      .firstMatch(opf);
  final title = titleMatch == null
      ? null
      : pdfSafeText(decodeEntities(titleMatch.group(1)!))
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  final blocks = <EpubBlock>[];
  var chapters = 0;
  for (final m in RegExp(r'<itemref\b[^>]*>', caseSensitive: false).allMatches(opf)) {
    final item = manifest[_attr(m.group(0)!, 'idref')];
    if (item == null) continue;
    final isText = item.type.contains('html') ||
        item.href.toLowerCase().endsWith('.xhtml') ||
        item.href.toLowerCase().endsWith('.html') ||
        item.href.toLowerCase().endsWith('.htm');
    if (!isText) continue;
    final file = byName[resolveEpubPath(base, item.href)];
    if (file == null) continue;
    final chapter = htmlToBlocks(_text(file));
    if (chapter.isEmpty) continue;
    chapters++;
    blocks.addAll(chapter);
  }
  if (blocks.isEmpty) {
    throw const FormatException('nel libro non c\'è testo da leggere');
  }
  return (
    title: title == null || title.isEmpty ? null : title,
    chapters: chapters,
    blocks: blocks,
  );
}

// --- Impaginazione ----------------------------------------------------------

/// Una riga già posizionata: [y] è la linea di base, dal basso della pagina.
class EpubLine {
  const EpubLine(this.text, this.x, this.y, this.size, this.bold);

  final String text;
  final double x;
  final double y;
  final double size;
  final bool bold;
}

/// Come misurare un testo: larghezza in punti di [text] al corpo [size].
typedef EpubMeasure = double Function(String text, double size, bool bold);

/// Spezza [text] in righe larghe al massimo [width]. Una parola più lunga
/// della riga si spezza dove capita.
List<String> wrapEpubText(
    String text, double width, double size, bool bold, EpubMeasure measure) {
  final lines = <String>[];
  var line = '';
  for (var word in text.split(' ')) {
    if (word.isEmpty) continue;
    while (measure(word, size, bold) > width && word.length > 1) {
      // Parola troppo lunga: se ne prende quanto sta.
      var n = word.length - 1;
      while (n > 1 && measure(word.substring(0, n), size, bold) > width) {
        n--;
      }
      if (line.isNotEmpty) {
        lines.add(line);
        line = '';
      }
      lines.add(word.substring(0, n));
      word = word.substring(n);
    }
    final candidate = line.isEmpty ? word : '$line $word';
    if (line.isNotEmpty && measure(candidate, size, bold) > width) {
      lines.add(line);
      line = word;
    } else {
      line = candidate;
    }
  }
  if (line.isNotEmpty) lines.add(line);
  return lines;
}

/// La pagina del libro in PDF (A4 di base, margini 56 pt).
const epubPageWidth = 595.28;
const epubPageHeight = 841.89;
const _margin = 56.0;

/// Impagina i [blocks] su pagine A4: le righe di ogni pagina, dall'alto.
/// Un capitolo nuovo comincia sempre su una pagina nuova. Ritorna almeno una
/// pagina (anche vuota) se ci sono blocchi.
List<List<EpubLine>> layoutEpub(List<EpubBlock> blocks, EpubMeasure measure) {
  const bodySize = 11.0;
  final width = epubPageWidth - 2 * _margin;
  final pages = <List<EpubLine>>[];
  var current = <EpubLine>[];
  var y = epubPageHeight - _margin;

  void newPage() {
    if (current.isNotEmpty) pages.add(current);
    current = <EpubLine>[];
    y = epubPageHeight - _margin;
  }

  for (final block in blocks) {
    if (block.chapterStart && current.isNotEmpty) newPage();
    final size = switch (block.level) {
      1 => 18.0,
      2 => 15.0,
      3 => 13.0,
      _ => bodySize,
    };
    final bold = block.level > 0;
    final leading = size * 1.35;
    final before = block.level > 0 ? size * 0.6 : 0.0;
    final lines = wrapEpubText(block.text, width, size, bold, measure);
    if (lines.isEmpty) continue;
    // Il titolo non resta solo in fondo alla pagina: con meno di tre righe di
    // spazio si passa alla pagina dopo.
    if (block.level > 0 &&
        current.isNotEmpty &&
        y - before - leading * 3 < _margin) {
      newPage();
    }
    if (current.isNotEmpty) y -= before;
    for (final line in lines) {
      if (y - leading < _margin && current.isNotEmpty) newPage();
      y -= leading;
      current.add(EpubLine(line, _margin, y, size, bold));
    }
    y -= block.level > 0 ? size * 0.3 : 5;
  }
  if (current.isNotEmpty || pages.isEmpty) pages.add(current);
  return pages;
}

// --- Dal libro al PDF -------------------------------------------------------

/// Il risultato di [epubToPdf].
typedef EpubPdfResult = ({
  Uint8List bytes,
  int pages,
  int chapters,
  String? title,
});

/// Legge [epub] e lo trasforma in un PDF di solo testo. Lancia
/// [FormatException] se non è un EPUB leggibile o non ha testo.
EpubPdfResult epubToPdf(Uint8List epub) {
  final content = readEpub(epub);
  final pages = layoutEpub(
      content.blocks, (text, size, bold) => measureHelvetica(text, size, bold: bold));
  final doc = PdfDocument.open(
      PdfBlankDocument.create(pageSize: PdfPageSize.a4, pageCount: pages.length));
  final editor = PdfEditor(doc);
  for (var i = 0; i < pages.length; i++) {
    final lines = pages[i];
    if (lines.isEmpty) continue;
    editor.stampPage(i, (stamp) {
      for (final line in lines) {
        stamp.text(line.text,
            x: line.x, y: line.y, size: line.size, bold: line.bold);
      }
    });
  }
  return (
    bytes: editor.save(),
    pages: pages.length,
    chapters: content.chapters,
    title: content.title,
  );
}

/// [epubToPdf] fuori dal filo dell'interfaccia: un libro lungo è lento.
Future<EpubPdfResult> epubToPdfAsync(Uint8List epub) =>
    compute(epubToPdf, epub, debugLabel: 'epub to PDF');

/// Il titolo della scheda: il nome del file senza `.epub`, più `.pdf`.
String epubTitle(String fileName) {
  var stem = fileName.trim();
  if (stem.toLowerCase().endsWith('.epub')) {
    stem = stem.substring(0, stem.length - 5).trim();
  }
  if (stem.isEmpty) stem = 'libro';
  return '$stem.pdf';
}
