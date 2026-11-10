// Regressioni del 10/11:
//  - la matita su una casella di testo selezionata deve lasciare la modifica
//    aperta (prima si chiudeva subito, perche' lo strumento passava da
//    Seleziona a Casella di testo e l'editor lo leggeva come cambio voluto);
//  - le linee guida di Disegna (orizzontale / verticale / entrambe).
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/editor_screen.dart';

void main() {
  late PdfEditingPreferences prefs;
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefs = PdfEditingPreferences();
  });
  tearDown(() => prefs.dispose());

  Future<PdfEditingController> pumpWithDoc(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EditorScreen(
        prefs: prefs,
        initialDocument: (bytes: buildClassicPdf(), title: 'Report.pdf'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return tester.widget<PdfEditorView>(find.byType(PdfEditorView)).controller!;
  }

  testWidgets('matita: la modifica della casella selezionata resta aperta',
      (tester) async {
    final session = await pumpWithDoc(tester);
    session
      ..tool = PdfEditTool.freeText
      ..addFreeText(0, const PdfRect(100, 600, 400, 650), 'Originale')
      ..selectAnnotation(0, 0);
    await tester.pump();
    expect(session.requestEditSelectedTextInline(), isTrue);
    await tester.pump();
    await tester.pump();
    // qualche fotogramma in piu': il bug chiudeva l'editor al fotogramma dopo
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('pdf-freetext-editor')), findsOneWidget);
    expect(session.isEditingText, isTrue);
    expect(session.tool, PdfEditTool.freeText);
  });

  testWidgets('linee guida: modalita e visibilita secondo lo strumento',
      (tester) async {
    final session = await pumpWithDoc(tester);
    expect(session.guideLines, PdfGuideLines.off);
    expect(session.guideLinesActive, isFalse);

    session.tool = PdfEditTool.ink;
    session.guideLines = PdfGuideLines.horizontal;
    expect(session.guideLinesActive, isTrue);
    session.guideLines = PdfGuideLines.vertical;
    expect(session.guideLinesActive, isTrue);
    session.guideLines = PdfGuideLines.both;
    expect(session.guideLinesActive, isTrue);

    session.tool = PdfEditTool.highlight;
    expect(session.guideLinesActive, isTrue);

    // fuori da Disegna / Evidenzia le linee non si vedono
    session.tool = PdfEditTool.rectangle;
    expect(session.guideLinesActive, isFalse);

    // spegnerle azzera anche il punto
    session.tool = PdfEditTool.ink;
    session.guidePoint.value = (page: 0, x: 100.0, y: 200.0);
    session.guideLines = PdfGuideLines.off;
    expect(session.guideLinesActive, isFalse);
    expect(session.guidePoint.value, isNull);
  });

  testWidgets('linee guida: il dito sposta la linea e non disegna',
      (tester) async {
    final session = await pumpWithDoc(tester);
    session
      ..tool = PdfEditTool.ink
      ..guideLines = PdfGuideLines.both;
    await tester.pump();

    final start = tester.getCenter(find.byType(PdfViewer));
    final gesture =
        await tester.startGesture(start, kind: PointerDeviceKind.touch);
    await tester.pump();
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(session.guidePoint.value, isNotNull);
    expect(session.hasPendingInk, isFalse);
    expect(session.document.page(0).annotations, isEmpty);
    // la linea resta dov'e' dopo aver alzato il dito
    expect(find.byKey(const ValueKey('pdf-reference-guides')), findsWidgets);
  });

  testWidgets('linee guida: il pulsante nel pannello Disegna le accende',
      (tester) async {
    final session = await pumpWithDoc(tester);
    session.tool = PdfEditTool.ink;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final button = find.byKey(const ValueKey('pdf-guide-lines'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Both'));
    await tester.pumpAndSettle();

    expect(session.guideLines, PdfGuideLines.both);
  });
}
