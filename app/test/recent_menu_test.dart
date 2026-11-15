import 'dart:convert';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: EditorScreen(prefs: prefs)));
    await tester.pump();
    await tester.pump();
  }

  String shortcut(String key, {bool shift = false}) {
    final apple = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return apple
        ? '${shift ? '⇧' : ''}⌘$key'
        : 'Ctrl+${shift ? 'Shift+' : ''}$key';
  }

  void seedRecents() {
    SharedPreferences.setMockInitialValues({
      'dart_pdf_editor_app.recents': jsonEncode([
        {
          't': 'alpha.pdf',
          'p': '/docs/alpha.pdf',
          'o': 2000,
        },
        {
          't': 'beta.pdf',
          'p': '/docs/beta.pdf',
          'o': 1000,
        },
      ]),
    });
  }

  testWidgets('the menu shows Open and the recent files under "Recenti"',
      (tester) async {
    seedRecents();
    await pumpApp(tester);

    await openAppMenu(tester);

    expect(find.byKey(const ValueKey('menu-open')), findsOneWidget);
    expect(find.text('Open a PDF…'), findsOneWidget);
    expect(find.text('Recenti'), findsOneWidget);
    expect(find.text(shortcut('O')), findsOneWidget);
    expect(find.text(shortcut('O', shift: true)), findsOneWidget);

    expect(findMiddleEllipsisText('alpha.pdf'), findsWidgets);
    expect(findMiddleEllipsisText('beta.pdf'), findsWidgets);
    expect(
      find.byKey(const ValueKey('view-all-recent-files')),
      findsOneWidget,
    );
    expect(find.text('Clear recent files'), findsWidgets);
  });

  testWidgets('"View all" opens the full searchable recent-files browser',
      (tester) async {
    seedRecents();
    await pumpApp(tester);

    await openAppMenu(tester);
    await tapMenuKey(tester, 'view-all-recent-files');
    await tester.pumpAndSettle();

    expect(find.text('Recent files'), findsOneWidget);
    final search = find.byKey(const ValueKey('recent-files-search'));
    expect(search, findsOneWidget);

    await tester.enterText(search, 'BETA');
    await tester.pump();

    expect(find.byKey(const ValueKey('recent-tile-/docs/beta.pdf')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('recent-tile-/docs/alpha.pdf')),
        findsNothing);
  });

  testWidgets('with no recent files "View all" stays but cannot be used',
      (tester) async {
    await pumpApp(tester);

    await openAppMenu(tester);

    final viewAll = find.byKey(const ValueKey('view-all-recent-files'));
    expect(viewAll, findsOneWidget);
    expect(tester.widget<ListTile>(viewAll).enabled, isFalse);
    expect(find.text('Clear recent files'), findsNothing);
  });
}
