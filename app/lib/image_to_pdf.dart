import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_document/pdf_document.dart';

import 'standard_sizes.dart';

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

/// [uprightPhoto] fuori dal filo dell'interfaccia.
Future<UprightPhoto> uprightPhotoAsync(Uint8List bytes) =>
    compute(uprightPhoto, bytes);

/// Posizioni iniziali di più foto su un foglio (coordinate PDF, in punti,
/// origine in basso a sinistra): una sotto l'altra, centrate, a grandezza
/// reale per la misura [sizeId]. Se non ci stanno si rimpiccioliscono tutte
/// nella stessa proporzione. La prima sta in alto.
List<PdfRect> layoutPhotosOnSheet(
  List<({int width, int height})> photos,
  String? sizeId, {
  PdfPageSize page = PdfPageSize.a4,
  double margin = 28.35,
  double gap = 28.35,
}) {
  if (photos.isEmpty) return const [];
  final widths = <double>[];
  final heights = <double>[];
  for (final p in photos) {
    final dpi = photoDpi(p.width, p.height, sizeId);
    widths.add(p.width * 72 / dpi);
    heights.add(p.height * 72 / dpi);
  }
  final availW = page.width - 2 * margin;
  final gaps = gap * (photos.length - 1);
  final availH = page.height - 2 * margin - gaps;
  final maxW = widths.reduce(math.max);
  final sumH = heights.fold<double>(0, (a, b) => a + b);
  var scale = 1.0;
  if (maxW > availW) scale = math.min(scale, availW / maxW);
  if (sumH > availH && availH > 0) scale = math.min(scale, availH / sumH);
  final contentH = sumH * scale + gaps;
  var top = page.height / 2 + contentH / 2;
  final rects = <PdfRect>[];
  for (var i = 0; i < photos.length; i++) {
    final w = widths[i] * scale;
    final h = heights[i] * scale;
    final left = (page.width - w) / 2;
    rects.add(PdfRect(left, top - h, left + w, top));
    top -= h + gap;
  }
  return rects;
}
