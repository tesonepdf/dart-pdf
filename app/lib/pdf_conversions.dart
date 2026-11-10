import 'dart:convert' show utf8;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart'
    show PdfExtractedRun, PdfReflowBlock, PdfTextExtractor;

import 'image_to_pdf.dart';

// Conversioni da e verso il PDF (punto 1: testo semplice e foto in PDF;
// punto 2: PDF in Word; punto 3: PDF in Excel).
// Solo logica, senza interfaccia: le finestre stanno in
// `photos_to_pdf_dialog.dart` e il collegamento al menu in `editor_screen.dart`.

// --- PDF in testo semplice (.txt) -------------------------------------------

/// Il testo di una pagina pronto per un file di testo: a capo uniformi e
/// niente righe vuote o spazi all'inizio e alla fine.
String cleanPageText(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

/// Unisce i testi delle pagine con una riga vuota tra una pagina e l'altra e
/// un a capo finale, come si aspetta un file di testo.
String joinPageTexts(List<String> pages) =>
    pages.isEmpty ? '' : '${pages.map(cleanPageText).join('\n\n')}\n';

/// Vero se [text] contiene almeno un carattere che non sia spazio o a capo.
/// Falso per un PDF che è una scansione, cioè solo immagini.
bool plainTextHasContent(String text) => text.trim().isNotEmpty;

/// Il nome proposto per il file di testo: il titolo senza `.pdf`, più `.txt`.
String textExportFileName(String title) {
  var stem = title.trim();
  if (stem.toLowerCase().endsWith('.pdf')) {
    stem = stem.substring(0, stem.length - 4).trim();
  }
  if (stem.isEmpty) stem = 'documento';
  return '$stem.txt';
}

/// Il risultato di [pdfToPlainText]: il testo di tutto il documento e le
/// pagine (da 0) che non si sono riuscite a leggere.
typedef PlainTextResult = ({String text, List<int> failedPages});

/// Legge il testo di ogni pagina di [document] con il motore
/// ([PdfTextExtractor], lo stesso della ricerca) e lo mette in un unico testo,
/// con una riga vuota tra le pagine. Una pagina che non si legge viene
/// saltata e riportata in `failedPages`, senza fermare le altre.
///
/// Tra una pagina e l'altra il ciclo degli eventi ha un turno, così
/// l'interfaccia non si blocca su un documento lungo. [onPage] riceve la
/// pagina che sta per essere letta (da 0) e il numero di pagine.
Future<PlainTextResult> pdfToPlainText(
  PdfDocument document, {
  void Function(int page, int pageCount)? onPage,
}) async {
  final count = document.pageCount;
  final pages = <String>[];
  final failed = <int>[];
  for (var i = 0; i < count; i++) {
    onPage?.call(i, count);
    try {
      pages.add(PdfTextExtractor.extract(document, i).text);
    } catch (_) {
      pages.add('');
      failed.add(i);
    }
    await Future<void>.delayed(Duration.zero);
  }
  return (text: joinPageTexts(pages), failedPages: failed);
}

// --- Più foto in un PDF, una pagina per foto --------------------------------

/// Come è fatta la pagina di ogni foto.
enum PhotoPdfPage {
  /// Foglio A4, in piedi o per traverso secondo la foto; la foto ci sta tutta.
  a4,

  /// La pagina ha la forma della foto (larga come un A4), senza bordi bianchi.
  photoSize,
}

/// A4 per traverso (punti), per le foto più larghe che alte.
const PdfPageSize kA4Landscape = PdfPageSize(841.89, 595.28);

/// Il risultato di [photosToPdf]: il PDF, le pagine che ha e quante foto si
/// sono dovute saltare perché non leggibili (o perché erano già dei PDF).
typedef PhotosPdfResult = ({Uint8List bytes, int pages, int skipped});

/// Mette ogni foto di [photos] (byte di JPEG, PNG, HEIC... nell'ordine
/// dato) in una pagina di un PDF nuovo. Le foto si rimettono dritte (con
/// l'orientamento EXIF applicato). Lancia [FormatException] se nessuna foto è
/// leggibile.
PhotosPdfResult photosToPdf(List<Uint8List> photos, PhotoPdfPage page) {
  final pdfs = <Uint8List>[];
  var skipped = 0;
  for (final raw in photos) {
    if (looksLikePdf(raw)) {
      skipped++;
      continue;
    }
    final UprightPhoto photo;
    try {
      photo = uprightPhoto(raw);
    } catch (_) {
      skipped++;
      continue;
    }
    pdfs.add(_onePhotoPdf(photo, page));
  }
  if (pdfs.isEmpty) {
    throw const FormatException('nessuna foto leggibile');
  }
  final bytes = pdfs.length == 1 ? pdfs.single : PdfMerger.merge(pdfs);
  return (bytes: bytes, pages: pdfs.length, skipped: skipped);
}

/// Un PDF di una pagina con la sola [photo].
Uint8List _onePhotoPdf(UprightPhoto photo, PhotoPdfPage page) => switch (page) {
      PhotoPdfPage.a4 => PdfImageDocument.fromImageBytes(
          [photo.bytes],
          pageSize: photo.width > photo.height ? kA4Landscape : PdfPageSize.a4,
          fit: PdfImageFit.contain,
        ),
      // Come la foto aperta da sola ([imageBytesToPdf]): la pagina è larga
      // circa quanto un A4 e ha le proporzioni della foto.
      PhotoPdfPage.photoSize => PdfImageDocument.fromImageBytes(
          [photo.bytes],
          dpi: photoDpi(photo.width, photo.height, null),
        ),
    };

PhotosPdfResult _photosToPdfJob(
        ({List<Uint8List> photos, PhotoPdfPage page}) args) =>
    photosToPdf(args.photos, args.page);

/// [photosToPdf] fuori dal filo dell'interfaccia: decodificare e riscrivere
/// molte foto è lento.
Future<PhotosPdfResult> photosToPdfAsync(
        List<Uint8List> photos, PhotoPdfPage page) =>
    compute(_photosToPdfJob, (photos: photos, page: page),
        debugLabel: 'photos to PDF');

// --- PDF in Word (.docx) -----------------------------------------------------
//
// Prima versione: i paragrafi si ricostruiscono dalle righe di testo (lo stesso
// ordine di lettura della vista "Lettura"), e il file Word si scrive a mano
// con la libreria zip già presente (`archive`). L'impaginazione non è identica
// all'originale, le tabelle diventano testo e le immagini non vengono portate.

/// Un paragrafo del file Word.
class DocxParagraph {
  const DocxParagraph(this.text,
      {this.fontSize = 11, this.isListItem = false, this.pageBreakBefore = false});

  final String text;

  /// Corpo in punti.
  final double fontSize;

  /// Vero se comincia con un punto elenco o un numero: si rientra a sinistra.
  final bool isListItem;

  /// Vero per il primo paragrafo di ogni pagina del PDF tranne la prima.
  final bool pageBreakBefore;
}

/// Il nome proposto per il file Word: il titolo senza `.pdf`, più `.docx`.
String docxExportFileName(String title) {
  final txt = textExportFileName(title);
  return '${txt.substring(0, txt.length - 4)}.docx';
}

/// Toglie da [text] i caratteri che un file XML non può contenere (controlli
/// vecchi, metà di coppie surrogate) e mette `&`, `<` e `>` nella forma
/// giusta.
String xmlSafeText(String text) {
  final out = StringBuffer();
  final units = text.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final c = units[i];
    if (c >= 0xD800 && c <= 0xDBFF) {
      // Metà alta di una coppia: tenuta solo se segue la metà bassa.
      if (i + 1 < units.length &&
          units[i + 1] >= 0xDC00 &&
          units[i + 1] <= 0xDFFF) {
        out.writeCharCode(c);
        out.writeCharCode(units[i + 1]);
        i++;
      }
      continue;
    }
    if (c >= 0xDC00 && c <= 0xDFFF) continue; // metà bassa senza la alta
    if (c == 0x9 || c == 0xA || c == 0xD || (c >= 0x20 && c <= 0xFFFD)) {
      switch (c) {
        case 0x26:
          out.write('&amp;');
        case 0x3C:
          out.write('&lt;');
        case 0x3E:
          out.write('&gt;');
        default:
          out.writeCharCode(c);
      }
    }
  }
  return out.toString();
}

