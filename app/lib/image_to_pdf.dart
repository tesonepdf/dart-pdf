import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_document/pdf_document.dart';

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
Uint8List imageBytesToPdf(Uint8List bytes) {
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
  final dpi = math.max(72.0, upright.width * 72 / 595.28);
  try {
    return PdfImageDocument.fromImageBytes([source], dpi: dpi);
  } catch (_) {
    // e.g. a CMYK JPEG: re-encode the decoded pixels
    final png = Uint8List.fromList(img.encodePng(upright));
    return PdfImageDocument.fromImageBytes([png], dpi: dpi);
  }
}

/// [imageBytesToPdf] off the UI thread.
Future<Uint8List> imageBytesToPdfAsync(Uint8List bytes) =>
    looksLikePdf(bytes) ? Future.value(bytes) : compute(imageBytesToPdf, bytes);
