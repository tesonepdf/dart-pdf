// Il telefono ha lo stesso menu di Windows: la tendina con tutte le voci e i
// sottomenu (File, Questo documento, App), con le righe alte quanto serve al
// tocco. Qui si prova a dimensione di telefono.
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/editor_screen.dart';

void main() {
  late PdfEditingPreferences prefs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefs = PdfEditingPreferences();
  });
  tearDown(() => prefs.dispose());

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pump(
    WidgetTester tester, {
    bool withDoc = false,
    bool withScanner = false,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: EditorScreen(
        prefs: prefs,
        documentScanner: withScanner ? () async => null : null,
        initialDocument:
            withDoc ? (bytes: buildClassicPdf(), title: 'Report.pdf') : null,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('DartPDF menu'));
    await tester.pumpAndSettle();
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  testWidgets('il telefono ha la tendina di Windows con tutte le sezioni',
      (tester) async {
    phoneSize(tester);
    await pump(tester, withDoc: true);
    await openMenu(tester);

    // niente foglio con i gruppi: la tendina, con le etichette di sezione
    expect(key('app-menu-sheet'), findsNothing);
    expect(find.text('FILE'), findsOneWidget);
    expect(key('menu-command-palette'), findsOneWidget);
    for (final id in [
      'menu-new-document',
      'menu-open',
      'open-recent-submenu',
      'menu-group-import',
      'menu-photos-to-pdf',
      'menu-open-comic',
      'menu-open-epub',
      'menu-compose-sheet',
      'menu-save-as',
      'menu-reduce-file-size',
      'menu-print',
      'menu-export-image',
      'menu-digital-signature',
      'menu-compare',
      'menu-insert-document',
      'menu-read-only',
      'menu-settings',
    ]) {
      expect(key(id), findsOneWidget, reason: id);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('senza documento restano solo le voci di File e App',
      (tester) async {
    phoneSize(tester);
    await pump(tester);
    await openMenu(tester);

    expect(key('menu-new-document'), findsOneWidget);
    expect(key('menu-open'), findsOneWidget);
    expect(key('open-recent-submenu'), findsOneWidget);
    expect(key('menu-print'), findsNothing);
    expect(key('menu-digital-signature'), findsNothing);
    expect(key('menu-read-only'), findsNothing);
    expect(key('menu-settings'), findsOneWidget);
  });

  testWidgets('Nuovo apre la scelta e lo scanner e\' in File', (tester) async {
    phoneSize(tester);
    await pump(tester, withScanner: true);
    await openMenu(tester);

    expect(key('menu-scan-document'), findsOneWidget);
    await tester.tap(key('menu-new-document'));
    await tester.pumpAndSettle();
    expect(key('new-document-dialog'), findsOneWidget);
  });

  testWidgets('lo scanner e\' in File e Inserisci scansione nel documento',
      (tester) async {
    phoneSize(tester);
    await pump(tester, withDoc: true, withScanner: true);
    await openMenu(tester);

    expect(key('menu-scan-document'), findsOneWidget);
    expect(key('menu-insert-scan'), findsOneWidget);
  });

  testWidgets('sul telefono restano Schede aperte e Condividi',
      (tester) async {
    phoneSize(tester);
    await pump(tester, withDoc: true);
    await openMenu(tester);

    // sono le voci che sul telefono non hanno un pulsante in barra
    expect(key('menu-tabs'), findsOneWidget);
    expect(key('menu-share'), findsOneWidget);
  });

  testWidgets('l\'importazione di una foto con misura e\' un sottomenu',
      (tester) async {
    phoneSize(tester);
    await pump(tester);
    await openMenu(tester);

    final group = key('menu-group-import');
    expect(group, findsOneWidget);
    expect(key('menu-import-auto'), findsNothing);
    await tester.ensureVisible(group);
    await tester.pumpAndSettle();
    await tester.tap(group);
    await tester.pumpAndSettle();
    for (final id in [
      'menu-import-auto',
      'menu-import-cards',
      'menu-import-passport',
      'menu-import-photoid',
      'menu-import-a4',
      'menu-import-other',
    ]) {
      expect(key(id), findsOneWidget, reason: id);
    }
  });

  testWidgets('la sola lettura e\' un interruttore nella tendina',
      (tester) async {
    phoneSize(tester);
    await pump(tester, withDoc: true);
    await openMenu(tester);

    final row = key('menu-read-only');
    expect(find.descendant(of: row, matching: find.byType(Switch)),
        findsOneWidget);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(PdfReader), findsOneWidget);
  });

  testWidgets('un tablet ha la stessa tendina', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, withDoc: true);
    await openMenu(tester);

    expect(key('app-menu-sheet'), findsNothing);
    expect(find.text('FILE'), findsOneWidget);
    expect(key('menu-group-import'), findsOneWidget);
  });
}