/// Il paragrafo come XML di Word (`<w:p>`).
String docxParagraphXml(DocxParagraph p) {
  // Mezzi punti, tra 6 e 72 punti.
  final half = (p.fontSize.isFinite ? p.fontSize : 11).clamp(6, 72) * 2;
  final size = half.round();
  final props = StringBuffer();
  if (p.pageBreakBefore) props.write('<w:pageBreakBefore/>');
  if (p.isListItem) props.write('<w:ind w:left="360"/>');
  final pPr = props.isEmpty ? '' : '<w:pPr>$props</w:pPr>';
  final text = xmlSafeText(p.text.replaceAll('\r\n', '\n'));
  if (text.trim().isEmpty) return '<w:p>$pPr</w:p>';
  // Un a capo dentro il paragrafo diventa un `<w:br/>`.
  final runs = text
      .split('\n')
      .map((line) => '<w:t xml:space="preserve">$line</w:t>')
      .join('<w:br/>');
  return '<w:p>$pPr<w:r><w:rPr><w:sz w:val="$size"/></w:rPr>$runs</w:r></w:p>';
}

/// Scrive il file Word (.docx) dei [paragraphs]. Un .docx è un file zip con
/// tre parti obbligatorie: i tipi, il collegamento al documento e il
/// documento stesso.
Uint8List buildDocx(List<DocxParagraph> paragraphs) {
  const ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
  const header = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
  final body = paragraphs.isEmpty
      ? '<w:p/>'
      : paragraphs.map(docxParagraphXml).join();
  final document = '$header<w:document $ns><w:body>$body'
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" '
      'w:header="709" w:footer="709" w:gutter="0"/></w:sectPr>'
      '</w:body></w:document>';
  const contentTypes = '$header<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>';
  const rels = '$header<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';
  final archive = Archive()
    ..addFile(_zipEntry('[Content_Types].xml', contentTypes))
    ..addFile(_zipEntry('_rels/.rels', rels))
    ..addFile(_zipEntry('word/document.xml', document));
  return ZipEncoder().encodeBytes(archive);
}

