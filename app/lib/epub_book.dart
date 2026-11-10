import 'dart:collection' show HashMap;
import 'dart:convert' show utf8;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:pdf_document/pdf_document.dart';

// Libri .epub: un file zip con i capitoli in XHTML. Si legge l'elenco dei
// capitoli (nell'ordine del libro), si estrae il testo, lo si impagina su fogli
// A4 e lo si scrive con il motore (Helvetica) in un PDF nuovo, che si apre in
// una scheda. Titoli e paragrafi, più copertina e immagini PNG o JPEG, corsivo
// per i paragrafi tutti in corsivo, note a fine capitolo e indice come
// segnalibri. Cirillico e greco si traslitterano in lettere latine.
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
  const EpubBlock(this.text,
      {this.level = 0,
      this.chapterStart = false,
      this.italic = false,
      this.imageSrc,
      this.imageBytes});

  final String text;

  /// 0 paragrafo, 1-3 titoli, 4 nota a fine capitolo.
  final int level;
  final bool chapterStart;

  /// Vero se tutto il testo del blocco è in corsivo.
  final bool italic;

  /// Un blocco immagine: il percorso come scritto nel capitolo (`src`), poi
  /// quello dentro lo zip e i byte (PNG o JPEG) dopo la lettura del libro.
  final String? imageSrc;
  final Uint8List? imageBytes;

  EpubBlock withChapterStart(bool value) => EpubBlock(text,
      level: level,
      chapterStart: value,
      italic: italic,
      imageSrc: imageSrc,
      imageBytes: imageBytes);

  @override
  bool operator ==(Object other) =>
      other is EpubBlock &&
      other.text == text &&
      other.level == level &&
      other.chapterStart == chapterStart &&
      other.italic == italic &&
      other.imageSrc == imageSrc;

  @override
  int get hashCode => Object.hash(text, level, chapterStart, italic, imageSrc);

  @override
  String toString() =>
      'EpubBlock($text, level: $level, start: $chapterStart, italic: $italic, image: $imageSrc)';
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
        out.write(_transliterate(code) ?? '?');
      default:
        out.writeCharCode(code);
    }
  }
  return out.toString();
}

const _cyrillic = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo',
  'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
  'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
  'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
  'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya', 'і': 'i',
  'ї': 'yi', 'є': 'ye', 'ґ': 'g', 'ў': 'u',
};

const _greek = {
  'α': 'a', 'β': 'v', 'γ': 'g', 'δ': 'd', 'ε': 'e', 'ζ': 'z', 'η': 'i',
  'θ': 'th', 'ι': 'i', 'κ': 'k', 'λ': 'l', 'μ': 'm', 'ν': 'n', 'ξ': 'x',
  'ο': 'o', 'π': 'p', 'ρ': 'r', 'σ': 's', 'ς': 's', 'τ': 't', 'υ': 'y',
  'φ': 'f', 'χ': 'ch', 'ψ': 'ps', 'ω': 'o', 'ά': 'a', 'έ': 'e', 'ή': 'i',
  'ί': 'i', 'ό': 'o', 'ύ': 'y', 'ώ': 'o', 'ϊ': 'i', 'ϋ': 'y', 'ΐ': 'i',
  'ΰ': 'y',
};

/// Le lettere cirilliche e greche in lettere latine (traslitterazione), con la
/// maiuscola dove c'era. Null per tutto il resto (cinese, giapponese...).
String? _transliterate(int code) {
  final ch = String.fromCharCode(code);
  final lower = ch.toLowerCase();
  final mapped = _cyrillic[lower] ?? _greek[lower];
  if (mapped == null) return null;
  if (ch == lower || mapped.isEmpty) return mapped;
  return mapped[0].toUpperCase() + mapped.substring(1);
}

const _noteTypes = ['footnote', 'endnote', 'rearnote'];

const _blockTags = {
  'p', 'div', 'section', 'article', 'blockquote', 'ul', 'ol', 'li', 'tr',
  'table', 'pre', 'br', 'hr', 'header', 'footer', 'figure', 'figcaption',
  'dd', 'dt', 'dl', 'aside', 'nav', 'caption', 'h1', 'h2', 'h3', 'h4', 'h5',
  'h6', 'title',
};

