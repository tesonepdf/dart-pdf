import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_document/pdf_document.dart';

import 'standard_sizes.dart';

/// Valore speciale di `sizeId`: la misura si decide dalla foto.
const String kAutoPhotoSize = 'auto';

/// Riconosce la misura dalla forma della foto: una carta (identità, credito,
/// tessera sanitaria, patente: tutte 85,6 x 54 mm) ha un rapporto lati di
/// circa 1,586. Null se la forma non è riconoscibile con sicurezza.
String? detectPhotoSizeId(int width, int height) {
  if (width <= 0 || height <= 0) return null;
  final ratio = math.max(width, height) / math.min(width, height);
  if ((ratio - 85.6 / 53.98).abs() / (85.6 / 53.98) <= 0.06) return 'card_cie';
  return null;
}

const _imageExtensions = {
  'jpg',
  'jpeg',
  'jpe',
  'png',
  'bmp',
  'gif',
  'webp',
  'tif',
  'tiff',
  'heic',
  'heif',
};

/// Whether [name] is an image file the app can turn into a one-page PDF.
bool isImageFileName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return false;
  return _imageExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// Whether [bytes] start like a PDF.
bool looksLikePdf(Uint8List bytes) {
  final n = math.min(bytes.length, 1024);
  for (var i = 0; i + 4 < n; i++) {
    if (bytes[i] == 0x25 &&
        bytes[i + 1] == 0x50 &&
        bytes[i + 2] == 0x44 &&
        bytes[i + 3] == 0x46) {
      return true;
    }
  }
  return false;
}

/// The title of an opened image as a PDF name.
String imageTitleAsPdf(String name) {
  final dot = name.lastIndexOf('.');
  return '${dot > 0 ? name.substring(0, dot) : name}.pdf';
}

/// Returns [bytes] unchanged when they are a PDF; otherwise decodes them as a
/// photo or bitmap (JPEG, PNG, BMP, GIF, WebP, TIFF...) and wraps the upright
/// pixels in a one-page PDF whose page is about A4 wide.
///
/// With [sizeId] (a [StandardSize] id) the page gets that real size instead:
/// the photo fits inside it, turned to match the photo's orientation.
Uint8List imageBytesToPdf(Uint8List bytes, {String? sizeId}) {
  if (looksLikePdf(bytes)) return bytes;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('formato immagine non riconosciuto');
  }
  final upright = img.bakeOrientation(decoded);
  final jpeg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  final untouched = jpeg &&
      upright.width == decoded.width &&
      upright.height == decoded.height &&
      identical(upright, decoded);
  Uint8List source;
  if (untouched) {
    source = bytes;
  } else if (upright.hasAlpha) {
    source = Uint8List.fromList(img.encodePng(upright));
  } else {
    source = Uint8List.fromList(img.encodeJpg(upright, quality: 92));
  }
  if (sizeId == kAutoPhotoSize) {
    sizeId = detectPhotoSizeId(upright.width, upright.height);
  }
  final dpi = photoDpi(upright.width, upright.height, sizeId);
  // Con una misura reale la foto sta a grandezza naturale al centro di un
  // foglio A4 bianco, pronto per la stampa (se non ci sta, si riduce).
  PdfPageSize? page;
  var fit = PdfImageFit.contain;
  const margin = 28.35;
  if (sizeId != null && standardSizeById(sizeId) != null) {
    final w = upright.width * 72 / dpi;
    final h = upright.height * 72 / dpi;
    const portrait = PdfPageSize.a4;
    const landscape = PdfPageSize(841.89, 595.28);
    bool fits(PdfPageSize p) =>
        w <= p.width - 2 * margin && h <= p.height - 2 * margin;
    if (fits(portrait)) {
      page = portrait;
      fit = PdfImageFit.none;
    } else if (fits(landscape)) {
      page = landscape;
      fit = PdfImageFit.none;
    } else {
      page = w > h ? landscape : portrait;
    }
  }
  try {
    return PdfImageDocument.fromImageBytes([source],
        dpi: dpi, pageSize: page, fit: fit, margin: page == null ? 0 : margin);
  } catch (_) {
    // e.g. a CMYK JPEG: re-encode the decoded pixels
    final png = Uint8List.fromList(img.encodePng(upright));
    return PdfImageDocument.fromImageBytes([png],
        dpi: dpi, pageSize: page, fit: fit, margin: page == null ? 0 : margin);
  }
}