ArchiveFile _zipEntry(String name, String content) =>
    ArchiveFile.bytes(name, Uint8List.fromList(utf8.encode(content)));

/// Il risultato di [pdfToDocx]: il file Word, i paragrafi che contiene e le
/// pagine (da 0) che non si sono riuscite a leggere.
typedef DocxResult = ({Uint8List bytes, int paragraphs, List<int> failedPages});

/// Ricostruisce i paragrafi di ogni pagina di [document] con il motore
/// ([PdfTextExtractor.reflowPage]) e ne fa un file Word. Le immagini e le
/// tabelle non vengono portate (le righe delle tabelle diventano testo).
/// Una pagina che non si legge viene saltata e riportata in `failedPages`.
/// [onPage] riceve la pagina che sta per essere letta (da 0) e il numero di
/// pagine; tra una pagina e l'altra l'interfaccia ha un turno.
Future<DocxResult> pdfToDocx(
  PdfDocument document, {
  void Function(int page, int pageCount)? onPage,
}) async {
  final count = document.pageCount;
  final paragraphs = <DocxParagraph>[];
  final failed = <int>[];
  for (var i = 0; i < count; i++) {
    onPage?.call(i, count);
    try {
      final blocks = <PdfReflowBlock>[
        for (final b in PdfTextExtractor.reflowPage(document, i).blocks)
          if (b.text.trim().isNotEmpty) b,
      ];
      var first = true;
      for (final b in blocks) {
        paragraphs.add(DocxParagraph(b.text.trim(),
            fontSize: b.fontSize,
            isListItem: b.isListItem,
            pageBreakBefore: first && i > 0));
        first = false;
      }
      // Una pagina senza testo tiene comunque il suo posto nel file Word.
      if (blocks.isEmpty && i > 0) {
        paragraphs.add(const DocxParagraph('', pageBreakBefore: true));
      }
    } catch (_) {
      failed.add(i);
      if (i > 0) paragraphs.add(const DocxParagraph('', pageBreakBefore: true));
    }
    await Future<void>.delayed(Duration.zero);
  }
  return (
    bytes: buildDocx(paragraphs),
    paragraphs: paragraphs.where((p) => p.text.isNotEmpty).length,
    failedPages: failed,
  );
}

// --- PDF in Excel (.xlsx) ----------------------------------------------------
//
// Prima versione, documento intero: le righe si trovano dalla posizione
// verticale del testo, le colonne dagli spazi larghi tra le parole, e i numeri
// diventano numeri veri nelle celle. Una scheda (foglio) per ogni pagina che
// ha del testo. Funziona bene sulle tabelle, male sui PDF che non lo sono.
// Limiti: una cella che si estende su più colonne (un titolo largo dentro una
// riga di più celle) può unire le colonne; niente formati, colori o bordi.

