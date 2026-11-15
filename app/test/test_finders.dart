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

/// Opens every collapsible section card, so tests can find the controls inside.
Future<void> expandSettingsSections(WidgetTester tester,
    {bool settle = true}) async {
  final sections = find.byWidgetPredicate((w) =>
      w is ExpansionTile &&
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('settings-section-'));
  final count = sections.evaluate().length;
  for (var i = 0; i < count; i++) {
    final section = sections.at(i);
    await tester.ensureVisible(section);
    settle
        ? await tester.pumpAndSettle()
        : await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(section);
    settle
        ? await tester.pumpAndSettle()
        : await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Opens the app menu and unfolds every group, so a test can find any row.
/// The menu is the same accordion on every platform (macro-areas that open
/// and close); afterwards it is scrolled back to the top, so the search row
/// and the first rows can be tapped directly.
Future<void> openAppMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('DartPDF menu'));
  await tester.pumpAndSettle();
  await expandMenuGroups(tester);
  final search = find.byKey(const ValueKey('menu-command-palette'));
  if (search.evaluate().isNotEmpty) {
    await tester.ensureVisible(search);
    await tester.pumpAndSettle();
  }
}

/// Taps an item of the app menu. A group that is still folded is unfolded
/// first, and the item is scrolled into view: the menu grows with every
/// feature, so in the 800x600 test window an item near the bottom can sit
/// below the fold, where a plain tap misses.
Future<void> tapMenuText(WidgetTester tester, String text) async {
  var item = find.text(text);
  if (item.evaluate().isEmpty) {
    await expandMenuGroups(tester);
    item = find.text(text);
  }
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
}

/// Taps a keyed app-menu item after unfolding its group and scrolling it
/// into view.
Future<void> tapMenuKey(WidgetTester tester, String key) async {
  var item = find.byKey(ValueKey(key));
  if (item.evaluate().isEmpty) {
    await expandMenuGroups(tester);
    item = find.byKey(ValueKey(key));
  }
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
}

/// Opens one folded group of the app menu ("file", "share", "print", "pages",
/// "tools", "sign", "view", "app", "other"), so a test can find its rows.
/// A group that is already open is left as it is (File starts open).
Future<void> expandMenuGroup(WidgetTester tester, String id) async {
  final group = find.byKey(ValueKey('app-menu-group-$id'));
  if (group.evaluate().isEmpty) return;
  final tiles = find.descendant(of: group, matching: find.byType(ListTile));
  // a folded group only has its header; an open one has its rows as well
  if (tiles.evaluate().length > 1) return;
  final header = tiles.first;
  await tester.ensureVisible(header);
  await tester.pumpAndSettle();
  await tester.tap(header);
  await tester.pumpAndSettle();
}

/// Opens every folded group of the app menu.
Future<void> expandMenuGroups(WidgetTester tester) async {
  for (final id in [
    'file',
    'share',
    'print',
    'pages',
    'tools',
    'sign',
    'view',
    'app',
    'other',
  ]) {
    await expandMenuGroup(tester, id);
  }
}
