// La barra in basso (Home, Crea, File, Strumenti, Impostazioni): spenta di
// base, si accende dalle Impostazioni, ogni voce apre la cosa giusta.
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/bottom_bar_setting.dart';
import 'package:dart_pdf_editor_app/editor_screen.dart';

void main() {
  late PdfEditingPreferences prefs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BottomBarSetting.instance.value = false;
    prefs = PdfEditingPreferences();
  });
  tearDown(() {
    BottomBarSetting.instance.value = false;
    prefs.dispose();
  });

  Future<void> pumpWithDoc(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EditorScreen(
        prefs: prefs,
        initialDocument: (bytes: buildClassicPdf(), title: 'Report.pdf'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets('la barra e\' spenta di base', (tester) async {
    await pumpWithDoc(tester);

    expect(key('bottom-bar'), findsNothing);
  });

  testWidgets('accesa mostra le cinque voci', (tester) async {
    await pumpWithDoc(tester);

    await BottomBarSetting.instance.save(true);
    await tester.pumpAndSettle();

    expect(key('bottom-bar'), findsOneWidget);
    for (final id in ['home', 'create', 'file', 'tools', 'settings']) {
      expect(key('bottom-bar-$id'), findsOneWidget, reason: id);
    }
  });

  testWidgets('Crea apre la schermata Crea con le sue azioni', (tester) async {
    await pumpWithDoc(tester);
    await BottomBarSetting.instance.save(true);
    await tester.pumpAndSettle();

    await tester.tap(key('bottom-bar-create'));
    await tester.pumpAndSettle();

    expect(key('create-screen'), findsOneWidget);
    expect(key('create-action-new-document'), findsOneWidget);
    expect(key('create-action-save-as'), findsNothing);
  });

  testWidgets('Strumenti apre la schermata Strumenti', (tester) async {
    await pumpWithDoc(tester);
    await BottomBarSetting.instance.save(true);
    await tester.pumpAndSettle();

    await tester.tap(key('bottom-bar-tools'));
    await tester.pumpAndSettle();

    expect(key('tools-screen'), findsOneWidget);
    expect(key('tools-tab-all'), findsOneWidget);
    expect(key('tool-new-document'), findsOneWidget);
  });

  testWidgets('Home apre la schermata Home', (tester) async {
    await pumpWithDoc(tester);
    await BottomBarSetting.instance.save(true);
    await tester.pumpAndSettle();

    await tester.tap(key('bottom-bar-home'));
    await tester.pumpAndSettle();

    expect(key('home-screen'), findsOneWidget);
    expect(find.text('Cosa vorresti fare?'), findsOneWidget);
  });

  testWidgets('Impostazioni apre le impostazioni con l\'interruttore',
      (tester) async {
    await pumpWithDoc(tester);
    await BottomBarSetting.instance.save(true);
    await tester.pumpAndSettle();

    await tester.tap(key('bottom-bar-settings'));
    await tester.pumpAndSettle();
    final toggle = key('settings-bottom-bar');
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(BottomBarSetting.instance.value, isFalse);
  });
}
