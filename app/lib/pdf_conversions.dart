import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart'
    show PdfReflowBlock, PdfTextExtractor;

import 'image_to_pdf.dart';

// Conversioni da e verso il PDF (punto 1: testo semplice e foto in PDF;
// punto 2: PDF in Word).
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
