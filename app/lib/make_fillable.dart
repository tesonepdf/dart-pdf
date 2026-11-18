import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dart_pdf_editor/dart_pdf_editor.dart' show PdfPageExport;
import 'package:material_ui/material_ui.dart';
import 'package:pdf_document/pdf_document.dart';

import 'page_choice.dart';

// Rendi compilabile: cerca nelle pagine le righe su cui si scrive (linee
// disegnate, "____", "....") e le caselline da spuntare, e ci mette sopra
// campi di modulo veri (AcroForm). Funziona allo stesso modo sui PDF normali
// e sulle scansioni, perché lavora sull'immagine della pagina: non serve
// l'OCR. I campi che ci sono già non si toccano e non se ne mettono sopra.

/// Un punto della pagina dove mettere un campo, nello spazio della pagina
/// (y verso l'alto).
class FillableSpot {
  const FillableSpot(this.rect, {this.checkbox = false});

  final PdfRect rect;

  /// Vero per una casellina da spuntare, falso per una riga di testo.
  final bool checkbox;
}

/// Un rettangolo di pixel trovato nell'immagine di una pagina.
class PixelBox {
  const PixelBox(this.l, this.t, this.r, this.b, {this.checkbox = false});

  /// Estremi inclusi, in pixel, origine in alto a sinistra.
  final int l;
  final int t;
  final int r;
  final int b;
  final bool checkbox;

  int get width => r - l + 1;
  int get height => b - t + 1;
}

class _Line {
  _Line(this.l, this.r, this.firstY) : lastY = firstY;

  int l;
  int r;
  final int firstY;
  int lastY;

  int get rows => lastY - firstY + 1;
}

class _Dot {
  _Dot(this.l, this.t, this.r, this.b);

  final int l;
  final int t;
  final int r;
  final int b;

  double get cy => (t + b) / 2;
}

