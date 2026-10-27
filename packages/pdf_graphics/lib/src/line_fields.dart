import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:pdf_cos/pdf_cos.dart';
import 'package:pdf_document/pdf_document.dart';

import 'device.dart';
import 'image_pixels.dart';
import 'interpreter.dart';
import 'path.dart';
import 'recording_device.dart';
import 'render_command.dart';
import 'text_extraction.dart';

/// A ruled strip on a page where a form is meant to be filled in by hand:
/// a drawn rule, a thin filled bar, or a run of underscores/dots.
///
/// Coordinates are in page space (PDF default user space, y-up). [y] is the
/// line's midpoint height, [slope] its page-space rise per unit of x, and
/// [left]..[right] its horizontal extent.
class PdfLineField {
  const PdfLineField({
    required this.pageIndex,
    required this.left,
    required this.right,
    required this.y,
    this.slope = 0,
  });

  final int pageIndex;
  final double left;
  final double right;
  final double y;
  final double slope;

  double get width => right - left;

  double yAt(double x) => y + slope * (x - (left + right) / 2);
}

class _Chain {
  _Chain(this.x0, this.x1, int row)
      : firstRow = row,
        lastRow = row,
        sumRow = row.toDouble(),
        n = 1;
  int x0;
  int x1;
  final int firstRow;
  int lastRow;
  double sumRow;
  int n;
}

class _Seg {
  _Seg(this.left, this.right, this.y, {this.slope = 0});
  double left;
  double right;
  double y;
  double slope;

  double yAt(double x) => y + slope * (x - (left + right) / 2);
}

/// Finds the fill-in strips of a page.
class PdfLineFieldDetector {
  PdfLineFieldDetector._();

  /// Detects the strips on page [pageIndex]: vector rules and thin bars, plus
  /// runs of underscores or dots in the page text. Results are ordered top to
  /// bottom, then left to right.
  static List<PdfLineField> detect(
    PdfDocument document,
    int pageIndex, {
    double minLength = 18,
    double maxThickness = 2.5,
  }) {
    final segs = <_Seg>[];
    try {
      final device = RecordingPdfDevice();
      PdfInterpreter(
        cos: document.cos,
        device: device,
        resolveOverprint: false,
      ).drawPage(document.page(pageIndex));
      for (final request in device.imageRequests) {
        try {
          _fromImage(document, request, segs, minLength);
        } catch (_) {}
      }
      for (final command in device.commands) {
        if (command is PdfFillPathCommand) {
          _fromFill(command.path, segs, minLength, maxThickness);
        } else if (command is PdfStrokePathCommand) {
          if (command.stroke.width <= maxThickness) {
            _fromStroke(command.path, segs, minLength);
          }
        }
      }
    } catch (_) {
      // a page the interpreter cannot walk still gets its text strips
    }
    // Text strips (underscores, dots) only estimate the rule's height from the
    // line box - and an OCR layer's boxes are loose - so a drawn or scanned
    // rule at the same place always wins over its text twin.
    try {
      final text = PdfTextExtractor.extract(document, pageIndex);
      for (final match in text.findAll(r'_{3,}|\.{6,}', regex: true)) {
        for (final r in match.rects) {
          final y = r.bottom + (r.top - r.bottom) * 0.2;
          final width = r.right - r.left;
          final centerX = (r.left + r.right) / 2;
          final twin = segs.any((g) =>
              (g.yAt(centerX) - y).abs() <= 16 &&
              math.min(g.right, r.right) - math.max(g.left, r.left) >
                  width * 0.4);
          if (!twin) segs.add(_Seg(r.left, r.right, y));
        }
      }
    } catch (_) {}
    return _merge(segs, pageIndex, minLength);
  }

