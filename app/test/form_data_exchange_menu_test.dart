// The reference viewer exchange formats (FDF, XFDF, XDP) are wired into the DartPDF
// app menu when a document is open; the XDP open path turns a package into
// the PDF it embeds. Picking and saving need platform channels, so the menu
// tests stop at the wiring.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_finders.dart';

import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor/dart_pdf_editor.dart' hide PdfDocument;
import 'package:dart_pdf_editor_app/editor_screen.dart';

const _menuIds = [
  'menu-import-form-data',
  'menu-export-fdf',
  'menu-export-xfdf',
  'menu-export-xdp',
];

void main() {
  late PdfEditingPreferences prefs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefs = PdfEditingPreferences();
  });
  tearDown(() => prefs.dispose());

  Future<void> pumpWithForm(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EditorScreen(
        prefs: prefs,
        initialDocument: (bytes: buildAcroFormPdf(), title: 'Form.pdf'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void expectEntries() {
    for (final id in _menuIds) {
      expect(find.byKey(ValueKey(id)), findsOneWidget, reason: id);
    }
    expect(find.text('Import form data or comments…'), findsOneWidget);
    expect(find.text('Export form data as FDF…'), findsOneWidget);
    expect(find.text('Export form data as XFDF…'), findsOneWidget);
    expect(find.text('Export as XDP…'), findsOneWidget);
  }

  testWidgets('the menu lists form-data import and export in the Sign group',
      (tester) async {
    await pumpWithForm(tester);

    await tester.tap(find.byTooltip('DartPDF menu'));
    await tester.pumpAndSettle();

    // the group is folded: its rows are not built until it is opened
    expect(find.byKey(const ValueKey('app-menu-group-sign')), findsOneWidget);
    for (final id in _menuIds) {
      expect(find.byKey(ValueKey(id)), findsNothing, reason: id);
    }

    await expandMenuGroup(tester, 'sign');
    expectEntries();
  });

  testWidgets('the phone has the same form-data rows as the desktop',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpWithForm(tester);

    await openAppMenu(tester);
    expectEntries();
  });
}
