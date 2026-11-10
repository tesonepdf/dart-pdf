// "Esporta come testo semplice (.txt)…", "Esporta come Word (.docx)…", "Esporta come Excel (.xlsx)…", "Esporta una zona come Excel…" e "Foto in PDF (una per pagina)…" sono
// collegate al menu di DartPDF. La lettura del testo e il salvataggio usano
// il motore e i canali della piattaforma, quindi qui si prova solo il
// collegamento (le parti di logica sono in pdf_conversions_test.dart).
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:dart_pdf_editor_app/editor_screen.dart';

void main() {
  late PdfEditingPreferences prefs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefs = PdfEditingPreferences();
  });
  tearDown(() => prefs.dispose());

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('DartPDF menu'));
    await tester.pumpAndSettle();
  }

  testWidgets('con un documento aperto il menu offre Esporta come testo',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EditorScreen(
        prefs: prefs,
        initialDocument: (bytes: buildClassicPdf(), title: 'Report.pdf'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await openMenu(tester);

    expect(find.byKey(const ValueKey('menu-export-text')), findsOneWidget);
    expect(find.text('Esporta come testo semplice (.txt)…'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-export-word')), findsOneWidget);
    expect(find.text('Esporta come Word (.docx)…'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-export-excel')), findsOneWidget);
    expect(find.text('Esporta come Excel (.xlsx)…'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('menu-export-excel-zone')), findsOneWidget);
    expect(find.text('Esporta una zona come Excel (.xlsx)…'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-photos-to-pdf')), findsOneWidget);
  });

  testWidgets('senza documento non c\'è Esporta come testo ma c\'è Foto in PDF',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: EditorScreen(prefs: prefs)));
    await tester.pump();
    await openMenu(tester);

    expect(find.byKey(const ValueKey('menu-export-text')), findsNothing);
    expect(find.byKey(const ValueKey('menu-export-word')), findsNothing);
    expect(find.byKey(const ValueKey('menu-export-excel')), findsNothing);
    expect(find.byKey(const ValueKey('menu-export-excel-zone')), findsNothing);
    expect(find.byKey(const ValueKey('menu-photos-to-pdf')), findsOneWidget);
    expect(find.text('Foto in PDF (una per pagina)…'), findsOneWidget);
  });
}
