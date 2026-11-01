import 'package:flutter_test/flutter_test.dart';

import 'package:dart_pdf_editor_app/standard_sizes.dart';

void main() {
  test('gli identificativi sono unici', () {
    final ids = kStandardSizes.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('carta di credito: 85,60 mm a 300 dpi sono circa 1011 pixel', () {
    final card = standardSizeById('card_id1')!;
    expect(card.dpiForPixelWidth(1011), closeTo(300, 0.5));
  });

  test('A4 in punti PDF', () {
    final a4 = standardSizeById('a4')!;
    expect(a4.widthPt, closeTo(595.28, 0.01));
    expect(a4.heightPt, closeTo(841.89, 0.01));
  });

  test('ogni gruppo ha almeno una misura', () {
    for (final g in StandardSizeGroup.values) {
      expect(standardSizesIn(g), isNotEmpty, reason: g.name);
    }
  });
}
