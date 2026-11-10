// Numera le pagine (page_numbers.dart): le scelte, la scrittura nel PDF con il
// motore e la finestra.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart' show PdfTextExtractor;
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';

import 'package:dart_pdf_editor_app/page_numbers.dart';

void main() {
  group('scelte', () {
    test('la fascia sta a sinistra, al centro o a destra secondo la posizione',
        () {
      final right =
          pageNumberBand(const PageNumberOptions(position: PageNumberPosition.bottomRight));
      expect(right.right, 'Pagina {page} di {pages}');
      expect(right.left, isNull);
      expect(right.center, isNull);

      final left =
          pageNumberBand(const PageNumberOptions(position: PageNumberPosition.topLeft));
      expect(left.left, isNotNull);
      expect(left.right, isNull);

      final center = pageNumberBand(const PageNumberOptions(
          format: PageNumberFormat.plain, size: 14));
      expect(center.center, '{page}');
      expect(center.size, 14);
    });

    test('alto e basso', () {
      expect(PageNumberPosition.topCenter.isTop, isTrue);
      expect(PageNumberPosition.topRight.isTop, isTrue);
      expect(PageNumberPosition.bottomLeft.isTop, isFalse);
    });
  });

  group('nel PDF', () {
    PdfDocument two() =>
        PdfDocument.open(PdfMerger.merge([buildClassicPdf(), buildClassicPdf()]));

    String text(PdfEditor editor, int page) =>
        PdfTextExtractor.extract(PdfDocument.open(editor.save()), page).text;

    test('di base numera ogni pagina: "Pagina 1 di 2", "Pagina 2 di 2"', () {
      final editor = PdfEditor(two());
      applyPageNumbers(editor, const PageNumberOptions());
      expect(text(editor, 0), contains('Pagina 1 di 2'));
      expect(text(editor, 1), contains('Pagina 2 di 2'));
      expect(text(editor, 0), contains('Hello, world!'));
    });

    test('partendo dalla pagina 2 la prima resta senza numero', () {
      final editor = PdfEditor(two());
      applyPageNumbers(
          editor,
          const PageNumberOptions(
              format: PageNumberFormat.pageWord, firstPage: 2));
      expect(text(editor, 0), isNot(contains('Pagina')));
      expect(text(editor, 1), contains('Pagina 2'));
    });

    test('in alto a destra, solo il numero', () {
      final editor = PdfEditor(two());
      applyPageNumbers(
          editor,
          const PageNumberOptions(
              position: PageNumberPosition.topRight,
              format: PageNumberFormat.slash));
      expect(text(editor, 1), contains('2 / 2'));
    });

    test('una prima pagina oltre la fine non cambia niente', () {
      final editor = PdfEditor(two());
      applyPageNumbers(editor, const PageNumberOptions(firstPage: 9));
      expect(editor.hasChanges, isFalse);
    });
  });

  group('finestra', () {
    PageNumberOptions? result;
    var closed = false;

    Future<void> open(WidgetTester tester) async {
      result = null;
      closed = false;
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showPageNumbersDialog(context, pageCount: 5);
                closed = true;
              },
              child: const Text('apri'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();
    }

    testWidgets('di base: in basso al centro, "Pagina N di M", dalla 1',
        (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('page-numbers-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('page-numbers-confirm')));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result!.position, PageNumberPosition.bottomCenter);
      expect(result!.format, PageNumberFormat.pageOfPages);
      expect(result!.size, 10);
      expect(result!.firstPage, 1);
    });

    testWidgets('si può cambiare posizione, grandezza e pagina di partenza',
        (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('page-numbers-position')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In alto a destra').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grande'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('page-numbers-first')), '3');
      await tester.tap(find.byKey(const ValueKey('page-numbers-confirm')));
      await tester.pumpAndSettle();
      expect(result!.position, PageNumberPosition.topRight);
      expect(result!.size, 14);
      expect(result!.firstPage, 3);
    });

    testWidgets('una pagina di partenza fuori misura si porta nei limiti',
        (tester) async {
      await open(tester);
      await tester.enterText(
          find.byKey(const ValueKey('page-numbers-first')), '99');
      await tester.tap(find.byKey(const ValueKey('page-numbers-confirm')));
      await tester.pumpAndSettle();
      expect(result!.firstPage, 5);
    });

    testWidgets('Annulla chiude senza scelte', (tester) async {
      await open(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isNull);
    });
  });
}
