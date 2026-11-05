import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_pdf_editor_app/middle_ellipsis_text.dart';
export 'package:dart_pdf_editor_app/middle_ellipsis_text.dart'
    show MiddleEllipsisText;

/// Finds the filename widget by its complete source value, regardless of the
/// centre-ellipsized text currently painted for its layout width.
Finder findMiddleEllipsisText(String value) => find.byWidgetPredicate(
      (widget) => widget is MiddleEllipsisText && widget.data == value,
    );

/// Opens every collapsible section of the Settings dialog, so the tests can
/// find the controls inside them.
Future<void> expandSettingsSections(WidgetTester tester,
    {bool settle = true}) async {
  final sections = find.byWidgetPredicate((w) =>
      w is ExpansionTile &&
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('settings-section-'));
  final count = sections.evaluate().length;
  for (var i = 0; i < count; i++) {
    final header = find
        .descendant(of: sections.at(i), matching: find.byType(ListTile))
        .first;
    await tester.ensureVisible(header);
    settle
        ? await tester.pumpAndSettle()
        : await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(header);
    settle
        ? await tester.pumpAndSettle()
        : await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Taps an item of the app menu. The menu grows with every feature and its
/// popup scrolls, so in the 800x600 test window an item near the bottom
/// ("Settings", "Updates") can sit below the fold, where a plain tap misses.
Future<void> tapMenuText(WidgetTester tester, String text) async {
  final item = find.text(text);
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
}