/// Il testo di un capitolo XHTML come blocchi (titoli, paragrafi, immagini).
/// Gli elenchi hanno un trattino davanti. Un blocco tutto dentro `<i>`, `<em>`
/// o `<cite>` è in corsivo. Le note (`epub:type` footnote, endnote, rearnote)
/// vanno in fondo al capitolo come blocchi di livello 4. Script, stili e
/// intestazione della pagina si saltano. Il primo blocco porta `chapterStart`.
List<EpubBlock> htmlToBlocks(String html) {
  var source = html;
  source = source.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ');
  source = source.replaceAll(
      RegExp(r'<(script|style|head)\b[^>]*>.*?</\1\s*>',
          dotAll: true, caseSensitive: false),
      ' ');
  final blocks = <EpubBlock>[];
  final notes = <EpubBlock>[];
  final buffer = StringBuffer();
  var level = 0;
  var pendingBullet = false;
  var italicDepth = 0;
  var plainChars = 0;
  var italicChars = 0;
  String? noteTag;
  var noteDepth = 0;

  void addText(String t) {
    if (t.isEmpty) return;
    buffer.write(t);
    final n = t.replaceAll(RegExp(r'\s'), '').length;
    if (italicDepth > 0) {
      italicChars += n;
    } else {
      plainChars += n;
    }
  }

  void flush() {
    final text = pdfSafeText(decodeEntities(buffer.toString()))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final italic = italicChars > 0 && plainChars == 0;
    buffer.clear();
    italicChars = 0;
    plainChars = 0;
    if (text.isEmpty) {
      level = 0;
      return;
    }
    final inNote = noteTag != null;
    final block = EpubBlock(pendingBullet ? '- $text' : text,
        level: inNote ? 4 : level, italic: italic);
    (inNote ? notes : blocks).add(block);
    level = 0;
    pendingBullet = false;
  }

  var pos = 0;
  for (final m in RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>').allMatches(source)) {
    addText(source.substring(pos, m.start));
    pos = m.end;
    final closing = m.group(1) == '/';
    final tag = m.group(2)!.toLowerCase();
    final raw = m.group(0)!;
    if (tag == 'i' || tag == 'em' || tag == 'cite') {
      if (closing) {
        if (italicDepth > 0) italicDepth--;
      } else {
        italicDepth++;
      }
      continue;
    }
    if ((tag == 'img' || tag == 'image') && !closing) {
      var src = _attr(raw, 'src');
      if (src.isEmpty) src = _attr(raw, 'xlink:href');
      if (src.isEmpty) src = _attr(raw, 'href');
      if (src.isNotEmpty) {
        flush();
        blocks.add(EpubBlock('', imageSrc: src));
      }
      continue;
    }
    if (!_blockTags.contains(tag)) continue;
    flush();
    if (noteTag != null) {
      if (tag == noteTag) {
        if (closing) {
          noteDepth--;
          if (noteDepth == 0) noteTag = null;
        } else {
          noteDepth++;
        }
      }
    } else if (!closing) {
      final type = _attr(raw, 'epub:type').toLowerCase();
      if (type.isNotEmpty && _noteTypes.any(type.contains)) {
        noteTag = tag;
        noteDepth = 1;
      }
    }
    if (!closing) {
      if (tag.length == 2 && tag[0] == 'h' && '123456'.contains(tag[1])) {
        level = int.parse(tag[1]).clamp(1, 3);
      }
      if (tag == 'li' && noteTag == null) pendingBullet = true;
    }
  }
  addText(source.substring(pos));
  flush();
  final all = [...blocks, ...notes];
  if (all.isEmpty) return all;
  all[0] = all.first.withChapterStart(true);
  return all;
}

// --- Dal libro ai blocchi ---------------------------------------------------

/// Il contenuto di un libro: titolo (se c'è), numero di capitoli, blocchi e
/// copertina (byte PNG o JPEG, se c'è).
typedef EpubContent = ({
  String? title,
  int chapters,
  List<EpubBlock> blocks,
  Uint8List? cover,
});

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

