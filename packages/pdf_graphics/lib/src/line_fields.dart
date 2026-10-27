import 'dart:math' as math;

import 'package:pdf_document/pdf_document.dart';

import 'interpreter.dart';
import 'path.dart';
import 'recording_device.dart';
import 'render_command.dart';
import 'text_extraction.dart';

/// A horizontal "strip" on a page where a form is meant to be filled in by
/// hand: a drawn rule, a thin filled bar, or a run of underscores/dots.
///
/// Coordinates are in page space (PDF default user space, y-up). The text
/// belongs just above [y], spanning [left]..[right].
class PdfLineField {
  const PdfLineField({
    required this.pageIndex,
    required this.left,
    required this.right,
    required this.y,
  });

  final int pageIndex;
  final double left;
  final double right;
  final double y;

  double get width => right - left;
}

class _Seg {
  _Seg(this.left, this.right, this.y);
  double left;
  double right;
  double y;
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
    double minLength = 24,
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
    try {
      final text = PdfTextExtractor.extract(document, pageIndex);
      for (final match in text.findAll(r'_{3,}|\.{6,}', regex: true)) {
        for (final r in match.rects) {
          final y = r.bottom + (r.top - r.bottom) * 0.2;
          segs.add(_Seg(r.left, r.right, y));
        }
      }
    } catch (_) {}
    return _merge(segs, pageIndex, minLength);
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
    segs.sort((p, q) {
      final dy = q.y.compareTo(p.y);
      return dy != 0 ? dy : p.left.compareTo(q.left);
    });
    final merged = <_Seg>[];
    for (final s in segs) {
      var joined = false;
      for (final m in merged) {
        if ((m.y - s.y).abs() <= 1.5 &&
            s.left <= m.right + 6 &&
            s.right >= m.left - 6) {
          m.left = math.min(m.left, s.left);
          m.right = math.max(m.right, s.right);
          joined = true;
          break;
        }
      }
      if (!joined) merged.add(_Seg(s.left, s.right, s.y));
    }
    final fields = [
      for (final m in merged)
        if (m.right - m.left >= minLength)
          PdfLineField(
              pageIndex: pageIndex, left: m.left, right: m.right, y: m.y),
    ];
    fields.sort((p, q) {
      final dy = q.y.compareTo(p.y);
      return dy != 0 ? dy : p.left.compareTo(q.left);
    });
    return fields;
  }
}