  /// Scanned pages: finds long, thin dark runs in the page image itself.
  /// A small global deskew lets rules on a rotated camera image join into
  /// continuous runs before their endpoints are mapped back to page space.
  static void _fromImage(PdfDocument document, PdfImageRequest request,
      List<_Seg> out, double minLength) {
    final m = request.transform;
    final imageWidth = math.sqrt(m.a * m.a + m.b * m.b);
    if (imageWidth < 100) return; // icons and logos, not a page or a band of one
    final dict = request.stream.dictionary;
    final w0 = document.cos.resolve(dict['Width']);
    final h0 = document.cos.resolve(dict['Height']);
    if (w0 is! CosInteger || h0 is! CosInteger) return;
    final sourceW = w0.value, sourceH = h0.value;
    if (sourceW <= 0 || sourceH <= 0) return;
    final decoded = _grayPixels(document, request, sourceW, sourceH);
    if (decoded == null) return;
    final w = decoded.width, sourceHeight = decoded.height;
    final deskewSlope = _estimateSkew(decoded.samples, w, sourceHeight);
    final offset = (deskewSlope.abs() * w / 2).ceil() + 2;
    final h = sourceHeight + 2 * offset;
    final samples = Uint8List(w * h)..fillRange(0, w * h, 255);
    final source = decoded.samples;
    final centerX = (w - 1) / 2;
    for (var y = 0; y < sourceHeight; y++) {
      final row = y * w;
      for (var x = 0; x < w; x++) {
        final targetY =
            (y - deskewSlope * (x - centerX)).round() + offset;
        if (targetY >= 0 && targetY < h) {
          final index = targetY * w + x;
          samples[index] = math.min(samples[index], source[row + x]).toInt();
        }
      }
    }

    final pxPerPt = w / imageWidth;
    final minRun = math.max(6, (14 * pxPerPt).round());
    final minChain = (minLength * pxPerPt).round();
    final maxRun = (w * 0.92).round();
    final maxRows = math.max(3, (5 * pxPerPt).round());

    bool dark(int x, int y) {
      return samples[y * w + x] < 185;
    }

    final open = <_Chain>[];
    final done = <_Chain>[];
    for (var y = 0; y < h; y++) {
      final runs = <(int, int)>[];
      var x = 0;
      while (x < w) {
        if (!dark(x, y)) {
          x++;
          continue;
        }
        final start = x;
        var end = x;
        var gap = 0;
        while (x < w && gap <= 1) {
          if (dark(x, y)) {
            end = x;
            gap = 0;
          } else {
            gap++;
          }
          x++;
        }
        final length = end - start + 1;
        if (length >= minRun && length <= maxRun) runs.add((start, end));
      }
      final stillOpen = <_Chain>[];
      for (final chain in open) {
        (chain.lastRow < y - 2 ? done : stillOpen).add(chain);
      }
      open
        ..clear()
        ..addAll(stillOpen);
      for (final (a, b) in runs) {
        _Chain? hit;
        for (final chain in open) {
          final overlap = math.min(b, chain.x1) - math.max(a, chain.x0);
          if (overlap > 0.5 * (b - a)) {
            hit = chain;
            break;
          }
        }
        if (hit == null) {
          open.add(_Chain(a, b, y));
        } else {
          hit.x0 = math.min(hit.x0, a);
          hit.x1 = math.max(hit.x1, b);
          hit.lastRow = y;
          hit.sumRow += y;
          hit.n++;
        }
      }
    }
    done.addAll(open);
    for (final chain in done) {
      final width = chain.x1 - chain.x0 + 1;
      if (width < minChain) continue;
      if (chain.x1 >= w - 3) continue; // the scan's own edge
      final rows = chain.lastRow - chain.firstRow + 1;
      if (rows > maxRows + 0.08 * width) continue; // a bar or a blot
      final row = chain.sumRow / chain.n + 0.5;
      if (row < 0.01 * h || row > 0.99 * h) continue;
      (double, double) toPage(double x, double deskewedY) {
        final sourceY =
            (deskewedY - offset + deskewSlope * (x - centerX))
                .clamp(0.0, sourceHeight.toDouble())
                .toDouble();
        final u = x / w;
        final v = 1 - sourceY / sourceHeight;
        return (m.e + m.a * u + m.c * v, m.f + m.b * u + m.d * v);
      }

      final start = toPage(
        chain.x0.toDouble(),
        row,
      );
      final end = toPage(
        (chain.x1 + 1).toDouble(),
        row,
      );
      final dx = end.$1 - start.$1;
      final dy = end.$2 - start.$2;
      if (dx.abs() < minLength || dy.abs() > dx.abs() * 0.25) continue;
      final left = math.min(start.$1, end.$1);
      final right = math.max(start.$1, end.$1);
      final slope = (dx < 0 ? -dy : dy) / dx.abs();
      out.add(_Seg(left, right, (start.$2 + end.$2) / 2, slope: slope));
    }
  }

