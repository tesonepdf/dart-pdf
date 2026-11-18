import 'dart:typed_data';

import 'package:dart_pdf_editor_app/make_fillable.dart';
import 'package:flutter_test/flutter_test.dart';

// Immagine bianca w x h (RGBA) su cui si disegnano linee e quadrati neri.
Uint8List _blank(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var i = 0; i < px.length; i += 4) {
    px[i] = px[i + 1] = px[i + 2] = px[i + 3] = 255;
  }
  return px;
}

void _black(Uint8List px, int w, int x, int y) {
  final p = (y * w + x) * 4;
  px[p] = px[p + 1] = px[p + 2] = 0;
}

void main() {
  const w = 600, h = 400;

  test('una linea lunga e sottile e\' una riga', () {
    final px = _blank(w, h);
    for (var x = 50; x < 350; x++) {
      _black(px, w, x, 200);
    }
    final found = findFillableInBitmap(px, w, h, 2);
    expect(found.where((b) => !b.checkbox), hasLength(1));
    final line = found.firstWhere((b) => !b.checkbox);
    expect(line.l, 50);
    expect(line.r, 349);
    expect(line.t, 200);
  });

  test('una riga con testo subito sopra non conta', () {
    final px = _blank(w, h);
    for (var x = 50; x < 350; x++) {
      _black(px, w, x, 200);
    }
    // Lettere: blocchi di 5 x 10 pixel, uno ogni 8.
    for (var y = 187; y < 197; y++) {
      for (var x = 60; x < 340; x += 8) {
        for (var dx = 0; dx < 5; dx++) {
          _black(px, w, x + dx, y);
        }
      }
    }
    expect(findFillableInBitmap(px, w, h, 2).where((b) => !b.checkbox),
        isEmpty);
  });

  test('una linea corta non conta', () {
    final px = _blank(w, h);
    for (var x = 50; x < 90; x++) {
      _black(px, w, x, 200);
    }
    expect(findFillableInBitmap(px, w, h, 2), isEmpty);
  });

  test('una fila di puntini e\' una riga', () {
    final px = _blank(w, h);
    for (var x = 50; x < 350; x += 6) {
      _black(px, w, x, 200);
      _black(px, w, x + 1, 200);
      _black(px, w, x, 201);
      _black(px, w, x + 1, 201);
    }
    final found = findFillableInBitmap(px, w, h, 2);
    expect(found.where((b) => !b.checkbox), hasLength(1));
  });

  test('un quadratino vuoto e\' una casellina, uno pieno no', () {
    final px = _blank(w, h);
    // Vuoto, 14 x 14 pixel.
    for (var i = 0; i < 14; i++) {
      _black(px, w, 100 + i, 100);
      _black(px, w, 100 + i, 113);
      _black(px, w, 100, 100 + i);
      _black(px, w, 113, 100 + i);
    }
    // Pieno.
    for (var y = 0; y < 14; y++) {
      for (var x = 0; x < 14; x++) {
        _black(px, w, 200 + x, 100 + y);
      }
    }
    final found = findFillableInBitmap(px, w, h, 2);
    expect(found.where((b) => b.checkbox), hasLength(1));
    expect(found.single.l, 100);
  });

  test('il nome della scheda', () {
    expect(fillableTabTitle('Modulo.pdf'), 'Modulo (compilabile).pdf');
    expect(fillableTabTitle(''), 'documento (compilabile).pdf');
  });
}
