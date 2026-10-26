// Phones use the same File, This document, and App menu sections as desktop,
// laid out as full-width touch rows instead of a popup.
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

  testWidgets('a phone gets the same menu sections and actions as desktop',
      (tester) async {
    phoneSize(tester);
    await pump(tester, withDoc: true);
    await openMenu(tester);

    expect(key('app-menu-sheet'), findsOneWidget);
    expect(find.text('FILE'), findsOneWidget);
    expect(find.text('THIS DOCUMENT'), findsOneWidget);
    expect(find.text('APP'), findsOneWidget);
    expect(key('menu-command-palette'), findsOneWidget);
    for (final id in [
      'menu-new-document',
      'menu-open',
      'menu-open-recent',
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
    expect(key('menu-group-export'), findsNothing);
    expect(key('menu-group-more-tools'), findsNothing);
    expect(tester.getTopLeft(find.text('FILE')).dy,
        lessThan(tester.getTopLeft(key('menu-new-document')).dy));
    expect(tester.getTopLeft(key('menu-new-document')).dy,
        lessThan(tester.getTopLeft(key('menu-open')).dy));
    expect(tester.getTopLeft(key('menu-open')).dy,
        lessThan(tester.getTopLeft(key('menu-open-recent')).dy));
    expect(tester.getTopLeft(key('menu-open-recent')).dy,
        lessThan(tester.getTopLeft(find.text('THIS DOCUMENT')).dy));
    expect(tester.getTopLeft(find.text('THIS DOCUMENT')).dy,
        lessThan(tester.getTopLeft(key('menu-save-as')).dy));
    expect(tester.getTopLeft(key('menu-compare')).dy,
        lessThan(tester.getTopLeft(find.text('APP')).dy));
    expect(tester.getTopLeft(find.text('APP')).dy,
        lessThan(tester.getTopLeft(key('menu-settings')).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Open Recent opens its page, and back returns to the menu',
      (tester) async {
    phoneSize(tester);
    await pump(tester, withDoc: true);
    await openMenu(tester);

    await tester.tap(key('menu-open-recent'));
    await tester.pumpAndSettle();
    expect(key('app-menu-sheet-recent'), findsOneWidget);
    expect(key('menu-recent-see-all'), findsOneWidget);
    expect(key('menu-no-recent-files'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(key('app-menu-sheet'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(key('app-menu-sheet'), findsNothing);
  });

  testWidgets('without a document only file and app actions remain',
      (tester) async {
    phoneSize(tester);
    await pump(tester);
    await openMenu(tester);

    expect(key('menu-new-document'), findsOneWidget);
    expect(key('menu-open'), findsOneWidget);
    expect(key('menu-open-recent'), findsOneWidget);
    expect(key('menu-print'), findsNothing);
    expect(key('menu-digital-signature'), findsNothing);
    expect(key('menu-group-export'), findsNothing);
    expect(key('menu-read-only'), findsNothing);
    expect(key('menu-settings'), findsOneWidget);
  });

  testWidgets('New asks blank or scan, then runs the pick', (tester) async {
    phoneSize(tester);
    await pump(tester, withScanner: true);
    await openMenu(tester);

    expect(key('menu-scan-document'), findsOneWidget);
    await tester.tap(key('menu-new-document'));
    await tester.pumpAndSettle();
    expect(key('app-menu-sheet-new'), findsNothing);
    expect(key('new-document-dialog'), findsOneWidget);
  });

  testWidgets('scan is directly available in the File section',
      (tester) async {
    phoneSize(tester);
    await pump(tester, withDoc: true, withScanner: true);
    await openMenu(tester);

    expect(key('menu-scan-document'), findsOneWidget);
    expect(key('menu-insert-scan'), findsOneWidget);
  });

  testWidgets('read-only is a switch in the sheet', (tester) async {
    phoneSize(tester);
    await pump(tester, withDoc: true);
    await openMenu(tester);

    final row = key('menu-read-only');
    expect(tester.getSemantics(row), isSemantics(isToggled: false));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(PdfReader), findsOneWidget);

    await openMenu(tester);
    expect(tester.getSemantics(row), isSemantics(isToggled: true));
  });

  testWidgets('a tablet-width touch screen keeps the popup', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, withDoc: true);
    await openMenu(tester);

    expect(key('app-menu-sheet'), findsNothing);
    expect(find.text('FILE'), findsOneWidget);
  });
}