  static double _estimateSkew(Uint8List samples, int width, int height) {
    final stepX = math.max(1, (width / 400).ceil());
    final stepY = math.max(1, (height / 600).ceil());
    final centerX = (width - 1) / 2;

    double score(double slope) {
      final offset = (slope.abs() * width / 2).ceil() + 2;
      final rows = Uint32List(height + 2 * offset);
      for (var y = 0; y < height; y += stepY) {
        final row = y * width;
        for (var x = 0; x < width; x += stepX) {
          if (samples[row + x] >= 185) continue;
          final deskewedY =
              (y - slope * (x - centerX)).round() + offset;
          if (deskewedY >= 0 && deskewedY < rows.length) {
            rows[deskewedY]++;
          }
        }
      }
      var result = 0.0;
      for (final count in rows) {
        result += count * count;
      }
      return result;
    }

    var bestSlope = 0.0;
    var bestScore = score(0);
    final zeroScore = bestScore;
    for (var i = -60; i <= 60; i++) {
      final candidate = i * 0.0025;
      final candidateScore = score(candidate);
      if (candidateScore > bestScore) {
        bestScore = candidateScore;
        bestSlope = candidate;
      }
    }
    final coarseSlope = bestSlope;
    for (var i = -10; i <= 10; i++) {
      final candidate = coarseSlope + i * 0.00025;
      if (candidate.abs() > 0.15) continue;
      final candidateScore = score(candidate);
      if (candidateScore > bestScore) {
        bestScore = candidateScore;
        bestSlope = candidate;
      }
    }
    return bestSlope.abs() < 0.002 || bestScore < zeroScore * 1.02
        ? 0
        : bestSlope;
  }

  /// The page image as one gray byte per pixel. Most scans are plain RGB JPEGs,
  /// which [decodePdfImagePixels] leaves to the platform codec, so those are
  /// decoded here directly.
  static ({Uint8List samples, int width, int height})? _grayPixels(
      PdfDocument document, PdfImageRequest request, int sourceW, int sourceH) {
    final targetW = math.min(sourceW, 2000);
    final targetH = math.max(1, (sourceH * targetW / sourceW).round());
    final pixels = targetW < sourceW
        ? decodePdfImagePixelsScaled(
            document.cos, request.stream, targetW, targetH)
        : decodePdfImagePixels(document.cos, request.stream);
    if (pixels != null) {
      final rgba = pixels.rgba;
      final n = pixels.width * pixels.height;
      final out = Uint8List(n);
      for (var i = 0; i < n; i++) {
        final j = i * 4;
        out[i] = rgba[j + 3] < 128
            ? 255
            : (rgba[j] + rgba[j + 1] + rgba[j + 2]) ~/ 3;
      }
      return (samples: out, width: pixels.width, height: pixels.height);
    }
    final filters = pdfImageFilters(document.cos, request.stream.dictionary);
    if (!filters.contains('DCTDecode')) return null;
    final jpeg = document.cos
        .decodeStreamData(request.stream, stopBeforeFilter: 'DCTDecode');
    final image = img.decodeJpg(jpeg);
    if (image == null) return null;
    final w = image.width, h = image.height;
    final rgb = image.getBytes(order: img.ChannelOrder.rgb);
    final out = Uint8List(w * h);
    for (var i = 0, j = 0; i < out.length; i++, j += 3) {
      out[i] = (rgb[j] + rgb[j + 1] + rgb[j + 2]) ~/ 3;
    }
    return (samples: out, width: w, height: h);
  }