/// [imageBytesToPdf] off the UI thread.
Future<Uint8List> imageBytesToPdfAsync(Uint8List bytes, {String? sizeId}) =>
    looksLikePdf(bytes)
        ? Future.value(bytes)
        : compute((Uint8List b) => imageBytesToPdf(b, sizeId: sizeId), bytes);

/// Dpi for a [width] x [height] pixel photo: about A4 wide when [sizeId] is
/// null or unknown, otherwise so the photo fits the real size [sizeId].
double photoDpi(int width, int height, String? sizeId) {
  var size = sizeId == null ? null : standardSizeById(sizeId);
  if (size == null) return math.max(72.0, width * 72 / 595.28);
  if ((width > height) != (size.widthMm > size.heightMm) &&
      size.widthMm != size.heightMm) {
    size = size.rotated;
  }
  return math.max(size.dpiForPixelWidth(width), size.dpiForPixelHeight(height));
}

/// Una foto decodificata, dritta e pronta da incorporare in un PDF.
class UprightPhoto {
  const UprightPhoto(this.bytes, this.width, this.height);

  /// JPEG (o PNG se ha trasparenza) con l'orientamento già applicato.
  final Uint8List bytes;
  final int width;
  final int height;
}

/// Decodifica [bytes] e la rimette dritta (orientamento EXIF applicato).
UprightPhoto uprightPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('formato immagine non riconosciuto');
  }
  final upright = img.bakeOrientation(decoded);
  final data = upright.hasAlpha
      ? Uint8List.fromList(img.encodePng(upright))
      : Uint8List.fromList(img.encodeJpg(upright, quality: 92));
  return UprightPhoto(data, upright.width, upright.height);
}

/// Porta una foto già dritta ([args.bytes]) a [args.target] dpi alla misura
/// vera [args.sizeId], solo se ha più dpi: toglie pixel, non ne aggiunge mai.
UprightPhoto reducePhotoDpi(
    ({Uint8List bytes, String sizeId, double target}) args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) {
    throw const FormatException('formato immagine non riconosciuto');
  }
  var photo = decoded;
  final dpi = photoDpi(photo.width, photo.height, args.sizeId);
  if (dpi > args.target) {
    final f = args.target / dpi;
    photo = img.copyResize(
      photo,
      width: (photo.width * f).round(),
      height: (photo.height * f).round(),
      interpolation: img.Interpolation.average,
    );
  }
  final data = photo.hasAlpha
      ? Uint8List.fromList(img.encodePng(photo))
      : Uint8List.fromList(img.encodeJpg(photo, quality: 92));
  return UprightPhoto(data, photo.width, photo.height);
}

/// [reducePhotoDpi] fuori dal filo dell'interfaccia.
Future<UprightPhoto> reducePhotoDpiAsync(
        Uint8List bytes, String sizeId, double target) =>
    compute(reducePhotoDpi, (bytes: bytes, sizeId: sizeId, target: target));

/// [uprightPhoto] fuori dal filo dell'interfaccia.
Future<UprightPhoto> uprightPhotoAsync(Uint8List bytes) =>
    compute(uprightPhoto, bytes);

/// Risoluzione con cui le foto sul foglio vengono stampate: pixel / 300 =
/// pollici (una foto di 1011 pixel di larghezza è larga 85,6 mm).
const double kSheetPhotoDpi = 300;

