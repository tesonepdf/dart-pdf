// TEMPORANEO: diagnosi dei test di rinomina. Fallisce di proposito per scrivere
// nella CI i numeri misurati. Da togliere appena capita la causa.
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/editor_screen.dart';
import 'package:dart_pdf_editor_app/unsaved_changes.dart';

void main() {
  late PdfEditingPreferences prefs;
  late InMemoryUnsavedChangesStore recovery;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefs = PdfEditingPreferences();
    recovery = InMemoryUnsavedChangesStore();
  });
  tearDown(() => prefs.dispose());

  testWidgets('zz DBG rename', (tester) async {
    final out = <String>[];
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: EditorScreen(
        prefs: prefs,
        unsavedChangesStore: recovery,
        initialDocument: (bytes: buildClassicPdf(), title: 'Original.pdf'),
      ),
    ));
    await tester.pumpAndSettle();

    out.add('platform=${defaultTargetPlatform.name}');
    out.add('title='
        '${find.byKey(const ValueKey('mobile-document-title')).evaluate().length}');
    out.add('menuBtn=${find.byTooltip('DartPDF menu').evaluate().length}');
    out.add('tabsBtn='
        '${find.byKey(const ValueKey('mobile-tabs-button')).evaluate().length}');
    out.add('saveBtn='
        '${find.byKey(const ValueKey('pdf-shell-save')).evaluate().length}');
    out.add('progress='
        '${find.byType(CircularProgressIndicator).evaluate().length}');
    out.add('appBars=${find.byType(AppBar).evaluate().length}');
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .where((t) => t.trim().isNotEmpty)
        .take(14)
        .toList();
    out.add('texts=${texts.join(',')}');
    final tips = find
        .byWidgetPredicate((w) => w is Tooltip && w.message != null)
        .evaluate()
        .map((e) => (e.widget as Tooltip).message)
        .take(14)
        .toList();
    out.add('tooltips=${tips.join(',')}');
    fail('DBG ${out.join(' | ')}');
  });
}