  static void _fromFill(
      PdfPath path, List<_Seg> out, double minLength, double maxThickness) {
    final points = <(double, double)>[];
    var count = 0;
    for (final s in path.segments) {
      if (s is PdfMoveTo) {
        points.add((s.x, s.y));
      } else if (s is PdfLineTo) {
        points.add((s.x, s.y));
      } else if (s is PdfCubicTo) {
        return; // curves are not rules
      }
      if (++count > 8) return;
    }
    if (points.length < 2) return;
    var minX = points.first.$1, maxX = minX;
    var minY = points.first.$2, maxY = minY;
    for (final (x, y) in points) {
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    if (maxX - minX >= minLength && maxY - minY <= maxThickness) {
      out.add(_Seg(minX, maxX, (minY + maxY) / 2));
    }
  }

  static void _fromStroke(PdfPath path, List<_Seg> out, double minLength) {
    // only a plain two-point open segment is a rule; rectangles and longer
    // polylines are boxes and tables
    final segments = path.segments;
    if (segments.length != 2) return;
    final a = segments[0], b = segments[1];
    if (a is! PdfMoveTo || b is! PdfLineTo) return;
    if ((a.y - b.y).abs() > 0.6) return;
    final length = (a.x - b.x).abs();
    if (length < minLength) return;
    out.add(_Seg(math.min(a.x, b.x), math.max(a.x, b.x), (a.y + b.y) / 2));
  }

  static List<PdfLineField> _merge(
      List<_Seg> segs, int pageIndex, double minLength) {
    var current = [
      for (final s in segs) _Seg(s.left, s.right, s.y, slope: s.slope)
    ];
    var changed = true;
    while (changed) {
      changed = false;
      current.sort((p, q) {
        final dy = q.y.compareTo(p.y);
        return dy != 0 ? dy : p.left.compareTo(q.left);
      });
      final out = <_Seg>[];
      for (final s in current) {
        _Seg? hit;
        for (final t in out) {
          final overlapLeft = math.max(t.left, s.left);
          final overlapRight = math.min(t.right, s.right);
          final compareX = overlapLeft <= overlapRight
              ? (overlapLeft + overlapRight) / 2
              : (math.max(t.left, s.left) + math.min(t.right, s.right)) / 2;
          if ((t.slope - s.slope).abs() <= 0.01 &&
              (t.yAt(compareX) - s.yAt(compareX)).abs() <= 2 &&
              s.left <= t.right + 1.5 &&
              s.right >= t.left - 1.5) {
            hit = t;
            break;
          }
        }
        if (hit == null) {
          out.add(s);
        } else {
          final n = hit.right - hit.left, k = s.right - s.left;
          final left = math.min(hit.left, s.left);
          final right = math.max(hit.right, s.right);
          final center = (left + right) / 2;
          final slope = (hit.slope * n + s.slope * k) / (n + k);
          final y =
              (hit.yAt(center) * n + s.yAt(center) * k) / (n + k);
          hit.left = math.min(hit.left, s.left);
          hit.right = math.max(hit.right, s.right);
          hit.y = y;
          hit.slope = slope;
          changed = true;
        }
      }
      current = out;
    }
    final merged = current;
    final fields = [
      for (final m in merged)
        if (m.right - m.left >= minLength)
          PdfLineField(
              pageIndex: pageIndex,
              left: m.left,
              right: m.right,
              y: m.y,
              slope: m.slope),
    ];
    fields.sort((p, q) {
      final dy = q.y.compareTo(p.y);
      return dy != 0 ? dy : p.left.compareTo(q.left);
    });
    return fields;
  }
}