/// Una cella trovata sulla pagina, prima di sapere in che colonna va. [left] e
/// [right] sono in punti della pagina.
class PageCell {
  const PageCell(this.left, this.right, this.text);

  final double left;
  final double right;
  final String text;
}

class _Piece {
  const _Piece(this.left, this.right, this.top, this.bottom, this.text);

  final double left;
  final double right;
  final double top;
  final double bottom;
  final String text;

  double get center => (top + bottom) / 2;
  double get height => top - bottom;
}

/// Le righe di celle di una pagina, dall'alto in basso e da sinistra a
/// destra. Una riga è fatta dal testo che sta alla stessa altezza; due pezzi
/// di testo della stessa riga stanno nella stessa cella se la distanza è meno
/// di un'altezza di carattere, altrimenti sono celle diverse. Dentro un pezzo
/// di testo, due o più spazi di fila (o una tabulazione) separano le celle.
///
/// Con [zone] (nello spazio della pagina) restano solo i pezzi di testo il cui
/// centro cade dentro la zona.
List<List<PageCell>> pageCellRows(Iterable<PdfExtractedRun> runs,
    {PdfRect? zone}) {
  final pieces = <_Piece>[];
  final separator = RegExp(r' {2,}|\t+');
  for (final run in runs) {
    final text = run.text;
    final b = run.bounds;
    if (text.trim().isEmpty || !(b.width > 0) || !(b.height > 0)) continue;
    final len = text.length;
    void add(int from, int to) {
      final seg = text.substring(from, to);
      final trimmed = seg.trim();
      if (trimmed.isEmpty) return;
      final s = from + (seg.length - seg.trimLeft().length);
      final e = s + trimmed.length;
      final pieceLeft = b.left + b.width * s / len;
      final pieceRight = b.left + b.width * e / len;
      if (zone != null &&
          !zone.contains((pieceLeft + pieceRight) / 2, (b.top + b.bottom) / 2)) {
        return;
      }
      pieces.add(_Piece(pieceLeft, pieceRight, b.top, b.bottom, trimmed));
    }

    var start = 0;
    for (final m in separator.allMatches(text)) {
      add(start, m.start);
      start = m.end;
    }
    add(start, len);
  }

  // Dall'alto in basso (la y della pagina cresce verso l'alto).
  pieces.sort((a, b) => b.center.compareTo(a.center));
  final rows = <List<_Piece>>[];
  var rowCenter = 0.0;
  var rowHeight = 0.0;
  for (final p in pieces) {
    if (rows.isNotEmpty &&
        (p.center - rowCenter).abs() <= 0.5 * math.min(rowHeight, p.height)) {
      rows.last.add(p);
    } else {
      rows.add([p]);
      rowCenter = p.center;
      rowHeight = p.height;
    }
  }

  final out = <List<PageCell>>[];
  for (final row in rows) {
    row.sort((a, b) => a.left.compareTo(b.left));
    final cells = <PageCell>[];
    var text = row.first.text;
    var left = row.first.left;
    var right = row.first.right;
    var height = row.first.height;
    for (final p in row.skip(1)) {
      final gap = p.left - right;
      final em = math.min(height, p.height);
      if (gap > em) {
        cells.add(PageCell(left, right, text));
        text = p.text;
        left = p.left;
        right = p.right;
        height = p.height;
      } else {
        text = gap > 0.15 * em ? '$text ${p.text}' : '$text${p.text}';
        right = math.max(right, p.right);
        height = p.height;
      }
    }
    cells.add(PageCell(left, right, text));
    out.add(cells);
  }
  return out;
}

/// Le colonne della pagina: gli intervalli (da sinistra a destra) in cui
/// cadono le celle delle righe con almeno due celle. Le celle che si
/// sovrappongono (a sinistra, a destra o al centro) sono la stessa colonna,
/// quindi funziona anche per i numeri allineati a destra. Se nessuna riga ha
/// due celle, contano tutte.
List<({double left, double right})> columnSpans(List<List<PageCell>> rows) {
  var source = <PageCell>[
    for (final r in rows)
      if (r.length >= 2) ...r,
  ];
  if (source.isEmpty) source = [for (final r in rows) ...r];
  source.sort((a, b) => a.left.compareTo(b.left));
  final spans = <({double left, double right})>[];
  for (final c in source) {
    if (spans.isNotEmpty && c.left <= spans.last.right) {
      spans[spans.length - 1] = (
        left: spans.last.left,
        right: math.max(spans.last.right, c.right),
      );
    } else {
      spans.add((left: c.left, right: c.right));
    }
  }
  return spans;
}