/// Cerca righe e caselline in un'immagine RGBA di [w]x[h] pixel; [ppp] sono i
/// pixel per punto (1 punto = 1/72 di pollice). Restituisce rettangoli in
/// pixel, senza badare a quello che c'è già nel PDF.
List<PixelBox> findFillableInBitmap(Uint8List rgba, int w, int h, double ppp) {
  if (w <= 0 || h <= 0 || rgba.length < w * h * 4) return const [];
  final dark = Uint8List(w * h);
  for (var i = 0, p = 0; i < w * h; i++, p += 4) {
    final lum = (rgba[p] * 77 + rgba[p + 1] * 151 + rgba[p + 2] * 28) >> 8;
    if (lum < 140 && rgba[p + 3] > 128) dark[i] = 1;
  }

  final minLen = math.max(20, (40 * ppp).round());

  // 1. Componenti connesse (a partire dalle sequenze di pixel scuri di ogni
  // riga), per le linee isolate (anche un po' storte), le caselline e i punti.
  final runY = <int>[];
  final runL = <int>[];
  final runR = <int>[];
  final parent = <int>[];
  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  void union(int a, int b) {
    final ra = find(a);
    final rb = find(b);
    if (ra != rb) parent[ra] = rb;
  }

  var prevStart = 0;
  var prevEnd = 0;
  for (var y = 0; y < h; y++) {
    final rowStart = runY.length;
    var ptr = prevStart;
    var x = 0;
    final base = y * w;
    while (x < w) {
      if (dark[base + x] == 0) {
        x++;
        continue;
      }
      final s = x;
      while (x < w && dark[base + x] == 1) {
        x++;
      }
      final e = x - 1;
      final id = runY.length;
      runY.add(y);
      runL.add(s);
      runR.add(e);
      parent.add(id);
      while (ptr < prevEnd && runR[ptr] < s) {
        ptr++;
      }
      for (var k = ptr; k < prevEnd && runL[k] <= e; k++) {
        union(id, k);
      }
    }
    prevStart = rowStart;
    prevEnd = runY.length;
  }

  final n = runY.length;
  final cMinX = List<int>.filled(n, 1 << 30);
  final cMaxX = List<int>.filled(n, -1);
  final cMinY = List<int>.filled(n, 1 << 30);
  final cMaxY = List<int>.filled(n, -1);
  final cCount = List<int>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final r = find(i);
    if (runL[i] < cMinX[r]) cMinX[r] = runL[i];
    if (runR[i] > cMaxX[r]) cMaxX[r] = runR[i];
    if (runY[i] < cMinY[r]) cMinY[r] = runY[i];
    if (runY[i] > cMaxY[r]) cMaxY[r] = runY[i];
    cCount[r] += runR[i] - runL[i] + 1;
  }

  final lines = <PixelBox>[];
  final boxes = <PixelBox>[];
  final dots = <_Dot>[];
  final minBox = math.max(6, (5 * ppp).round());
  final maxBox = (18 * ppp).round();
  final maxDot = math.max(3, (3.5 * ppp).round());

  bool darkAt(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && dark[y * w + x] == 1;

  bool cornerDark(int x0, int y0) {
    for (var dy = 0; dy < 3; dy++) {
      for (var dx = 0; dx < 3; dx++) {
        if (darkAt(x0 + dx, y0 + dy)) return true;
      }
    }
    return false;
  }

  for (var i = 0; i < n; i++) {
    if (parent[i] != i) continue;
    final l = cMinX[i], r = cMaxX[i], t = cMinY[i], b = cMaxY[i];
    final cw = r - l + 1, ch = b - t + 1;
    final count = cCount[i];
    if (cw >= minLen) {
      final thick = count / cw;
      if (thick >= 0.6 &&
          thick <= 3.5 * ppp &&
          ch <= cw * 0.03 + 4 * ppp) {
        lines.add(PixelBox(l, t, r, b));
      }
      continue;
    }
    if (cw <= maxDot && ch <= maxDot) {
      dots.add(_Dot(l, t, r, b));
      continue;
    }
    if (cw >= minBox && cw <= maxBox && ch >= minBox && ch <= maxBox) {
      final ratio = cw / ch;
      if (ratio < 0.8 || ratio > 1.25) continue;
      if (count / (cw * ch) > 0.55) continue;
      if (!cornerDark(l, t) ||
          !cornerDark(r - 2, t) ||
          !cornerDark(l, b - 2) ||
          !cornerDark(r - 2, b - 2)) {
        continue;
      }
      var inner = 0, total = 0;
      final x0 = l + (cw * 0.3).round(), x1 = l + (cw * 0.7).round();
      final y0 = t + (ch * 0.3).round(), y1 = t + (ch * 0.7).round();
      for (var yy = y0; yy <= y1; yy++) {
        for (var xx = x0; xx <= x1; xx++) {
          total++;
          if (darkAt(xx, yy)) inner++;
        }
      }
      if (total > 0 && inner / total > 0.2) continue;
      boxes.add(PixelBox(l, t, r, b, checkbox: true));
    }
  }

  // 2. Linee lunghe righe per riga, per le linee dentro una tabella (che nelle
  // componenti connesse sono un pezzo solo con tutto il resto).
  final done = <_Line>[];
  var active = <_Line>[];
  final maxRows = math.max(3, (4 * ppp).round());
  for (var y = 0; y < h; y++) {
    final base = y * w;
    final fresh = <_Line>[];
    var x = 0;
    while (x < w) {
      if (dark[base + x] == 0) {
        x++;
        continue;
      }
      final s = x;
      var e = x;
      var gap = 0;
      x++;
      while (x < w) {
        if (dark[base + x] == 1) {
          e = x;
          gap = 0;
        } else {
          gap++;
          if (gap > 2) break;
        }
        x++;
      }
      final len = e - s + 1;
      if (len < minLen) continue;
      _Line? match;
      for (final a in active) {
        if (a.lastY != y - 1) continue;
        final overlap = math.min(a.r, e) - math.max(a.l, s) + 1;
        if (overlap >= 0.6 * math.min(len, a.r - a.l + 1)) {
          match = a;
          break;
        }
      }
      if (match != null) {
        match.l = math.min(match.l, s);
        match.r = math.max(match.r, e);
        match.lastY = y;
      } else {
        fresh.add(_Line(s, e, y));
      }
    }
    final still = <_Line>[];
    for (final a in active) {
      if (a.lastY == y) {
        still.add(a);
      } else {
        done.add(a);
      }
    }
    still.addAll(fresh);
    active = still;
  }
  done.addAll(active);
  for (final a in done) {
    if (a.rows <= maxRows) lines.add(PixelBox(a.l, a.firstY, a.r, a.lastY));
  }

  // 3. Righe di puntini: tanti punti piccoli, allineati e vicini.
  dots.sort((a, b) => a.cy.compareTo(b.cy));
  final maxGap = (5 * ppp).round();
  var from = 0;
  while (from < dots.length) {
    var to = from + 1;
    while (to < dots.length && dots[to].cy - dots[to - 1].cy <= 1.5 * ppp) {
      to++;
    }
    final row = dots.sublist(from, to)..sort((a, b) => a.l.compareTo(b.l));
    var start = 0;
    for (var k = 1; k <= row.length; k++) {
      final breaks = k == row.length || row[k].l - row[k - 1].r > maxGap;
      if (!breaks) continue;
      final chain = row.sublist(start, k);
      start = k;
      if (chain.length < 10) continue;
      final l = chain.first.l, r = chain.last.r;
      if (r - l + 1 < minLen) continue;
      lines.add(PixelBox(l, chain.map((d) => d.t).reduce(math.min), r,
          chain.map((d) => d.b).reduce(math.max)));
    }
    from = to;
  }

  // 4. Via le righe con testo subito sopra (sono sottolineature o righe già
  // scritte) e i doppioni.
  final band = math.max(3, (7 * ppp).round());
  final gapAbove = math.max(1, (2 * ppp).round());
  final kept = <PixelBox>[];
  lines.sort((a, b) => b.width.compareTo(a.width));
  for (final line in lines) {
    final y1 = line.t - gapAbove;
    final y0 = y1 - band;
    if (y0 < 0) continue;
    var count = 0;
    for (var yy = y0; yy < y1; yy++) {
      final base = yy * w;
      for (var xx = line.l; xx <= line.r; xx++) {
        if (dark[base + xx] == 1) count++;
      }
    }
    if (count / ((y1 - y0) * line.width) > 0.05) continue;
    var duplicate = false;
    for (final k in kept) {
      final overlap = math.min(k.r, line.r) - math.max(k.l, line.l) + 1;
      if (overlap >= 0.5 * line.width &&
          ((k.t + k.b) - (line.t + line.b)).abs() <= 6 * ppp) {
        duplicate = true;
        break;
      }
    }
    if (!duplicate) kept.add(line);
    if (kept.length >= 200) break;
  }
  return [...kept, ...boxes.take(200)];
}

