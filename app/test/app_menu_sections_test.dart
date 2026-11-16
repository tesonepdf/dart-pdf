// The app menu is one accordion on every platform: a search row on top, then
// the macro-areas (File, Share, Print, Pages, Tools, Sign, View, App) that
// open and close, with read-only as a switch in the View group.
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
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

  Future<void> pump(WidgetTester tester, {bool withDoc = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: EditorScreen(
        prefs: prefs,
        initialDocument:
            withDoc ? (bytes: buildClassicPdf(), title: 'Report.pdf') : null,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder group(String id) => find.byKey(ValueKey('app-menu-group-$id'));

  testWidgets('a document open shows every macro-area, File already open',
      (tester) async {
    await pump(tester, withDoc: true);
    await tester.tap(find.byTooltip('DartPDF menu'));
    await tester.pumpAndSettle();

    for (final id in ['create', 'file', 'view', 'pages', 'tools', 'sign', 'export', 'share', 'app']) {
      expect(group(id), findsOneWidget, reason: id);
    }
    // File starts open, the others are folded: their rows are not built yet
    expect(find.byKey(const ValueKey('menu-new-document')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-print')), findsNothing);
    expect(find.byKey(const ValueKey('menu-settings')), findsNothing);

    await expandMenuGroup(tester, 'share');
    await expandMenuGroup(tester, 'app');
    expect(find.byKey(const ValueKey('menu-print')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-settings')), findsOneWidget);
  });

  testWidgets('with nothing open the document rows are not in the menu',
      (tester) async {
    await pump(tester);
    await openAppMenu(tester);

    expect(find.byKey(const ValueKey('menu-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-print')), findsNothing);
    expect(find.byKey(const ValueKey('menu-digital-signature')), findsNothing);
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('menu-new-document')))
          .enabled,
      isTrue,
    );
  });

  testWidgets('read-only is a switch in the View group', (tester) async {
    await pump(tester, withDoc: true);
    await openAppMenu(tester);

    final row = find.byKey(const ValueKey('menu-read-only'));
    expect(row, findsOneWidget);
    Switch switchOf() =>
        tester.widget<Switch>(find.descendant(of: row, matching: find.byType(Switch)));
    expect(switchOf().value, isFalse);

    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    // Read-only swaps the editor for the reader...
    expect(find.byType(PdfReader), findsOneWidget);
    // ...and the switch now reads back on.
    await openAppMenu(tester);
    expect(switchOf().value, isTrue);
  });

  testWidgets('the search row leads the menu and carries its shortcut',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(tester, withDoc: true);
      await tester.tap(find.byTooltip('DartPDF menu'));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('menu-command-palette')), findsOneWidget);
      expect(find.text('Search actions…'), findsOneWidget);
      expect(find.text('Ctrl+K'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