/// La griglia di testo di una pagina: righe per colonne, con `''` dove la
/// cella è vuota. Vuota se nella pagina non c'è testo. Con [zone] conta solo
/// il testo dentro la zona (vedi [pageCellRows]).
List<List<String>> pageGrid(Iterable<PdfExtractedRun> runs, {PdfRect? zone}) {
  final rows = pageCellRows(runs, zone: zone);
  if (rows.isEmpty) return const [];
  final spans = columnSpans(rows);

  // La colonna che comincia più a destra senza superare l'inizio della cella.
  int byLeftEdge(PageCell c) {
    var index = 0;
    for (var i = 0; i < spans.length; i++) {
      if (spans[i].left <= c.left + 1) index = i;
    }
    return index;
  }

  int byOverlap(PageCell c) {
    var best = -1;
    var bestOverlap = 0.0;
    for (var i = 0; i < spans.length; i++) {
      final overlap =
          math.min(spans[i].right, c.right) - math.max(spans[i].left, c.left);
      if (overlap > bestOverlap) {
        best = i;
        bestOverlap = overlap;
      }
    }
    return best >= 0 ? best : byLeftEdge(c);
  }

  final grid = <List<String>>[];
  for (final row in rows) {
    final line = List<String>.filled(spans.length, '');
    for (final c in row) {
      // Una cella sola nella riga (un titolo) va dove comincia, non dove
      // copre più colonne.
      final i = row.length == 1 ? byLeftEdge(c) : byOverlap(c);
      line[i] = line[i].isEmpty ? c.text : '${line[i]} ${c.text}';
    }
    grid.add(line);
  }
  return grid;
}

/// Il numero scritto in [raw], oppure null se è testo. Capisce il formato
/// italiano (`1.234,56`) e quello inglese (`1,234.56`); un solo `,` è il
/// decimale, un solo `.` è il decimale tranne per `1.234` (migliaia). Un
/// segno meno, le parentesi (negativo), `€`, `$` e `£` all'inizio o alla fine
/// vanno bene. Restano testo i codici con lo zero davanti (`007`), i numeri
/// con più di 15 cifre (telefoni, IBAN), le date (`10.11.2026`) e le
/// percentuali.
num? parseSpreadsheetNumber(String raw) {
  var t = raw.trim().replaceAll('\u2212', '-');
  var negative = false;
  if (t.length > 2 && t.startsWith('(') && t.endsWith(')')) {
    negative = true;
    t = t.substring(1, t.length - 1).trim();
  }
  t = t.replaceFirst(RegExp(r'^[€$£]\s*'), '');
  t = t.replaceFirst(RegExp(r'\s*[€$£]$'), '');
  if (t.startsWith('-')) {
    negative = !negative;
    t = t.substring(1).trim();
  } else if (t.startsWith('+')) {
    t = t.substring(1).trim();
  }
  if (!RegExp(r'^\d[\d.,]*$').hasMatch(t)) return null;
  final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length > 15) return null;
  if (RegExp(r'^\d+$').hasMatch(t) && t.length > 1 && t.startsWith('0')) {
    return null;
  }

  final dots = '.'.allMatches(t).length;
  final commas = ','.allMatches(t).length;
  String normalized;
  if (dots > 0 && commas > 0) {
    // Il separatore che sta per ultimo è il decimale, l'altro le migliaia.
    final decimal = t.lastIndexOf('.') > t.lastIndexOf(',') ? '.' : ',';
    final thousands = decimal == '.' ? ',' : '.';
    if (decimal.allMatches(t).length != 1) return null;
    final at = t.lastIndexOf(decimal);
    final whole = t.substring(0, at);
    final fraction = t.substring(at + 1);
    if (fraction.isEmpty || !RegExp(r'^\d+$').hasMatch(fraction)) return null;
    final grouped =
        RegExp('^\\d{1,3}(${RegExp.escape(thousands)}\\d{3})+\$');
    if (!grouped.hasMatch(whole)) return null;
    normalized = '${whole.replaceAll(thousands, '')}.$fraction';
  } else if (commas > 0) {
    if (commas > 1) {
      if (!RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(t)) return null;
      normalized = t.replaceAll(',', '');
    } else {
      if (!RegExp(r'^\d+,\d+$').hasMatch(t)) return null;
      normalized = t.replaceAll(',', '.');
    }
  } else if (dots > 0) {
    if (dots > 1) {
      if (!RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) return null;
      normalized = t.replaceAll('.', '');
    } else if (RegExp(r'^[1-9]\d{0,2}\.\d{3}$').hasMatch(t)) {
      normalized = t.replaceAll('.', '');
    } else {
      if (!RegExp(r'^\d+\.\d+$').hasMatch(t)) return null;
      normalized = t;
    }
  } else {
    normalized = t;
  }

  final value =
      normalized.contains('.') ? double.parse(normalized) : int.parse(normalized);
  return negative ? -value : value;
}

