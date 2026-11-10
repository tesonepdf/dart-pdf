import 'dart:convert' show utf8;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart'
    show
        PdfDecodedPixels,
        PdfExtractedRun,
        PdfReflowBlock,
        PdfReflowImage,
        PdfTextExtractor,
        decodePdfImage,
        pdfImageFilters;

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
// I paragrafi si ricostruiscono dalle righe di testo (lo stesso ordine di
// lettura della vista "Lettura"), e il file Word si scrive a mano con la
// libreria zip già presente (`archive`). L'impaginazione non è identica
// all'originale. Grassetto, corsivo e colore si portano per paragrafo (per
// maggioranza di caratteri), non per singola parola. Le tabelle si riconoscono
// ([findPageTables]) e diventano tabelle vere di Word, a colonne di larghezza
// uguale. Le immagini si portano (JPEG com'è, il resto in PNG), ridotte alla
// larghezza della pagina; le pagine di sola immagine (scansioni) restano
// senza, perché l'app propone di leggerle con l'OCR.

/// Un elemento del corpo del file Word: un paragrafo o una tabella.
sealed class DocxElement {
  const DocxElement();
}

/// Un'immagine del file Word, già nel formato del file ([extension] `jpeg` o
/// `png`). [widthPt] e [heightPt] sono la misura sulla pagina del PDF, in
/// punti; [buildDocx] la riduce alla larghezza del testo.
class DocxImage extends DocxElement {
  const DocxImage(this.bytes, this.extension, this.widthPt, this.heightPt);

  final Uint8List bytes;
  final String extension;
  final double widthPt;
  final double heightPt;
}

/// Una tabella del file Word: righe di celle di testo. Le righe più corte
/// vengono completate con celle vuote.
class DocxTable extends DocxElement {
  const DocxTable(this.rows,
      {this.fontSize = 10, this.pageBreakBefore = false});

  final List<List<String>> rows;

  /// Corpo del testo delle celle, in punti.
  final double fontSize;

  /// Vero se la tabella è il primo elemento di una pagina del PDF che non è
  /// la prima.
  final bool pageBreakBefore;
}

/// Un paragrafo del file Word.
class DocxParagraph extends DocxElement {
  const DocxParagraph(this.text,
      {this.fontSize = 11,
      this.isListItem = false,
      this.pageBreakBefore = false,
      this.bold = false,
      this.italic = false,
      this.color = 0});

  final String text;

  /// Vero se il paragrafo è in grassetto.
  final bool bold;

  /// Vero se il paragrafo è in corsivo.
  final bool italic;

  /// Colore del testo come 0xRRGGBB; 0 (nero) non scrive nessun colore.
  final int color;

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
  // L'ordine dentro `<w:rPr>` è quello dello schema di Word: b, i, color, sz.
  final rPr = StringBuffer();
  if (p.bold) rPr.write('<w:b/>');
  if (p.italic) rPr.write('<w:i/>');
  final rgb = p.color & 0xFFFFFF;
  if (rgb != 0) {
    final hex = rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
    rPr.write('<w:color w:val="$hex"/>');
  }
  rPr.write('<w:sz w:val="$size"/>');
  return '<w:p>$pPr<w:r><w:rPr>$rPr</w:rPr>$runs</w:r></w:p>';
}

/// Larghezza del testo di una pagina A4 con i margini di [buildDocx], in
/// ventesimi di punto.
const int _docxTextWidth = 11906 - 2 * 1134;

