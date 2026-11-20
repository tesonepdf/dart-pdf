import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:pdf_document/pdf_document.dart';

import 'compose_sheet.dart' show regionFromSelection;

// Togliere (o allargare) una striscia di una pagina. Verticale: la parte a
// sinistra e quella a destra si affiancano nella stessa pagina, piu' stretta, e
// le righe restano alla stessa altezza. Orizzontale: la parte sopra e quella
// sotto si impilano nella stessa pagina, piu' bassa, e le colonne restano alla
// stessa larghezza.
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

/// Lo spessore della striscia scelta, in punti, per una pagina larga
/// [pageWidth] e alta [pageHeight] punti: la larghezza se la striscia e'
/// verticale, l'altezza se e' [horizontal].
double stripThicknessPt(
  double pageWidth,
  double pageHeight,
  Rect strip, {
  bool horizontal = false,
}) =>
    horizontal ? pageHeight * strip.height : pageWidth * strip.width;

/// Gira la selezione [sel] di un quarto di giro attorno al suo centro, come
/// farebbe sulla pagina vera: [pageAspect] e' larghezza / altezza della
/// pagina, perche' le frazioni (0..1) non sono quadrate. Il risultato resta
/// dentro la pagina: se non ci sta, si accorcia; se esce dal bordo, si sposta.
Rect rotateStripSelection(Rect sel, double pageAspect) {
  final aspect = pageAspect <= 0 ? 1.0 : pageAspect;
  var w = sel.height / aspect;
  var h = sel.width * aspect;
  w = w.clamp(0.0, 1.0).toDouble();
  h = h.clamp(0.0, 1.0).toDouble();
  final left = (sel.center.dx - w / 2).clamp(0.0, 1.0 - w).toDouble();
  final top = (sel.center.dy - h / 2).clamp(0.0, 1.0 - h).toDouble();
  return Rect.fromLTWH(left, top, w, h);
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
/// origine in alto a sinistra) e' sostituita da uno spazio di [gap] punti.
/// Con [horizontal] falso conta solo la larghezza della striscia (va su tutta
/// l'altezza); con [horizontal] vero conta solo l'altezza (va su tutta la
/// larghezza) e le parti sopra e sotto si impilano.
///
/// Le due parti restano vettoriali, il testo resta selezionabile e le righe
/// (o le colonne) stanno dove stavano. Lancia [FormatException] se non
/// resterebbe niente.
Uint8List removePageStrip({
  required PdfDocument source,
  required int page,
  required Rect strip,
  required double gap,
  bool horizontal = false,
}) {
  if (horizontal) {
    return _removeHorizontalStrip(
        source: source, page: page, strip: strip, gap: gap);
  }
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

Uint8List _removeHorizontalStrip({
  required PdfDocument source,
  required int page,
  required Rect strip,
  required double gap,
}) {
  final pdfPage = source.page(page);
  final box = pdfPage.cropBox;
  final rotation = pdfPage.rotation;
  final size = pdfRegionDisplaySize(box, rotation);
  final from = strip.top.clamp(0.0, 1.0).toDouble();
  final to = strip.bottom.clamp(from, 1.0).toDouble();
  final spacing = math.max(0.0, gap);
  final topHeight = size.height * from;
  final bottomHeight = size.height * (1 - to);
  final height = topHeight + spacing + bottomHeight;
  if (height < 1) {
    throw const FormatException('della pagina non resterebbe niente');
  }
  final doc = PdfDocument.open(PdfBlankDocument.create(
    pageSize: PdfPageSize(size.width, height),
    pageCount: 1,
  ));
  final editor = PdfEditor(doc);
  final imports = PdfSheetImports();
  // L'origine di (x, y) e' in basso a sinistra, come nel PDF: la parte sotto
  // sta in fondo, quella sopra sale di altezza sotto + spazio.
  void place(Rect part, double y) {
    editor.placePageRegion(
      imports,
      sheet: 0,
      source: source,
      sourcePage: page,
      region: regionFromSelection(part, box, rotation),
      x: 0,
      y: y,
    );
  }

  if (bottomHeight >= kStripMinPart) {
    place(Rect.fromLTRB(0, to, 1, 1), 0);
  }
  if (topHeight >= kStripMinPart) {
    place(Rect.fromLTRB(0, 0, 1, from), bottomHeight + spacing);
  }
  return editor.save();
}