/// Una scheda del file Excel: il [name] e le [rows] di testo (celle vuote
/// `''`). I numeri si riconoscono quando si scrive il file.
class XlsxSheet {
  const XlsxSheet(this.name, this.rows);

  final String name;
  final List<List<String>> rows;
}

/// Il nome della colonna `index` (da 0): A, B, ... Z, AA, AB...
String xlsxColumnName(int index) {
  var n = index + 1;
  final letters = <int>[];
  while (n > 0) {
    final r = (n - 1) % 26;
    letters.add(0x41 + r);
    n = (n - 1) ~/ 26;
  }
  return String.fromCharCodes(letters.reversed);
}

/// Il foglio come XML di Excel: testo in celle di testo, numeri in celle
/// numeriche, larghezza di colonna secondo il contenuto.
String xlsxSheetXml(XlsxSheet sheet) {
  final columns = sheet.rows.fold<int>(0, (m, r) => math.max(m, r.length));
  final widths = List<int>.filled(columns, 0);
  final body = StringBuffer();
  var rowNumber = 0;
  for (final row in sheet.rows) {
    rowNumber++;
    final cells = StringBuffer();
    for (var c = 0; c < row.length; c++) {
      var text = row[c];
      if (text.trim().isEmpty) continue;
      if (text.length > 32767) text = text.substring(0, 32767);
      widths[c] = math.max(widths[c], text.length);
      final ref = '${xlsxColumnName(c)}$rowNumber';
      final number = parseSpreadsheetNumber(text);
      if (number == null) {
        cells.write('<c r="$ref" t="inlineStr"><is>'
            '<t xml:space="preserve">${xmlSafeText(text)}</t></is></c>');
      } else {
        cells.write('<c r="$ref"><v>$number</v></c>');
      }
    }
    body.write('<row r="$rowNumber">$cells</row>');
  }
  final cols = StringBuffer();
  for (var c = 0; c < columns; c++) {
    final width = (widths[c] + 2).clamp(8, 60);
    cols.write('<col min="${c + 1}" max="${c + 1}" width="$width" '
        'customWidth="1"/>');
  }
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '${columns == 0 ? '' : '<cols>$cols</cols>'}'
      '<sheetData>$body</sheetData></worksheet>';
}

