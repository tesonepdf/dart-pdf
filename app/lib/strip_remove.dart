import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:pdf_document/pdf_document.dart';

import 'compose_sheet.dart' show regionFromSelection;

// Togliere (o allargare) una striscia verticale di una pagina: la parte a
// sinistra e quella a destra della striscia si affiancano nella stessa pagina,
// piu' stretta, e le righe restano alla stessa altezza.
// Solo logica, senza interfaccia: il selettore sta in `compose_sheet.dart`
// (`pickPageStrip`) e il collegamento al menu in `editor_screen.dart`.

/// Sotto questa larghezza (in punti) una parte non si disegna.
const double kStripMinPart = 0.5;

/// La larghezza della striscia scelta, in punti, per una pagina larga
/// [pageWidth] punti. [strip] e' in frazioni della pagina (0..1).
double stripWidthPt(double pageWidth, Rect strip) => pageWidth * strip.width;

/// La larghezza della pagina nuova, in punti: parte sinistra + [gap] + parte
/// destra. Con [gap] piu' piccolo della striscia la pagina si stringe, con
/// [gap] piu' grande si allarga.
double stripResultWidth(double pageWidth, Rect strip, double gap) {
  final from = strip.left.clamp(0.0, 1.0).toDouble();
  final to = strip.right.clamp(from, 1.0).toDouble();
  return pageWidth * from + math.max(0.0, gap) + pageWidth * (1 - to);
}

/// Il titolo della scheda con il risultato.
String stripTabTitle(String title, int page) {
  var stem = title.trim();
  if (stem.toLowerCase().endsWith('.pdf')) {
    stem = stem.substring(0, stem.length - 4).trim();
  }
  if (stem.isEmpty) stem = 'documento';
  return '$stem (pag. ${page + 1} regolata).pdf';
}

/// Una pagina nuova (un solo foglio) fatta con la pagina [page] (da 0) di
/// [source], in cui la striscia [strip] (in frazioni della pagina vista, 0..1,
/// origine in alto a sinistra; conta solo la larghezza, la striscia va su
/// tutta l'altezza) e' sostituita da uno spazio di [gap] punti.
///
/// Le due parti restano vettoriali, il testo resta selezionabile e le righe
/// stanno alla stessa altezza di prima. Lancia [FormatException] se non
/// resterebbe niente.
Uint8List removePageStrip({
  required PdfDocument source,
  required int page,
  required Rect strip,
  required double gap,
}) {
  final pdfPage = source.page(page);
  final box = pdfPage.cropBox;
  final rotation = pdfPage.rotation;
  final size = pdfRegionDisplaySize(box, rotation);
  final from = strip.left.clamp(0.0, 1.0).toDouble();
  final to = strip.right.clamp(from, 1.0).toDouble();
  final spacing = math.max(0.0, gap);
  final leftWidth = size.width * from;
  final rightWidth = size.width * (1 - to);
  final width = leftWidth + spacing + rightWidth;
  if (width < 1) {
    throw const FormatException('della pagina non resterebbe niente');
  }
  final doc = PdfDocument.open(PdfBlankDocument.create(
    pageSize: PdfPageSize(width, size.height),
    pageCount: 1,
  ));
  final editor = PdfEditor(doc);
  final imports = PdfSheetImports();
  void place(Rect part, double x) {
    editor.placePageRegion(
      imports,
      sheet: 0,
      source: source,
      sourcePage: page,
      region: regionFromSelection(part, box, rotation),
      x: x,
      y: 0,
    );
  }

  if (leftWidth >= kStripMinPart) {
    place(Rect.fromLTRB(0, 0, from, 1), 0);
  }
  if (rightWidth >= kStripMinPart) {
    place(Rect.fromLTRB(to, 0, 1, 1), leftWidth + spacing);
  }
  return editor.save();
}
