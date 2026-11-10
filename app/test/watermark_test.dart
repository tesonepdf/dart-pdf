// Filigrana (watermark.dart): la scrittura nel PDF con il motore e la finestra.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart' show PdfTextExtractor;
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';

import 'package:dart_pdf_editor_app/watermark.dart';

void main() {
  group('nel PDF', () {
    PdfDocument two() =>
        PdfDocument.open(PdfMerger.merge([buildClassicPdf(), buildClassicPdf()]));

    String text(PdfEditor editor, int page) =>
        PdfTextExtractor.extract(PdfDocument.open(editor.save()), page).text;

    test('di base scrive BOZZA su ogni pagina e lascia il resto', () {
      final editor = PdfEditor(two());
      applyWatermark(editor, const WatermarkOptions());
      expect(text(editor, 0), contains('BOZZA'));
      expect(text(editor, 1), contains('BOZZA'));
      expect(text(editor, 0), contains('Hello, world!'));
    });

    test('partendo dalla pagina 2 la prima resta senza filigrana', () {
      final editor = PdfEditor(two());
      applyWatermark(
          editor, const WatermarkOptions(text: 'COPIA', firstPage: 2));
      expect(text(editor, 0), isNot(contains('COPIA')));
      expect(text(editor, 1), contains('COPIA'));
    });

    test('dritta e verticale scrivono lo stesso testo', () {
      for (final angle in [WatermarkAngle.flat, WatermarkAngle.vertical]) {
        final editor = PdfEditor(two());
        applyWatermark(editor, WatermarkOptions(angle: angle));
        expect(editor.hasChanges, isTrue);
      }
    });

    test('senza testo o oltre la fine non cambia niente', () {
      final empty = PdfEditor(two());
      applyWatermark(empty, const WatermarkOptions(text: '   '));
      expect(empty.hasChanges, isFalse);

      final beyond = PdfEditor(two());
      applyWatermark(beyond, const WatermarkOptions(firstPage: 9));
      expect(beyond.hasChanges, isFalse);
    });
  });

  group('finestra', () {
    WatermarkOptions? result;
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
                result = await showWatermarkDialog(context, pageCount: 5);
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

    Finder inside(String key, String label) => find.descendant(
        of: find.byKey(ValueKey(key)), matching: find.text(label));

    testWidgets('di base: BOZZA, media, diagonale, media, dalla 1',
        (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('watermark-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('watermark-confirm')));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result!.text, 'BOZZA');
      expect(result!.size, WatermarkSize.medium);
      expect(result!.angle, WatermarkAngle.diagonal);
      expect(result!.strength, WatermarkStrength.medium);
      expect(result!.firstPage, 1);
    });

    testWidgets('si può cambiare testo, grandezza, inclinazione e partenza',
        (tester) async {
      await open(tester);
      await tester.enterText(
          find.byKey(const ValueKey('watermark-text')), 'RISERVATO');
      await tester.tap(inside('watermark-size', 'Grande'));
      await tester.pumpAndSettle();
      await tester.tap(inside('watermark-angle', 'Dritta'));
      await tester.pumpAndSettle();
      await tester.tap(inside('watermark-strength', 'Forte'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('watermark-first')), '3');
      await tester.tap(find.byKey(const ValueKey('watermark-confirm')));
      await tester.pumpAndSettle();
      expect(result!.text, 'RISERVATO');
      expect(result!.size, WatermarkSize.large);
      expect(result!.angle, WatermarkAngle.flat);
      expect(result!.strength, WatermarkStrength.strong);
      expect(result!.firstPage, 3);
    });

    testWidgets('con il testo vuoto Applica è spento', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const ValueKey('watermark-text')), '');
      await tester.pump();
      final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('watermark-confirm')));
      expect(button.onPressed, isNull);
    });

    testWidgets('una partenza fuori misura si porta nei limiti',
        (tester) async {
      await open(tester);
      await tester.enterText(
          find.byKey(const ValueKey('watermark-first')), '99');
      await tester.tap(find.byKey(const ValueKey('watermark-confirm')));
      await tester.pumpAndSettle();
      expect(result!.firstPage, 5);
    });

    testWidgets('Annulla restituisce null', (tester) async {
      await open(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isNull);
    });
  });
}