/// Posizioni iniziali di più foto su un foglio (coordinate PDF, in punti,
/// origine in basso a sinistra). Con [dpi] la misura di ogni foto è
/// pixel / dpi; altrimenti è la misura reale per [sizeId]. Le foto stanno
/// affiancate e vanno a capo quando la riga è piena, sempre staccate tra
/// loro (mai sovrapposte); se non ci stanno si rimpiccioliscono tutte nella
/// stessa proporzione. Il blocco è centrato nel foglio.
List<PdfRect> layoutPhotosOnSheet(
  List<({int width, int height})> photos,
  String? sizeId, {
  PdfPageSize page = PdfPageSize.a4,
  double margin = 28.35,
  double gap = 28.35,
  double? dpi,
}) {
  if (photos.isEmpty) return const [];
  final widths = <double>[];
  final heights = <double>[];
  for (final p in photos) {
    final d = dpi ??
        photoDpi(
          p.width,
          p.height,
          sizeId == kAutoPhotoSize
              ? detectPhotoSizeId(p.width, p.height)
              : sizeId,
        );
    widths.add(p.width * 72 / d);
    heights.add(p.height * 72 / d);
  }
  final availW = page.width - 2 * margin;
  final availH = page.height - 2 * margin;
  var scale = 1.0;
  for (var i = 0; i < widths.length; i++) {
    scale = math.min(
        scale, math.min(availW / widths[i], availH / heights[i]));
  }

  List<List<int>> rowsFor(double s) {
    final rows = <List<int>>[];
    var row = <int>[];
    var rowW = 0.0;
    for (var i = 0; i < widths.length; i++) {
      final w = widths[i] * s;
      if (row.isNotEmpty && rowW + gap + w > availW + 0.01) {
        rows.add(row);
        row = <int>[];
        rowW = 0;
      }
      rowW += (row.isEmpty ? 0 : gap) + w;
      row.add(i);
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }

  double rowHeight(List<int> row, double s) =>
      row.map((i) => heights[i] * s).reduce(math.max);

  double totalHeight(List<List<int>> rows, double s) =>
      rows.fold<double>(0, (a, r) => a + rowHeight(r, s)) +
      gap * (rows.length - 1);

  var rows = rowsFor(scale);
  for (var n = 0; n < 80 && totalHeight(rows, scale) > availH; n++) {
    scale *= 0.95;
    rows = rowsFor(scale);
  }

  final rects = List<PdfRect>.filled(photos.length, const PdfRect(0, 0, 0, 0));
  var top = page.height / 2 + totalHeight(rows, scale) / 2;
  for (final row in rows) {
    final rowH = rowHeight(row, scale);
    var rowW = gap * (row.length - 1);
    for (final i in row) {
      rowW += widths[i] * scale;
    }
    var left = (page.width - rowW) / 2;
    for (final i in row) {
      final w = widths[i] * scale;
      final h = heights[i] * scale;
      rects[i] = PdfRect(
          left, top - (rowH + h) / 2, left + w, top - (rowH - h) / 2);
      left += w + gap;
    }
    top -= rowH + gap;
  }
  return rects;
}

String _mmText(double pt) =>
    (pt * 25.4 / 72).toStringAsFixed(1).replaceAll('.', ',');

/// Una riga del controllo misura: i mm veri della foto sul foglio e se sono
/// quelli della misura scelta ([ratio] = grandezza sul foglio / grandezza
/// vera; 1 = reale).
String photoSizeCheckLine(
    String label, double widthPt, double heightPt, double ratio) {
  final state = (ratio - 1).abs() < 0.01
      ? 'misura reale ✓'
      : 'ridotta al ${(ratio * 100).round()}%';
  return '$label: ${_mmText(widthPt)} × ${_mmText(heightPt)} mm, $state';
}

/// Il controllo misura di più foto messe sul foglio ([rects] dal layout).
/// Si fa solo quando le foto vengono inserite.
String photosOnSheetReport(
  List<({int width, int height})> photos,
  List<PdfRect> rects,
  String sizeId,
) {
  final size = standardSizeById(sizeId);
  final lines = <String>[
    if (size != null)
      'Misura scelta: ${size.name} (${_mmText(size.widthPt)} × ${_mmText(size.heightPt)} mm)',
  ];
  for (var i = 0; i < photos.length; i++) {
    final dpi = photoDpi(photos[i].width, photos[i].height, sizeId);
    final natural = photos[i].width * 72 / dpi;
    lines.add(photoSizeCheckLine('Foto ${i + 1}', rects[i].width,
        rects[i].height, natural == 0 ? 1 : rects[i].width / natural));
  }
  return lines.join('\n');
}

/// Il controllo misura di una foto aperta da sola alla misura [sizeId]
/// (come la mette [imageBytesToPdf]: al centro di un A4, ridotta se non ci sta).
String singlePhotoReport(int width, int height, String sizeId) {
  final dpi = photoDpi(width, height, sizeId);
  final w = width * 72 / dpi;
  final h = height * 72 / dpi;
  const margin = 28.35;
  const portrait = PdfPageSize.a4;
  const landscape = PdfPageSize(841.89, 595.28);
  bool fits(PdfPageSize p) =>
      w <= p.width - 2 * margin && h <= p.height - 2 * margin;
  var ratio = 1.0;
  if (!fits(portrait) && !fits(landscape)) {
    final page = w > h ? landscape : portrait;
    ratio = math.min((page.width - 2 * margin) / w,
        (page.height - 2 * margin) / h);
  }
  final size = standardSizeById(sizeId);
  return [
    if (size != null)
      'Misura scelta: ${size.name} (${_mmText(size.widthPt)} × ${_mmText(size.heightPt)} mm)',
    photoSizeCheckLine('Foto', w * ratio, h * ratio, ratio),
  ].join('\n');
}