/// Scrive il file Excel (.xlsx) delle [sheets] (almeno una). Un .xlsx è un
/// file zip: i tipi, il collegamento al libro, il libro con l'elenco delle
/// schede, i suoi collegamenti e un file per scheda.
Uint8List buildXlsx(List<XlsxSheet> sheets) {
  if (sheets.isEmpty) throw ArgumentError('serve almeno una scheda');
  const header = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
  const relType =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  final overrides = StringBuffer();
  final sheetList = StringBuffer();
  final sheetRels = StringBuffer();
  for (var i = 0; i < sheets.length; i++) {
    final n = i + 1;
    overrides.write('<Override PartName="/xl/worksheets/sheet$n.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
    sheetList.write('<sheet name="${xmlSafeText(sheets[i].name)}" '
        'sheetId="$n" r:id="rId$n"/>');
    sheetRels.write('<Relationship Id="rId$n" Type="$relType/worksheet" '
        'Target="worksheets/sheet$n.xml"/>');
  }
  final contentTypes =
      '$header<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '$overrides</Types>';
  final rels =
      '$header<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="$relType/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';
  final workbook =
      '$header<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="$relType"><sheets>$sheetList</sheets></workbook>';
  final workbookRels =
      '$header<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '$sheetRels</Relationships>';
  final archive = Archive()
    ..addFile(_zipEntry('[Content_Types].xml', contentTypes))
    ..addFile(_zipEntry('_rels/.rels', rels))
    ..addFile(_zipEntry('xl/workbook.xml', workbook))
    ..addFile(_zipEntry('xl/_rels/workbook.xml.rels', workbookRels));
  for (var i = 0; i < sheets.length; i++) {
    archive.addFile(
        _zipEntry('xl/worksheets/sheet${i + 1}.xml', xlsxSheetXml(sheets[i])));
  }
  return ZipEncoder().encodeBytes(archive);
}

/// Il nome proposto per il file Excel: il titolo senza `.pdf`, più `.xlsx`.
String xlsxExportFileName(String title) {
  final txt = textExportFileName(title);
  return '${txt.substring(0, txt.length - 4)}.xlsx';
}

/// Il risultato di [pdfToXlsx]: il file (vuoto se nessuna pagina ha testo),
/// le schede, le celle con del contenuto, quelle che sono numeri veri e le
/// pagine (da 0) che non si sono riuscite a leggere.
typedef XlsxResult = ({
  Uint8List bytes,
  int sheets,
  int cells,
  int numbers,
  List<int> failedPages,
});

/// Legge ogni pagina di [document] con il motore ([PdfTextExtractor]), ne
/// ricava righe e colonne ([pageGrid]) e fa un file Excel con una scheda per
/// pagina che ha del testo (le altre non hanno scheda). Una pagina che non si
/// legge viene saltata e riportata in `failedPages`. [onPage] riceve la
/// pagina che sta per essere letta (da 0) e il numero di pagine.
Future<XlsxResult> pdfToXlsx(
  PdfDocument document, {
  void Function(int page, int pageCount)? onPage,
}) async {
  final count = document.pageCount;
  final sheets = <XlsxSheet>[];
  final failed = <int>[];
  var cells = 0;
  var numbers = 0;
  for (var i = 0; i < count; i++) {
    onPage?.call(i, count);
    try {
      final grid = pageGrid(PdfTextExtractor.extract(document, i).runs);
      if (grid.isNotEmpty) {
        sheets.add(XlsxSheet('Pagina ${i + 1}', grid));
        for (final row in grid) {
          for (final text in row) {
            if (text.trim().isEmpty) continue;
            cells++;
            if (parseSpreadsheetNumber(text) != null) numbers++;
          }
        }
      }
    } catch (_) {
      failed.add(i);
    }
    await Future<void>.delayed(Duration.zero);
  }
  return (
    bytes: sheets.isEmpty ? Uint8List(0) : buildXlsx(sheets),
    sheets: sheets.length,
    cells: cells,
    numbers: numbers,
    failedPages: failed,
  );
}

/// Il nome proposto per il file Excel di una zona della pagina [page] (da 0):
/// `Titolo (pagina 2).xlsx`.
String xlsxZoneFileName(String title, int page) {
  final base = xlsxExportFileName(title);
  return '${base.substring(0, base.length - 5)} (pagina ${page + 1}).xlsx';
}

/// Come [pdfToXlsx] ma per una sola zona [zone] (nello spazio della pagina)
/// della pagina [pageIndex] (da 0): una scheda sola, "Zona". È molto più
/// precisa del documento intero perché righe e colonne si cercano solo nella
/// zona. Se nella zona non c'è testo `cells` è 0 e `bytes` è vuoto.
XlsxResult pdfZoneToXlsx(PdfDocument document, int pageIndex, PdfRect zone) {
  final grid = pageGrid(PdfTextExtractor.extract(document, pageIndex).runs,
      zone: zone);
  var cells = 0;
  var numbers = 0;
  for (final row in grid) {
    for (final text in row) {
      if (text.trim().isEmpty) continue;
      cells++;
      if (parseSpreadsheetNumber(text) != null) numbers++;
    }
  }
  return (
    bytes: grid.isEmpty ? Uint8List(0) : buildXlsx([XlsxSheet('Zona', grid)]),
    sheets: grid.isEmpty ? 0 : 1,
    cells: cells,
    numbers: numbers,
    failedPages: const [],
  );
}