/// La tabella come XML di Word (`<w:tbl>`): colonne di larghezza uguale e
/// bordi semplici. Dopo la tabella c'è un paragrafo vuoto, perché Word non
/// vuole una tabella come ultima cosa del corpo. Vuota se non ci sono celle.
String docxTableXml(DocxTable table) {
  final columns = table.rows.fold<int>(0, (m, r) => math.max(m, r.length));
  if (columns == 0) return '';
  final width = _docxTextWidth ~/ columns;
  const line = 'w:val="single" w:sz="4" w:space="0" w:color="808080"';
  final out = StringBuffer();
  // La pagina nuova sta in un paragrafo vuoto prima della tabella: dentro la
  // prima cella Word non la rispetta sempre.
  if (table.pageBreakBefore) {
    out.write('<w:p><w:pPr><w:pageBreakBefore/></w:pPr></w:p>');
  }
  out.write('<w:tbl><w:tblPr><w:tblW w:w="${width * columns}" w:type="dxa"/>'
      '<w:tblBorders>');
  const sides = ['top', 'left', 'bottom', 'right', 'insideH', 'insideV'];
  for (final side in sides) {
    out.write('<w:$side $line/>');
  }
  out.write('</w:tblBorders></w:tblPr><w:tblGrid>');
  for (var c = 0; c < columns; c++) {
    out.write('<w:gridCol w:w="$width"/>');
  }
  out.write('</w:tblGrid>');
  for (final row in table.rows) {
    out.write('<w:tr>');
    for (var c = 0; c < columns; c++) {
      final text = c < row.length ? row[c] : '';
      out.write('<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/></w:tcPr>'
          '${docxParagraphXml(DocxParagraph(text, fontSize: table.fontSize))}'
          '</w:tc>');
    }
    out.write('</w:tr>');
  }
  out.write('</w:tbl><w:p/>');
  return out.toString();
}

/// L'immagine come XML di Word (`<w:drawing>` dentro un paragrafo). [number]
/// (da 1) dà il nome del file in `word/media` e il collegamento `rId$number`.
/// Più larga del testo della pagina, si riduce tenendo le proporzioni.
String docxImageXml(DocxImage image, {required int number}) {
  const emuPerPoint = 12700;
  const maxWidth = _docxTextWidth * 635; // un ventesimo di punto = 635 EMU
  var width = (image.widthPt.isFinite ? image.widthPt : 1) * emuPerPoint;
  var height = (image.heightPt.isFinite ? image.heightPt : 1) * emuPerPoint;
  if (width < emuPerPoint) width = emuPerPoint.toDouble();
  if (height < emuPerPoint) height = emuPerPoint.toDouble();
  if (width > maxWidth) {
    height = height * maxWidth / width;
    width = maxWidth.toDouble();
  }
  final cx = width.round();
  final cy = math.max(1, height.round());
  const aNs = 'http://schemas.openxmlformats.org/drawingml/2006/main';
  const picNs = 'http://schemas.openxmlformats.org/drawingml/2006/picture';
  return '<w:p><w:r><w:drawing>'
      '<wp:inline distT="0" distB="0" distL="0" distR="0">'
      '<wp:extent cx="$cx" cy="$cy"/>'
      '<wp:docPr id="$number" name="Immagine $number"/>'
      '<wp:cNvGraphicFramePr>'
      '<a:graphicFrameLocks xmlns:a="$aNs" noChangeAspect="1"/>'
      '</wp:cNvGraphicFramePr>'
      '<a:graphic xmlns:a="$aNs">'
      '<a:graphicData uri="$picNs">'
      '<pic:pic xmlns:pic="$picNs">'
      '<pic:nvPicPr><pic:cNvPr id="$number" name="image$number.${image.extension}"/>'
      '<pic:cNvPicPr/></pic:nvPicPr>'
      '<pic:blipFill><a:blip r:embed="rId$number"/>'
      '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
      '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
      '</pic:pic></a:graphicData></a:graphic>'
      '</wp:inline></w:drawing></w:r></w:p>';
}

