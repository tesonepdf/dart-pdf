// TEMPORANEO: diagnosi dei test delle Impostazioni. Fallisce di proposito per
// scrivere nella CI i numeri misurati. Da togliere appena capita la causa.
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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

  testWidgets('zz DBG settings', (tester) async {
    final out = <String>[];
    await tester.pumpWidget(MaterialApp(home: EditorScreen(prefs: prefs)));
    await tester.pump();
    out.add('size=${tester.view.physicalSize.width.round()}x'
        '${tester.view.physicalSize.height.round()}');

    await tester.tap(find.byTooltip('DartPDF menu'));
    await tester.pumpAndSettle();
    out.add('menuSettings=${find.text('Settings').evaluate().length}');
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    out.add('dialog=${find.byType(Dialog).evaluate().length}'
        ' alert=${find.byType(AlertDialog).evaluate().length}');
    final sections = find.byWidgetPredicate((w) =>
        w is ExpansionTile &&
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('settings-section-'));
    out.add('tiles=${find.byType(ExpansionTile).evaluate().length}'
        ' sections=${sections.evaluate().length}');
    if (sections.evaluate().isNotEmpty) {
      final first = sections.first;
      out.add('s0:listTiles='
          '${find.descendant(of: first, matching: find.byType(ListTile)).evaluate().length}'
          ' inkwells='
          '${find.descendant(of: first, matching: find.byType(InkWell)).evaluate().length}'
          ' texts='
          '${find.descendant(of: first, matching: find.byType(Text)).evaluate().length}');
    }
    out.add('langBefore='
        '${find.byKey(const ValueKey('settings-language')).evaluate().length}');

    try {
      await expandSettingsSections(tester);
      out.add('expand=ok');
    } catch (e) {
      out.add('expand=ERR ${e.runtimeType}');
    }
    out.add('langAfter='
        '${find.byKey(const ValueKey('settings-language')).evaluate().length}'
        ' defApp='
        '${find.byKey(const ValueKey('settings-default-app')).evaluate().length}'
        ' title1='
        '${find.text('ASPETTO E LINGUA').evaluate().length}');
    final ex = tester.takeException();
    if (ex != null) out.add('exception=${ex.runtimeType}');

    // Tocco diretto sul titolo della prima sezione.
    final title = find.text('ASPETTO E LINGUA');
    if (title.evaluate().isNotEmpty) {
      await tester.tap(title.first);
      await tester.pumpAndSettle();
      out.add('afterTitleTap lang='
          '${find.byKey(const ValueKey('settings-language')).evaluate().length}');
    }
    fail('DBG ${out.join(' | ')}');
  });
}
