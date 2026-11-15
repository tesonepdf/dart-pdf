// Il telefono ha lo stesso menu di PC, web e Mac: un'unica fisarmonica con la
// ricerca in cima e le macroaree che si aprono e si chiudono. Qui si prova a
// dimensione di telefono e di tablet.
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/editor_screen.dart';
import 'test_finders.dart';

void main() {
  late PdfEditingPreferences prefs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefs = PdfEditingPreferences();
  });
  tearDown(() => prefs.dispose());

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
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

  Finder key(String value) => find.byKey(ValueKey(value));
  Finder group(String id) => key('app-menu-group-$id');

  testWidgets('il telefono ha le macroaree, File aperto e le altre chiuse',
      (tester) async {
    setSize(tester, const Size(390, 844));
    await pump(tester, withDoc: true);
    await tester.tap(find.byTooltip('DartPDF menu'));
    await tester.pumpAndSettle();

    expect(key('menu-command-palette'), findsOneWidget);
    for (final id in ['file', 'print', 'pages', 'tools', 'sign', 'view', 'app']) {
      expect(group(id), findsOneWidget, reason: id);
    }
    // File e' aperto, le altre macroaree no
    expect(key('menu-new-document'), findsOneWidget);
    expect(key('menu-save-as'), findsOneWidget);
    expect(key('menu-print'), findsNothing);
    expect(key('menu-digital-signature'), findsNothing);

    // si aprono e si chiudono toccando il titolo
    await expandMenuGroup(tester, 'print');
    expect(key('menu-print'), findsOneWidget);
    await tester.tap(
        find.descendant(of: group('print'), matching: find.byType(ListTile)).first);
    await tester.pumpAndSettle();
    expect(key('menu-print'), findsNothing);
  });

  testWidgets('aperte tutte, ci sono le voci di File, Stampa, Pagine e Firma',
      (tester) async {
    setSize(tester, const Size(390, 844));
    await pump(tester, withDoc: true);
    await openAppMenu(tester);

    for (final id in [
      'menu-new-document',
      'menu-open',
      'menu-photos-one-sheet',
      'menu-photos-to-pdf',
      'menu-open-comic',
      'menu-open-epub',
      'menu-compose-sheet',
      'menu-save-as',
      'menu-reduce-file-size',
      'menu-print',
      'menu-export-image',
      'menu-insert-document',
      'menu-compare',
      'menu-digital-signature',
      'menu-read-only',
      'menu-settings',
    ]) {
      expect(key(id), findsOneWidget, reason: id);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('senza documento le voci del documento restano ma spente',
      (tester) async {
    setSize(tester, const Size(390, 844));
    await pump(tester);
    await openAppMenu(tester);

    expect(tester.widget<ListTile>(key('menu-new-document')).enabled, isTrue);
    expect(tester.widget<ListTile>(key('menu-open')).enabled, isTrue);
    expect(tester.widget<ListTile>(key('menu-print')).enabled, isFalse);
    expect(tester.widget<ListTile>(key('menu-digital-signature')).enabled,
        isFalse);
    expect(key('menu-read-only'), findsNothing);
    expect(key('menu-settings'), findsOneWidget);
  });

  testWidgets('Nuovo apre la scelta e lo scanner e\' in File', (tester) async {
    setSize(tester, const Size(390, 844));
    await pump(tester, withScanner: true);
    await tester.tap(find.byTooltip('DartPDF menu'));
    await tester.pumpAndSettle();

    expect(key('menu-scan-document'), findsOneWidget);
    await tester.tap(key('menu-new-document'));
    await tester.pumpAndSettle();
    expect(key('new-document-dialog'), findsOneWidget);
  });

  testWidgets('lo scanner e\' in File e Inserisci scansione in Pagine',
      (tester) async {
    setSize(tester, const Size(390, 844));
    await pump(tester, withDoc: true, withScanner: true);
    await openAppMenu(tester);

    expect(key('menu-scan-document'), findsOneWidget);
    expect(key('menu-insert-scan'), findsOneWidget);
  });

  testWidgets('sul telefono restano Schede aperte e Condividi',
      (tester) async {
    setSize(tester, const Size(390, 844));
    await pump(tester, withDoc: true);
    await openAppMenu(tester);

    // sono le voci che sul telefono non hanno un pulsante in barra
    expect(key('menu-tabs'), findsOneWidget);
    expect(key('menu-share'), findsOneWidget);
  });

  testWidgets('importare una foto con misura e\' un blocco di File',
      (tester) async {
    setSize(tester, const Size(390, 844));
    await pump(tester);
    await tester.tap(find.byTooltip('DartPDF menu'));
    await tester.pumpAndSettle();

    expect(find.text('Importa foto con misura'), findsOneWidget);
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

  testWidgets('la sola lettura e\' un interruttore in Visualizza',
      (tester) async {
    setSize(tester, const Size(390, 844));
    await pump(tester, withDoc: true);
    await openAppMenu(tester);

    final row = key('menu-read-only');
    expect(find.descendant(of: row, matching: find.byType(Switch)),
        findsOneWidget);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(PdfReader), findsOneWidget);
  });

  testWidgets('Visualizza ha i pannelli e le opzioni di vista con interruttore',
      (tester) async {
    setSize(tester, const Size(390, 844));
    await pump(tester, withDoc: true);
    await openAppMenu(tester);

    expect(find.text('Pannelli'), findsOneWidget);
    expect(find.text('Opzioni di vista'), findsOneWidget);
    expect(key('panel-pages'), findsOneWidget);
    expect(
        find.descendant(of: key('panel-pages'), matching: find.byType(Switch)),
        findsOneWidget);
    expect(key('view-two-page'), findsOneWidget);
  });

  testWidgets('un tablet e un PC hanno lo stesso menu', (tester) async {
    setSize(tester, const Size(1024, 768));
    await pump(tester, withDoc: true);
    await tester.tap(find.byTooltip('DartPDF menu'));
    await tester.pumpAndSettle();

    expect(key('menu-command-palette'), findsOneWidget);
    for (final id in ['file', 'print', 'pages', 'tools', 'sign', 'view', 'app']) {
      expect(group(id), findsOneWidget, reason: id);
    }
    expect(find.text('Importa foto con misura'), findsOneWidget);
  });
}
