import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart' show PdfTextExtractor;

import 'image_to_pdf.dart';

// Conversioni da e verso il PDF (punto 1: testo semplice e foto in PDF).
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
