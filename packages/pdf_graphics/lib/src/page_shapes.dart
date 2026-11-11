import 'dart:math' as math;

import 'package:pdf_document/pdf_document.dart';

import 'color.dart';
import 'device.dart';
import 'interpreter.dart';
import 'mesh.dart';
import 'path.dart';
import 'render_command.dart';
import 'shading.dart';

/// A filled axis-aligned rectangle on a page: a cell or table background.
class PdfFilledRect {
  const PdfFilledRect(this.bounds, this.color);

  /// Page space (y up).
  final PdfRect bounds;

  /// 0xRRGGBB, already blended over white when the fill was translucent.
  final int color;
}

/// A straight horizontal or vertical rule on a page: a table border, drawn
/// either as a stroked line or as a thin filled rectangle.
class PdfRuleLine {
  const PdfRuleLine(this.bounds);

  /// Page space (y up). One of width or height is (near) zero.
  final PdfRect bounds;

  bool get isHorizontal => bounds.width >= bounds.height;
}

/// The background fills and border rules of a page, in painting order.
///
/// Only what a table needs is kept: rectangle fills (white ones are dropped,
/// they are the paper), and horizontal or vertical lines. Curves, gradients,
/// images, tiling patterns and clips are ignored.
class PdfPageShapes {
  const PdfPageShapes(this.fills, this.lines);

  static const empty = PdfPageShapes([], []);

  final List<PdfFilledRect> fills;
  final List<PdfRuleLine> lines;

  /// Interprets page [pageIndex] of [document] and collects its shapes.
  static PdfPageShapes extract(PdfDocument document, int pageIndex) {
    final device = _ShapeDevice();
    PdfInterpreter(
      cos: document.cos,
      device: device,
      resolveOverprint: false,
    ).drawPage(document.page(pageIndex));
    return PdfPageShapes(device.fills, device.lines);
  }
}

int _rgbOnWhite(PdfColor c, double alpha) {
  final a = alpha.isFinite ? alpha.clamp(0.0, 1.0) : 1.0;
  int channel(double v) {
    final x = v.isFinite ? v.clamp(0.0, 1.0) : 0.0;
    return ((x * a + (1 - a)) * 255).round();
  }

  return (channel(c.red) << 16) | (channel(c.green) << 8) | channel(c.blue);
}

class _ShapeDevice implements PdfDevice, PdfTiledCellSink {
  static const _limit = 50000;
  static const _white = 0xFFFFFF;

  final List<PdfFilledRect> fills = [];
  final List<PdfRuleLine> lines = [];

  void _addLine(double x1, double y1, double x2, double y2) {
    if (lines.length >= _limit) return;
    const eps = 1e-3;
    final horizontal = (y1 - y2).abs() <= eps;
    final vertical = (x1 - x2).abs() <= eps;
    if (!horizontal && !vertical) return;
    final length = horizontal ? (x1 - x2).abs() : (y1 - y2).abs();
    if (length < 3) return;
    lines.add(PdfRuleLine(PdfRect(
        math.min(x1, x2), math.min(y1, y2), math.max(x1, x2), math.max(y1, y2))));
  }

  @override
  void fillPath(PdfPath path, PdfColor color, PdfFillRule rule, double a) {
    if (a < 0.05) return;
    final rects = pdfPathAxisAlignedRects(path);
    if (rects == null) return;
    final rgb = _rgbOnWhite(color, a);
    if (rgb == _white) return;
    for (var i = 0; i + 3 < rects.length; i += 4) {
      final l = rects[i], b = rects[i + 1], r = rects[i + 2], t = rects[i + 3];
      final w = r - l, h = t - b;
      if (math.min(w, h) < 1.5) {
        // A table border drawn as a thin fill.
        if (w >= h) {
          _addLine(l, (b + t) / 2, r, (b + t) / 2);
        } else {
          _addLine((l + r) / 2, b, (l + r) / 2, t);
        }
      } else if (fills.length < _limit) {
        fills.add(PdfFilledRect(PdfRect(l, b, r, t), rgb));
      }
    }
  }

  @override
  void strokePath(PdfPath path, PdfColor color, PdfStroke stroke, double a) {
    if (a < 0.05 || _rgbOnWhite(color, a) == _white) return;
    final cursor = path.cursor();
    var hasCurrent = false;
    var sx = 0.0, sy = 0.0, cx = 0.0, cy = 0.0;
    while (cursor.moveNext()) {
      switch (cursor.verb) {
        case PdfPathVerb.moveTo:
          sx = cx = cursor.x1;
          sy = cy = cursor.y1;
          hasCurrent = true;
        case PdfPathVerb.lineTo:
          if (hasCurrent) _addLine(cx, cy, cursor.x1, cursor.y1);
          cx = cursor.x1;
          cy = cursor.y1;
          hasCurrent = true;
        case PdfPathVerb.cubicTo:
          cx = cursor.x3;
          cy = cursor.y3;
        case PdfPathVerb.close:
          if (hasCurrent) _addLine(cx, cy, sx, sy);
          cx = sx;
          cy = sy;
      }
    }
  }

  // Patterns and Type3 glyph cells hold no table shapes worth the cost.
  @override
  void drawTiledCell(PdfDrawTiledCellCommand command) {}

  @override
  void drawText(PdfTextRun run) {}
  @override
  void save() {}
  @override
  void restore() {}
  @override
  void fillPathGradient(
      PdfPath path, PdfFillRule rule, PdfGradient gradient, double a) {}
  @override
  void fillMesh(PdfMesh mesh, double a) {}
  @override
  void clipPath(PdfPath path, PdfFillRule rule) {}
  @override
  void drawImage(PdfImageRequest request) {}
  @override
  void setBlendMode(PdfBlendMode mode) {}
  @override
  void setOverprint(
      {required bool fill, required bool stroke, required int mode}) {}
  @override
  void beginGroup(double alpha, {bool knockout = false}) {}
  @override
  void endGroup() {}
  @override
  void beginSoftMasked() {}
  @override
  void endSoftMasked(
      {required bool luminosity,
      required PdfRect backdrop,
      required void Function() drawMask,
      double backdropLuminance = 0,
      double transferScale = 1,
      double transferOffset = 0}) {}
}