/// Scrive il file Word (.docx) degli [elements] (paragrafi, tabelle e
/// immagini). Un .docx è un file zip con tre parti obbligatorie: i tipi, il
/// collegamento al documento e il documento stesso; con delle immagini ci
/// sono anche i file in `word/media` e i loro collegamenti.
Uint8List buildDocx(List<DocxElement> elements) {
  const ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"';
  const header = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
  final images = <DocxImage>[];
  String elementXml(DocxElement element) {
    switch (element) {
      case DocxParagraph p:
        return docxParagraphXml(p);
      case DocxTable t:
        return docxTableXml(t);
      case DocxImage i:
        images.add(i);
        return docxImageXml(i, number: images.length);
    }
  }

  final body = elements.isEmpty ? '<w:p/>' : elements.map(elementXml).join();
  final document = '$header<w:document $ns><w:body>$body'
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" '
      'w:header="709" w:footer="709" w:gutter="0"/></w:sectPr>'
      '</w:body></w:document>';
  final imageTypes = <String>{for (final i in images) i.extension};
  final contentTypes = '$header<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '${imageTypes.map((e) => '<Default Extension="$e" ContentType="image/$e"/>').join()}'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>';
  const rels = '$header<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';
  final archive = Archive()
    ..addFile(_zipEntry('[Content_Types].xml', contentTypes))
    ..addFile(_zipEntry('_rels/.rels', rels))
    ..addFile(_zipEntry('word/document.xml', document));
  if (images.isNotEmpty) {
    final links = StringBuffer();
    for (var n = 1; n <= images.length; n++) {
      final image = images[n - 1];
      links.write('<Relationship Id="rId$n" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
          'Target="media/image$n.${image.extension}"/>');
      archive.addFile(
          ArchiveFile.bytes('word/media/image$n.${image.extension}', image.bytes));
    }
    archive.addFile(_zipEntry(
        'word/_rels/document.xml.rels',
        '$header<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '$links</Relationships>'));
  }
  return ZipEncoder().encodeBytes(archive);
}

ArchiveFile _zipEntry(String name, String content) =>
    ArchiveFile.bytes(name, Uint8List.fromList(utf8.encode(content)));

/// Il risultato di [pdfToDocx]: il file Word, i paragrafi che contiene e le
/// pagine (da 0) che non si sono riuscite a leggere.
typedef DocxResult = ({Uint8List bytes, int paragraphs, List<int> failedPages});

/// Ricostruisce i paragrafi di ogni pagina di [document] con il motore
/// ([PdfTextExtractor.reflowPage]) e ne fa un file Word, con le tabelle
/// ([findPageTables]) e le immagini ([docxImageFromReflow]); le pagine di sola
/// immagine (scansioni) restano senza immagini. Una pagina che non si legge
/// viene saltata e riportata in `failedPages`.
/// [onPage] riceve la pagina che sta per essere letta (da 0) e il numero di
/// pagine; tra una pagina e l'altra l'interfaccia ha un turno.
Future<DocxResult> pdfToDocx(
  PdfDocument document, {
  void Function(int page, int pageCount)? onPage,
}) async {
  final count = document.pageCount;
  final elements = <DocxElement>[];
  final failed = <int>[];
  var withText = 0;
  for (var i = 0; i < count; i++) {
    onPage?.call(i, count);
    try {
      final reflow = PdfTextExtractor.reflowPage(document, i);
      final blocks = reflow.blocks;
      // Una pagina di sola immagine è una scansione: niente immagini, così
      // l'app propone l'OCR.
      final images = <({PdfRect bounds, DocxImage image})>[];
      if (blocks.any((b) => b.text.trim().isNotEmpty)) {
        for (final item in reflow.images) {
          try {
            final image = docxImageFromReflow(document, item);
            if (image != null) images.add((bounds: item.bounds, image: image));
          } catch (_) {
            // Un'immagine che non si legge si salta; il resto della pagina va.
          }
        }
      }
      var tables = const <PageTable>[];
      try {
        tables = findPageTables(PdfTextExtractor.extract(document, i).runs);
      } catch (_) {
        // Senza tabelle il testo si porta lo stesso, come paragrafi.
      }
      final page =
          docxPageElements(blocks, tables, images: images, pageBreak: i > 0);
      elements.addAll(page);
      for (final e in page) {
        if (e is DocxTable || (e is DocxParagraph && e.text.isNotEmpty)) {
          withText++;
        }
      }
      // Una pagina senza testo tiene comunque il suo posto nel file Word.
      if (page.isEmpty && i > 0) {
        elements.add(const DocxParagraph('', pageBreakBefore: true));
      }
    } catch (_) {
      failed.add(i);
      if (i > 0) elements.add(const DocxParagraph('', pageBreakBefore: true));
    }
    await Future<void>.delayed(Duration.zero);
  }
  return (
    bytes: buildDocx(elements),
    paragraphs: withText,
    failedPages: failed,
  );
}

/// Gli elementi Word di una pagina: i paragrafi dei [blocks] (in ordine di
/// lettura), le [tables] e le [images] (con la zona che occupano nella
/// pagina). I blocchi di testo dentro una tabella si tolgono (il loro testo
/// sta già nelle celle). Ogni tabella o immagine va prima del primo blocco
/// rimasto che sta sotto di lei e si sovrappone in orizzontale, o in fondo se
/// non c'è. Con [pageBreak] il primo elemento comincia su una pagina nuova.
List<DocxElement> docxPageElements(
  List<PdfReflowBlock> blocks,
  List<PageTable> tables, {
  List<({PdfRect bounds, DocxImage image})> images = const [],
  bool pageBreak = false,
}) {
  bool inside(PdfRect b, PdfRect zone) =>
      zone.contains((b.left + b.right) / 2, (b.top + b.bottom) / 2);
  final text = <PdfReflowBlock>[
    for (final b in blocks)
      if (b.text.trim().isNotEmpty &&
          !tables.any((t) => inside(b.bounds, t.zone)))
        b,
  ];
  // Tabelle e immagini, ognuna con la zona e il modo di scriverla; `first` è
  // vero se è il primo elemento della pagina e deve aprire una pagina nuova.
  final anchored = <({PdfRect zone, List<DocxElement> Function(bool first) make})>[
    for (final t in tables)
      (
        zone: t.zone,
        make: (first) => [DocxTable(t.grid, pageBreakBefore: first)],
      ),
    for (final entry in images)
      (
        zone: entry.bounds,
        make: (first) => [
              // Una pagina nuova sta in un paragrafo vuoto prima dell'immagine.
              if (first) const DocxParagraph('', pageBreakBefore: true),
              entry.image,
            ],
      ),
  ]..sort((a, b) => b.zone.top.compareTo(a.zone.top));
  final before = <int, List<int>>{};
  for (var n = 0; n < anchored.length; n++) {
    final zone = anchored[n].zone;
    var at = text.length;
    for (var k = 0; k < text.length; k++) {
      final b = text[k].bounds;
      final overlap = math.min(b.right, zone.right) - math.max(b.left, zone.left);
      if (b.top <= zone.top && overlap > 0) {
        at = k;
        break;
      }
    }
    (before[at] ??= []).add(n);
  }
  final out = <DocxElement>[];
  void addAnchored(int at) {
    for (final n in before[at] ?? const <int>[]) {
      out.addAll(anchored[n].make(pageBreak && out.isEmpty));
    }
  }

  for (var k = 0; k < text.length; k++) {
    addAnchored(k);
    final b = text[k];
    out.add(DocxParagraph(b.text.trim(),
        fontSize: b.fontSize,
        isListItem: b.isListItem,
        pageBreakBefore: pageBreak && out.isEmpty,
        bold: b.bold,
        italic: b.italic,
        color: b.color));
  }
  addAnchored(text.length);
  return out;
}

/// Le dimensioni e i canali di un JPEG, letti dal primo segmento SOF (solo
/// baseline e progressivo, gli unici che Word apre); null se non è un JPEG di
/// quei tipi.
({int width, int height, int components})? jpegInfo(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
  var i = 2;
  while (i + 9 < b.length) {
    if (b[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = b[i + 1];
    if (marker == 0xFF) {
      i++;
      continue;
    }
    if (marker == 0x00 ||
        marker == 0x01 ||
        marker == 0xD8 ||
        (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
      return (
        height: (b[i + 5] << 8) | b[i + 6],
        width: (b[i + 7] << 8) | b[i + 8],
        components: b[i + 9],
      );
    }
    if (marker == 0xDA) return null; // i dati, senza aver visto il SOF
    i += 2 + ((b[i + 2] << 8) | b[i + 3]);
  }
  return null;
}

/// Le immagini più grandi di così (in pixel) non si portano: decodificarle
/// occuperebbe troppa memoria.
const int _docxMaxImagePixels = 12000000;

/// L'immagine [item] di una pagina pronta per il file Word, o null se non si
/// porta (un'immagine minuscola, una maschera, una che non si decodifica).
///
/// Un JPEG a un solo filtro, in grigio o RGB, senza maschera né `/Decode`,
/// passa com'è. Tutto il resto si decodifica con il motore e si riscrive in
/// PNG, con la trasparenza appoggiata sul bianco.
DocxImage? docxImageFromReflow(PdfDocument document, PdfReflowImage item) {
  final request = item.request;
  if (request.isStencil || request.isLuminosityMask) return null;
  final widthPt = item.bounds.width;
  final heightPt = item.bounds.height;
  if (!(widthPt >= 2) || !(heightPt >= 2)) return null;
  final cos = document.cos;
  final stream = request.stream;
  final dict = stream.dictionary;
  final filters = pdfImageFilters(cos, dict);
  final plain = !dict.containsKey('SMask') &&
      !dict.containsKey('Mask') &&
      !dict.containsKey('Decode');
  if (plain && filters.length == 1 && filters.first == 'DCTDecode') {
    final bytes = cos.decodeStreamData(stream, stopBeforeFilter: 'DCTDecode');
    final info = jpegInfo(bytes);
    if (info != null && (info.components == 1 || info.components == 3)) {
      return DocxImage(bytes, 'jpeg', widthPt, heightPt);
    }
  }
  final PdfDecodedPixels? pixels = decodePdfImage(cos, stream);
  if (pixels == null || pixels.width < 1 || pixels.height < 1) return null;
  if (pixels.width * pixels.height > _docxMaxImagePixels) return null;
  return DocxImage(_pngOfPixels(pixels), 'png', widthPt, heightPt);
}

/// Un PNG a colori dai pixel RGBA (moltiplicati per l'alfa) di [pixels],
/// appoggiati sul bianco.
Uint8List _pngOfPixels(PdfDecodedPixels pixels) {
  final rgba = pixels.rgba;
  final rgb = Uint8List(pixels.width * pixels.height * 3);
  for (var i = 0, o = 0; i + 3 < rgba.length && o + 2 < rgb.length; i += 4, o += 3) {
    final white = 255 - rgba[i + 3];
    rgb[o] = math.min(255, rgba[i] + white);
    rgb[o + 1] = math.min(255, rgba[i + 1] + white);
    rgb[o + 2] = math.min(255, rgba[i + 2] + white);
  }
  final image = img.Image.fromBytes(
    width: pixels.width,
    height: pixels.height,
    bytes: rgb.buffer,
    numChannels: 3,
  );
  return Uint8List.fromList(img.encodePng(image));
}

// --- PDF in Excel (.xlsx) ----------------------------------------------------
//
// Documento intero: le righe si trovano dalla posizione verticale del testo,
// le colonne dagli spazi larghi tra le parole, e i numeri diventano numeri
// veri nelle celle. Una scheda (foglio) per ogni pagina che ha del testo.
// Una pagina che è quasi tutta tabella si legge a colonne; una pagina di
// testo ([pageSheetRows]) va in una colonna sola, con le eventuali tabelle
// al loro posto. Limiti: una cella che si estende su più colonne (un titolo
// largo dentro una riga di più celle) può unire le colonne; niente colori o
// bordi. I numeri hanno il formato giusto ([parseSpreadsheetValue]):
// percentuali, valute (€, $, £) e date (gg/mm/aaaa, aaaa-mm-gg) diventano
// numeri veri, con lo stile in `xl/styles.xml`.

/// Una cella trovata sulla pagina, prima di sapere in che colonna va. [left] e
/// [right] sono in punti della pagina.
class PageCell {
  const PageCell(this.left, this.right, this.text,
      {this.top = 0, this.bottom = 0});

  final double left;
  final double right;
  final String text;

  /// Bordo alto e basso della cella, in punti della pagina (la y cresce verso
  /// l'alto). 0 se non si conosce.
  final double top;
  final double bottom;
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
    var top = row.first.top;
    var bottom = row.first.bottom;
    for (final p in row.skip(1)) {
      final gap = p.left - right;
      final em = math.min(height, p.height);
      if (gap > em) {
        cells.add(PageCell(left, right, text, top: top, bottom: bottom));
        text = p.text;
        left = p.left;
        right = p.right;
        height = p.height;
        top = p.top;
        bottom = p.bottom;
      } else {
        text = gap > 0.15 * em ? '$text ${p.text}' : '$text${p.text}';
        right = math.max(right, p.right);
        height = p.height;
        top = math.max(top, p.top);
        bottom = math.min(bottom, p.bottom);
      }
    }
    cells.add(PageCell(left, right, text, top: top, bottom: bottom));
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

/// Una tabella trovata sulla pagina: la [zone] che occupa (nello spazio della
/// pagina) e la [grid] di testo, righe per colonne.
class PageTable {
  const PageTable(this.zone, this.grid);

  final PdfRect zone;
  final List<List<String>> grid;
}

/// Le tabelle di una pagina. Una tabella è un gruppo di almeno due righe di
/// fila con almeno due celle ciascuna, dove le colonne sono coerenti (non più
/// intervalli delle celle della riga più larga, più uno) e il testo delle
/// celle è breve (in media al massimo 40 caratteri: due colonne di prosa non
/// sono una tabella). Le righe con una cella sola chiudono il gruppo.
List<PageTable> findPageTables(Iterable<PdfExtractedRun> runs) {
  final all = runs.toList();
  final tables = <PageTable>[];
  var group = <List<PageCell>>[];
  void flush() {
    if (group.length >= 2) {
      final table = _tableOf(all, group);
      if (table != null) tables.add(table);
    }
    group = <List<PageCell>>[];
  }

  for (final row in pageCellRows(all)) {
    if (row.length >= 2) {
      group.add(row);
    } else {
      flush();
    }
  }
  flush();
  return tables;
}

PageTable? _tableOf(List<PdfExtractedRun> runs, List<List<PageCell>> rows) {
  final cells = [for (final r in rows) ...r];
  final widest = rows.fold<int>(0, (m, r) => math.max(m, r.length));
  if (columnSpans(rows).length > widest + 1) return null;
  final characters = cells.fold<int>(0, (sum, c) => sum + c.text.length);
  if (characters / cells.length > 40) return null;
  final zone = PdfRect(
    cells.map((c) => c.left).reduce(math.min) - 0.5,
    cells.map((c) => c.bottom).reduce(math.min) - 0.5,
    cells.map((c) => c.right).reduce(math.max) + 0.5,
    cells.map((c) => c.top).reduce(math.max) + 0.5,
  );
  final grid = pageGrid(runs, zone: zone);
  if (grid.length < 2) return null;
  return PageTable(zone, grid);
}

/// Sotto questa quota di righe con almeno due celle una pagina non è una
/// tabella (vedi [pageSheetRows]).
const double _sheetTableShare = 0.4;

/// Le righe del foglio di una pagina intera. Se almeno il 40% delle righe ha
/// due o più celle la pagina è una tabella e vale [pageGrid]. Altrimenti è
/// una pagina di testo: ogni riga è un paragrafo in colonna A (così le parole
/// non finiscono sparpagliate in colonne a caso), tranne le tabelle trovate
/// ([findPageTables]), che stanno nel foglio a colonne, nel punto della
/// pagina in cui si trovano. Vuota se non c'è testo.
List<List<String>> pageSheetRows(Iterable<PdfExtractedRun> runs) {
  final all = runs.toList();
  final rows = pageCellRows(all);
  if (rows.isEmpty) return const [];
  final multi = rows.where((r) => r.length >= 2).length;
  if (multi >= _sheetTableShare * rows.length) return pageGrid(all);

  final tables = findPageTables(all);
  final emitted = <PageTable>{};
  final out = <List<String>>[];
  for (final row in rows) {
    final first = row.first;
    final y = (first.top + first.bottom) / 2;
    PageTable? table;
    for (final t in tables) {
      if (t.zone.contains((first.left + first.right) / 2, y)) {
        table = t;
        break;
      }
    }
    if (table == null) {
      out.add([row.map((c) => c.text).join(' ')]);
    } else if (emitted.add(table)) {
      out.addAll(table.grid);
    }
  }
  return out;
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

/// Come si mostra una cella numerica nel file Excel.
enum SheetFormat {
  /// Numero normale (nessuno stile).
  general,

  /// Percentuale intera: `12%`.
  percent,

  /// Percentuale con decimali: `12,50%`.
  percentDecimals,

  /// Valuta in euro.
  euro,

  /// Valuta in dollari.
  dollar,

  /// Valuta in sterline.
  pound,

  /// Data breve, nel formato dell'Excel di chi apre il file (gg/mm/aaaa).
  dateShort,

  /// Data aaaa-mm-gg.
  dateIso,
}

/// Il valore di una cella numerica e il suo [SheetFormat].
typedef SheetValue = ({num value, SheetFormat format});

/// Il numero seriale di Excel di una data, o null se non esiste (31 febbraio)
/// o è prima del 1° marzo 1900 (l'Excel di quegli anni conta un 29 febbraio
/// 1900 che non c'è).
int? _excelSerial(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || year < 1900 || year > 9999) {
    return null;
  }
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  final serial = date.difference(DateTime.utc(1899, 12, 30)).inDays;
  return serial >= 61 ? serial : null;
}

/// Ciò che c'è scritto in [raw] come valore di una cella, con il formato, o
/// null se è testo. Oltre ai numeri di [parseSpreadsheetNumber] capisce:
///  * le percentuali (`12%`, `12,5 %`): il valore è la frazione (0,125);
///  * le valute (`€ 12,50`, `12,50 €`, `$9.99`, `£3`): il formato mostra il
///    simbolo;
///  * le date `gg/mm/aaaa` e `aaaa-mm-gg`: il valore è il numero seriale di
///    Excel. Una data che non esiste resta testo.
/// Gli zeri iniziali (`007`, i CAP, i telefoni) restano testo.
SheetValue? parseSpreadsheetValue(String raw) {
  final t = raw.trim();
  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(t);
  if (slash != null) {
    final serial = _excelSerial(
        int.parse(slash[3]!), int.parse(slash[2]!), int.parse(slash[1]!));
    return serial == null
        ? null
        : (value: serial, format: SheetFormat.dateShort);
  }
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(t);
  if (iso != null) {
    final serial = _excelSerial(
        int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
    return serial == null
        ? null
        : (value: serial, format: SheetFormat.dateIso);
  }
  final percent = RegExp(r'^(.*\S)\s*%$').firstMatch(t);
  if (percent != null) {
    final inner = parseSpreadsheetNumber(percent[1]!);
    if (inner == null) return null;
    return (
      // Arrotondato, perché 33,3 / 100 non diventi 0,33299999999999996.
      value: double.parse((inner / 100).toStringAsFixed(12)),
      format: inner == inner.truncate()
          ? SheetFormat.percent
          : SheetFormat.percentDecimals,
    );
  }
  final number = parseSpreadsheetNumber(t);
  if (number == null) return null;
  final format = t.contains('€')
      ? SheetFormat.euro
      : t.contains(r'$')
          ? SheetFormat.dollar
          : t.contains('£')
              ? SheetFormat.pound
              : SheetFormat.general;
  return (value: number, format: format);
}

/// Il codice di formato di Excel di [format] e il suo numero (i primi 163
/// sono di Excel: 9 è `0%`, 10 è `0.00%`, 14 è la data breve), o null per
/// [SheetFormat.general].
({int id, String? code})? _xlsxNumberFormat(SheetFormat format) =>
    switch (format) {
      SheetFormat.general => null,
      SheetFormat.percent => (id: 9, code: null),
      SheetFormat.percentDecimals => (id: 10, code: null),
      SheetFormat.dateShort => (id: 14, code: null),
      SheetFormat.euro => (id: 164, code: '#,##0.00 "€"'),
      SheetFormat.dollar => (id: 165, code: '"\$"#,##0.00'),
      SheetFormat.pound => (id: 166, code: '"£"#,##0.00'),
      SheetFormat.dateIso => (id: 167, code: r'yyyy\-mm\-dd'),
    };

/// Gli stili delle celle di un file Excel (`xl/styles.xml`). Lo stile 0 è
/// quello normale; ogni formato usato ne prende uno, nell'ordine in cui
/// compare ([styleFor]).
class XlsxStyles {
  final List<SheetFormat> _formats = [SheetFormat.general];

  /// Il numero di stile (`s="N"`) per [format]; 0 per [SheetFormat.general].
  int styleFor(SheetFormat format) {
    final at = _formats.indexOf(format);
    if (at >= 0) return at;
    _formats.add(format);
    return _formats.length - 1;
  }

  /// `xl/styles.xml`.
  String toXml() {
    final codes = StringBuffer();
    var codeCount = 0;
    final xfs = StringBuffer();
    for (final format in _formats) {
      final f = _xlsxNumberFormat(format);
      if (f == null) {
        xfs.write('<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>');
        continue;
      }
      final code = f.code;
      if (code != null) {
        codeCount++;
        codes.write('<numFmt numFmtId="${f.id}" formatCode="${xmlSafeText(code).replaceAll('"', '&quot;')}"/>');
      }
      xfs.write('<xf numFmtId="${f.id}" fontId="0" fillId="0" borderId="0" '
          'xfId="0" applyNumberFormat="1"/>');
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '${codeCount == 0 ? '' : '<numFmts count="$codeCount">$codes</numFmts>'}'
        '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
        '<fills count="2"><fill><patternFill patternType="none"/></fill>'
        '<fill><patternFill patternType="gray125"/></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="${_formats.length}">$xfs</cellXfs>'
        '</styleSheet>';
  }
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
/// numeriche (con lo stile di [styles] se hanno un formato: percentuale,
/// valuta, data), larghezza di colonna secondo il contenuto.
String xlsxSheetXml(XlsxSheet sheet, {XlsxStyles? styles}) {
  styles ??= XlsxStyles();
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
      final number = parseSpreadsheetValue(text);
      if (number == null) {
        cells.write('<c r="$ref" t="inlineStr"><is>'
            '<t xml:space="preserve">${xmlSafeText(text)}</t></is></c>');
      } else {
        final style = styles.styleFor(number.format);
        final attr = style == 0 ? '' : ' s="$style"';
        cells.write('<c r="$ref"$attr><v>${number.value}</v></c>');
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
  final styles = XlsxStyles();
  for (var i = 0; i < sheets.length; i++) {
    final n = i + 1;
    overrides.write('<Override PartName="/xl/worksheets/sheet$n.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
    sheetList.write('<sheet name="${xmlSafeText(sheets[i].name)}" '
        'sheetId="$n" r:id="rId$n"/>');
    sheetRels.write('<Relationship Id="rId$n" Type="$relType/worksheet" '
        'Target="worksheets/sheet$n.xml"/>');
  }
  sheetRels.write('<Relationship Id="rId${sheets.length + 1}" '
      'Type="$relType/styles" Target="styles.xml"/>');
  final contentTypes =
      '$header<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
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
    archive.addFile(_zipEntry('xl/worksheets/sheet${i + 1}.xml',
        xlsxSheetXml(sheets[i], styles: styles)));
  }
  // Gli stili si scrivono per ultimi: sono quelli che i fogli hanno usato.
  archive.addFile(_zipEntry('xl/styles.xml', styles.toXml()));
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
/// ricava righe e colonne ([pageSheetRows]) e fa un file Excel con una scheda
/// per pagina che ha del testo (le altre non hanno scheda). Una pagina che non si
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
      final grid = pageSheetRows(PdfTextExtractor.extract(document, i).runs);
      if (grid.isNotEmpty) {
        sheets.add(XlsxSheet('Pagina ${i + 1}', grid));
        for (final row in grid) {
          for (final text in row) {
            if (text.trim().isEmpty) continue;
            cells++;
            if (parseSpreadsheetValue(text) != null) numbers++;
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
      if (parseSpreadsheetValue(text) != null) numbers++;
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
