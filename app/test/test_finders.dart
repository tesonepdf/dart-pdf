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
Future<void> expandSettingsSections(WidgetTester tester) async {
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
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
  }
}