/// Quanti punti sopra la riga sono liberi (fino a [limit]), per sapere quanto
/// può essere alto il campo senza coprire il testo che sta sopra.
int _freeRowsAbove(
    Uint8List rgba, int w, int h, PixelBox line, int limit) {
  var free = 0;
  for (var y = line.t - 1; y >= 0 && free < limit; y--) {
    var dark = 0;
    for (var x = line.l; x <= line.r; x++) {
      final p = (y * w + x) * 4;
      final lum = (rgba[p] * 77 + rgba[p + 1] * 151 + rgba[p + 2] * 28) >> 8;
      if (lum < 140) dark++;
    }
    if (dark / line.width > 0.03) break;
    free++;
  }
  return free;
}

/// Trova i punti dove mettere un campo in una pagina ([pageIndex], da 0).
/// Se c'è una [zone] (spazio della pagina) tiene solo quelli dentro la zona.
/// I punti che toccano un campo già presente non si danno.
Future<List<FillableSpot>> findFillableSpotsOnPage(
  PdfDocument document,
  int pageIndex, {
  PdfRect? zone,
}) async {
  final page = document.page(pageIndex);
  final box = page.cropBox;
  if (box.width <= 0 || box.height <= 0) return const [];
  var scale = 2.0;
  final longSide = math.max(box.width, box.height);
  if (longSide * scale > 3200) scale = 3200 / longSide;
  // Pagina senza rotazione: i campi si scrivono nello spazio della pagina.
  final png = await PdfPageExport.exportPage(page,
      scale: scale, annotations: false, rotation: 0);
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  codec.dispose();
  final image = frame.image;
  final w = image.width, h = image.height;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (data == null) return const [];
  final rgba =
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  final sx = w / box.width, sy = h / box.height;
  final found = findFillableInBitmap(rgba, w, h, sx);

  final existing = <PdfRect>[];
  final form = PdfAcroForm.of(document);
  if (form != null) {
    for (final info in form.describeFields()) {
      final rect = info.rect;
      if (info.pageIndex == pageIndex && rect != null) existing.add(rect);
    }
  }

  bool touchesExisting(PdfRect r) {
    for (final e in existing) {
      if (r.left < e.right + 2 &&
          r.right > e.left - 2 &&
          r.bottom < e.top + 2 &&
          r.top > e.bottom - 2) {
        return true;
      }
    }
    return false;
  }

  final out = <FillableSpot>[];
  for (final f in found) {
    final left = box.left + f.l / sx;
    final right = box.left + (f.r + 1) / sx;
    final topEdge = box.top - f.t / sy;
    final bottomEdge = box.top - (f.b + 1) / sy;
    PdfRect rect;
    if (f.checkbox) {
      rect = PdfRect(left - 0.5, bottomEdge - 0.5, right + 0.5, topEdge + 0.5);
    } else {
      final free = _freeRowsAbove(rgba, w, h, f, (16 * sx).round());
      final height = (free / sx - 1).clamp(9.0, 15.0);
      final bottom = topEdge + 0.5;
      rect = PdfRect(left + 1, bottom, right - 1, bottom + height);
    }
    if (rect.width <= 2 || rect.height <= 2) continue;
    if (zone != null &&
        (rect.left < zone.left - 3 ||
            rect.right > zone.right + 3 ||
            rect.bottom < zone.bottom - 3 ||
            rect.top > zone.top + 3)) {
      continue;
    }
    if (touchesExisting(rect)) continue;
    out.add(FillableSpot(rect, checkbox: f.checkbox));
  }
  return out;
}