/// I byte di un'immagine dello zip se è PNG o JPEG, altrimenti null (GIF, SVG,
/// WebP... non si portano).
Uint8List? _imageBytes(ArchiveFile? f) {
  if (f == null) return null;
  final bytes = Uint8List.fromList(f.content as List<int>);
  final png = bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
  final jpeg = bytes.length > 4 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  return png || jpeg ? bytes : null;
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

  final manifest = <String, ({String href, String type, String props})>{};
  for (final m in RegExp(r'<item\b[^>]*>', caseSensitive: false).allMatches(opf)) {
    final tag = m.group(0)!;
    manifest[_attr(tag, 'id')] = (
      href: _attr(tag, 'href'),
      type: _attr(tag, 'media-type'),
      props: _attr(tag, 'properties'),
    );
  }
  // La copertina: `<meta name="cover" content="id">` (EPUB 2) oppure l'item
  // con `properties="cover-image"` (EPUB 3).
  String? coverHref;
  for (final m in RegExp(r'<meta\b[^>]*>', caseSensitive: false).allMatches(opf)) {
    final tag = m.group(0)!;
    if (_attr(tag, 'name').toLowerCase() == 'cover') {
      coverHref = manifest[_attr(tag, 'content')]?.href;
      break;
    }
  }
  coverHref ??= manifest.values
      .where((i) => i.props.split(' ').contains('cover-image'))
      .map((i) => i.href)
      .firstOrNull;
  final coverPath =
      coverHref == null || coverHref.isEmpty ? null : resolveEpubPath(base, coverHref);
  final cover = coverPath == null ? null : _imageBytes(byName[coverPath]);
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
    final chapterPath = resolveEpubPath(base, item.href);
    final file = byName[chapterPath];
    if (file == null) continue;
    final chapterDir = _dirOf(chapterPath);
    var chapter = <EpubBlock>[];
    for (final b in htmlToBlocks(_text(file))) {
      final src = b.imageSrc;
      if (src == null) {
        chapter.add(b);
        continue;
      }
      final path = resolveEpubPath(chapterDir, src);
      final bytes = _imageBytes(byName[path]);
      if (bytes == null) continue; // immagine che non si può portare
      chapter.add(EpubBlock('',
          chapterStart: b.chapterStart, imageSrc: path, imageBytes: bytes));
    }
    // Una pagina fatta solo della copertina non si ripete: la copertina è già
    // la prima pagina del PDF.
    if (chapter.isNotEmpty &&
        coverPath != null &&
        chapter.every((b) => b.imageSrc == coverPath)) {
      continue;
    }
    if (chapter.isEmpty) continue;
    chapter[0] = chapter.first.withChapterStart(true);
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
    cover: cover,
  );
}

// --- Impaginazione ----------------------------------------------------------

/// Una riga già posizionata: [y] è la linea di base, dal basso della pagina.
class EpubLine {
  const EpubLine(this.text, this.x, this.y, this.size, this.bold,
      {this.italic = false, this.image, this.width = 0, this.height = 0});

  final String text;
  final double x;
  final double y;
  final double size;
  final bool bold;
  final bool italic;

