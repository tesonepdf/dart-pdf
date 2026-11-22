import 'package:pdf_cos/pdf_cos.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:test/test.dart';

import 'content_edit_test.dart' show buildContentPdf, richContent;
import 'content_move_test.dart' show boundsOf, expectRect;

/// Trasforma gli elementi [ids] della pagina 0 con [matrix].
int transform(PdfDocument doc, List<int> ids, PdfMatrix matrix) =>
    PdfEditor(doc)
        .transformElements(PdfPageElements.of(doc, 0), ids, matrix);

void main() {
  group('transforming page content', () {
    test('una scala raddoppia un tracciato e un\'immagine', () {
      final doc = PdfDocument.open(buildContentPdf(richContent));
      final before = boundsOf(doc);
      expect(transform(doc, [0, 3], PdfMatrix(2, 0, 0, 2, 0, 0)), 2);

      final after = boundsOf(doc);
      expect(after, hasLength(before.length));
      expectRect(
          after[0],
          PdfRect(before[0]!.left * 2, before[0]!.bottom * 2,
              before[0]!.right * 2, before[0]!.top * 2));
      expectRect(
          after[3],
          PdfRect(before[3]!.left * 2, before[3]!.bottom * 2,
              before[3]!.right * 2, before[3]!.top * 2));
      // gli altri non si toccano
      expectRect(after[2], before[2]!);
    });

    test('lo spostamento e\' una trasformazione come le altre', () {
      final doc = PdfDocument.open(buildContentPdf(richContent));
      expect(transform(doc, [0], PdfMatrix.translation(-40, 12)), 1);
      expectRect(boundsOf(doc)[0], const PdfRect(60, 112, 110, 152));
    });

    test('il testo si ingrandisce e il resto della riga non si muove', () {
      final doc = PdfDocument.open(buildContentPdf(richContent));
      final before = boundsOf(doc);
      expect(transform(doc, [1], PdfMatrix(2, 0, 0, 2, 0, 0)), 1);

      final after = boundsOf(doc);
      expect(after[1]!.width, closeTo(before[1]!.width * 2, 0.5));
      expect(after[1]!.height, closeTo(before[1]!.height * 2, 0.5));
      expectRect(after[2], before[2]!);
    });
  });
}
