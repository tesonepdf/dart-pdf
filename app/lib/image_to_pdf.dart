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
  try {
    return PdfImageDocument.fromImageBytes([source], dpi: dpi);
  } catch (_) {
    // e.g. a CMYK JPEG: re-encode the decoded pixels
    final png = Uint8List.fromList(img.encodePng(upright));
    return PdfImageDocument.fromImageBytes([png], dpi: dpi);
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