/// I punti di tutte le [pages] (indici da 0). Una pagina che non si legge si
/// salta e finisce in [failed].
Future<({Map<int, List<FillableSpot>> spots, List<int> failed})>
    findFillableSpots(
  PdfDocument document,
  Iterable<int> pages, {
  PdfRect? zone,
}) async {
  final spots = <int, List<FillableSpot>>{};
  final failed = <int>[];
  for (final p in pages) {
    try {
      final list = await findFillableSpotsOnPage(document, p, zone: zone);
      if (list.isNotEmpty) spots[p] = list;
    } catch (_) {
      failed.add(p);
    }
  }
  return (spots: spots, failed: failed);
}

/// Mette i campi in una sola modifica (si annulla con una mossa). Restituisce
/// quanti ne ha messi.
int applyFillable(PdfEditor editor, Map<int, List<FillableSpot>> byPage) {
  var added = 0;
  final used = <String>{};
  String freshName(String stem) {
    var k = 1;
    while (true) {
      final name = '${stem}_$k';
      k++;
      if (used.contains(name)) continue;
      if (editor.acroForm?.fieldNamed(name) != null) continue;
      used.add(name);
      return name;
    }
  }

  final pages = byPage.keys.toList()..sort();
  for (final page in pages) {
    for (final spot in byPage[page]!) {
      if (spot.checkbox) {
        editor.addCheckBoxField(page, freshName('casella_p${page + 1}'),
            spot.rect);
      } else {
        editor.addTextField(page, freshName('campo_p${page + 1}'), spot.rect);
      }
      added++;
    }
  }
  return added;
}

/// Il nome della scheda con la copia compilabile.
String fillableTabTitle(String title) {
  var stem = title.trim();
  if (stem.toLowerCase().endsWith('.pdf')) {
    stem = stem.substring(0, stem.length - 4).trim();
  }
  if (stem.isEmpty) stem = 'documento';
  return '$stem (compilabile).pdf';
}

/// Dove applicare: `pages` null = tutto il documento, altrimenti gli indici
/// (da 0); `zone` vero = una zona di una pagina, da disegnare.
typedef FillableScope = ({List<int>? pages, bool zone});

/// Chiede dove rendere compilabile il documento. Null se si annulla.
Future<FillableScope?> askFillableScope(
  BuildContext context, {
  required int pageCount,
  required int currentPage,
}) {
  return showDialog<FillableScope>(
    context: context,
    builder: (context) =>
        _FillableScopeDialog(pageCount: pageCount, currentPage: currentPage),
  );
}

class _FillableScopeDialog extends StatefulWidget {
  const _FillableScopeDialog(
      {required this.pageCount, required this.currentPage});

  final int pageCount;
  final int currentPage;

  @override
  State<_FillableScopeDialog> createState() => _FillableScopeDialogState();
}

class _FillableScopeDialogState extends State<_FillableScopeDialog> {
  int _mode = 0;
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _option(int mode, String label) => ListTile(
        key: ValueKey('fillable-scope-$mode'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(_mode == mode
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked),
        title: Text(label),
        onTap: () => setState(() {
          _mode = mode;
          _error = null;
        }),
      );

  void _confirm() {
    switch (_mode) {
      case 0:
        Navigator.pop<FillableScope>(context, (pages: null, zone: false));
      case 1:
        Navigator.pop<FillableScope>(
            context, (pages: [widget.currentPage], zone: false));
      case 2:
        final pages = parsePageList(_controller.text, widget.pageCount);
        if (pages == null) {
          setState(() => _error =
              'Pagine non valide: il documento ha ${widget.pageCount} pagine');
          return;
        }
        Navigator.pop<FillableScope>(context, (pages: pages, zone: false));
      default:
        Navigator.pop<FillableScope>(context, (pages: const [], zone: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dove rendo compilabile?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _option(0, 'Tutto il documento (${widget.pageCount} pagine)'),
            _option(1, 'Solo questa pagina (${widget.currentPage + 1})'),
            _option(2, 'Alcune pagine'),
            if (_mode == 2)
              TextField(
                key: const ValueKey('fillable-scope-pages'),
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Pagine, per esempio 1,3,5-7',
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _confirm(),
              ),
            _option(3, 'Una zona della pagina'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const ValueKey('fillable-scope-ok'),
          onPressed: _confirm,
          child: Text(_mode == 3 ? 'Scegli la zona' : 'Continua'),
        ),
      ],
    );
  }
}