  /// Una riga che è un'immagine (PNG o JPEG): [y] è il suo lato basso, [width]
  /// e [height] la misura sulla pagina.
  final Uint8List? image;
  final double width;
  final double height;
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

/// Larghezza e altezza in punti di un'immagine (PNG o JPEG), o null se non si
/// legge.
typedef EpubImageSize = ({double width, double height})? Function(Uint8List bytes);

/// Impagina i [blocks] su pagine A4: le righe di ogni pagina, dall'alto.
/// Un capitolo nuovo comincia sempre su una pagina nuova. Le immagini
/// ([imageSize] ne dà la misura) si riducono per stare nella pagina; senza
/// [imageSize] si saltano. Se c'è [chapterStarts], vi si scrive per ogni
/// capitolo l'indice del suo primo blocco e la pagina (da 0) dove comincia.
/// Ritorna almeno una pagina (anche vuota) se ci sono blocchi.
List<List<EpubLine>> layoutEpub(
  List<EpubBlock> blocks,
  EpubMeasure measure, {
  EpubImageSize? imageSize,
  List<({int block, int page})>? chapterStarts,
}) {
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

  for (var index = 0; index < blocks.length; index++) {
    final block = blocks[index];
    final bytes = block.imageBytes;
    if (bytes != null) {
      final dims = imageSize?.call(bytes);
      if (dims == null || dims.width <= 0 || dims.height <= 0) continue;
      if (block.chapterStart && current.isNotEmpty) newPage();
      final maxHeight = (epubPageHeight - 2 * _margin) * 0.6;
      final scale = [1.0, width / dims.width, maxHeight / dims.height]
          .reduce(math.min);
      final w = dims.width * scale;
      final h = dims.height * scale;
      if (current.isNotEmpty && y - h < _margin) newPage();
      if (block.chapterStart) {
        chapterStarts?.add((block: index, page: pages.length));
      }
      y -= h;
      current.add(EpubLine('', _margin + (width - w) / 2, y, 0, false,
          image: bytes, width: w, height: h));
      y -= 8;
      continue;
    }
    final size = switch (block.level) {
      1 => 18.0,
      2 => 15.0,
      3 => 13.0,
      4 => 9.0,
      _ => bodySize,
    };
    final isHeading = block.level >= 1 && block.level <= 3;
    final bold = isHeading;
    final leading = size * 1.35;
    final before = isHeading ? size * 0.6 : 0.0;
    if (block.chapterStart && current.isNotEmpty) newPage();
    final lines = wrapEpubText(block.text, width, size, bold, measure);
    if (lines.isEmpty) continue;
    // Il titolo non resta solo in fondo alla pagina: con meno di tre righe di
    // spazio si passa alla pagina dopo.
    if (isHeading &&
        current.isNotEmpty &&
        y - before - leading * 3 < _margin) {
      newPage();
    }
    if (block.chapterStart) {
      chapterStarts?.add((block: index, page: pages.length));
    }
    if (current.isNotEmpty) y -= before;
    for (final line in lines) {
      if (y - leading < _margin && current.isNotEmpty) newPage();
      y -= leading;
      current.add(EpubLine(line, _margin, y, size, bold, italic: block.italic));
    }
    y -= isHeading ? size * 0.3 : 5;
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

/// Il titolo di un capitolo per l'indice: il titolo (livello 1-3) del suo primo
/// blocco o dei due dopo, altrimenti "Capitolo N". [first] è l'indice del
/// primo blocco del capitolo.
String epubChapterTitle(List<EpubBlock> blocks, int first, int number) {
  for (var i = first; i < blocks.length && i <= first + 2; i++) {
    if (i > first && blocks[i].chapterStart) break;
    final b = blocks[i];
    if (b.imageBytes == null && b.level >= 1 && b.level <= 3 && b.text.isNotEmpty) {
      return b.text.length > 80 ? '${b.text.substring(0, 80)}...' : b.text;
    }
  }
  return 'Capitolo $number';
}

/// Legge [epub] e lo trasforma in un PDF: la copertina (se c'è) come prima
/// pagina, poi titoli, paragrafi e immagini su pagine A4, con i capitoli come
/// segnalibri quando sono almeno due. Lancia [FormatException] se non è un
/// EPUB leggibile o non ha testo.
EpubPdfResult epubToPdf(Uint8List epub) {
  final content = readEpub(epub);
  final decoded = HashMap<Uint8List, PdfEmbeddableImage?>.identity();
  PdfEmbeddableImage? decode(Uint8List? bytes) {
    if (bytes == null) return null;
    return decoded.putIfAbsent(bytes, () {
      try {
        return PdfEmbeddableImage.decode(bytes);
      } catch (_) {
        return null;
      }
    });
  }

  final starts = <({int block, int page})>[];
  final pages = layoutEpub(
    content.blocks,
    (text, size, bold) => measureHelvetica(text, size, bold: bold),
    imageSize: (bytes) {
      final img = decode(bytes);
      return img == null
          ? null
          : (width: img.width.toDouble(), height: img.height.toDouble());
    },
    chapterStarts: starts,
  );
  final cover = decode(content.cover);
  final offset = cover == null ? 0 : 1;
  final doc = PdfDocument.open(PdfBlankDocument.create(
      pageSize: PdfPageSize.a4, pageCount: pages.length + offset));
  final editor = PdfEditor(doc);
  if (cover != null) {
    editor.stampPage(0, (stamp) {
      const margin = 36.0;
      final scale = math.min((epubPageWidth - 2 * margin) / cover.width,
          (epubPageHeight - 2 * margin) / cover.height);
      final w = cover.width * scale;
      final h = cover.height * scale;
      stamp.image(cover,
          x: (epubPageWidth - w) / 2,
          y: (epubPageHeight - h) / 2,
          width: w,
          height: h);
    });
  }
  for (var i = 0; i < pages.length; i++) {
    final lines = pages[i];
    if (lines.isEmpty) continue;
    editor.stampPage(i + offset, (stamp) {
      for (final line in lines) {
        final bytes = line.image;
        if (bytes != null) {
          final img = decode(bytes);
          if (img != null) {
            stamp.image(img,
                x: line.x, y: line.y, width: line.width, height: line.height);
          }
        } else {
          stamp.text(line.text,
              x: line.x,
              y: line.y,
              size: line.size,
              bold: line.bold,
              italic: line.italic);
        }
      }
    });
  }
  if (starts.length >= 2) {
    if (cover != null) editor.addOutlineItem('Copertina', pageIndex: 0);
    for (var n = 0; n < starts.length; n++) {
      editor.addOutlineItem(
        epubChapterTitle(content.blocks, starts[n].block, n + 1),
        pageIndex: starts[n].page + offset,
      );
    }
  }
  return (
    bytes: editor.save(),
    pages: pages.length + offset,
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
