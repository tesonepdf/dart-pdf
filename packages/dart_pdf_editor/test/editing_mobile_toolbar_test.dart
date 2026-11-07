import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The phone layout: the dock at the bottom holds undo/redo and the actions of
// a selection; the active-tool control sits in the host's header and opens the
// tools sheet; the colour swatches are not in the dock (colour is chosen in the
// tools sheet).
void main() {
  final swatch = find.byKey(const ValueKey('pdf-mobile-swatch-0'));
  final currentTool = find.byKey(const ValueKey('pdf-mobile-current-tool'));
  // the tool's name as the control shows it (the header gives it 100px)
  Finder toolName(String name) =>
      find.descendant(of: currentTool, matching: find.textContaining(name));

  // [headerWidth] is the width the host gives the active-tool control (the app
  // uses 100 on a phone, 52 while its search field is open).
  Future<PdfEditingController> pumpToolbar(WidgetTester tester,
      {Uint8List? bytes,
      double width = 380,
      double headerWidth = 100}) async {
    SharedPreferences.setMockInitialValues({});
    final editing =
        PdfEditingController(bytes ?? buildAppearanceAnnotationsPdf());
    final viewer = PdfViewerController();
    final commands =
        PdfEditorCommands(controller: editing, viewerController: viewer);
    addTearDown(commands.dispose);
    addTearDown(editing.dispose);
    addTearDown(viewer.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PdfEditorCommandsScope(
          commands: commands,
          // a width under the 600px mobile breakpoint forces the dock layout
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // what the app's header does with the toolbar's control
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: headerWidth,
                      child: ListenableBuilder(
                        listenable: Listenable.merge([commands, editing]),
                        builder: (context, _) {
                          final build = commands.currentToolBuilder;
                          return build == null
                              ? const SizedBox.shrink()
                              : build(context);
                        },
                      ),
                    ),
                  ),
                  PdfEditingToolbar(
                      controller: editing, viewerController: viewer),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    // the toolbar announces its control after its first frame
    await tester.pump();
    return editing;
  }

  Future<void> openToolsSheet(WidgetTester tester) async {
    await tester.tap(currentTool);
    await tester.pumpAndSettle();
  }

  test('toolUsesColor: true for painters, false for colourless tools', () {
    SharedPreferences.setMockInitialValues({});
    final c = PdfEditingController(buildAppearanceAnnotationsPdf());
    addTearDown(c.dispose);

    for (final tool in [
      PdfEditTool.ink,
      PdfEditTool.highlight,
      PdfEditTool.rectangle,
      PdfEditTool.line,
      PdfEditTool.freeText,
      PdfEditTool.stamp,
      PdfEditTool.measureDistance,
    ]) {
      c.tool = tool;
      expect(c.toolUsesColor, isTrue, reason: '$tool paints in colour');
    }
    for (final tool in [PdfEditTool.eraser, PdfEditTool.form]) {
      c.tool = tool;
      expect(c.toolUsesColor, isFalse, reason: '$tool ignores colour');
    }
    c.tool = null;
    expect(c.toolUsesColor, isFalse, reason: 'select ignores colour');
    c.markupTool = PdfMarkupKind.highlight;
    expect(c.toolUsesColor, isTrue, reason: 'text markup paints in colour');
  });

  testWidgets('the dock carries no colour swatches', (tester) async {
    final editing = await pumpToolbar(tester);

    expect(swatch, findsNothing, reason: 'resting in Hand mode');

    editing.tool = PdfEditTool.eraser;
    await tester.pump();
    expect(swatch, findsNothing, reason: 'the eraser ignores colour');

    editing.tool = PdfEditTool.ink;
    await tester.pump();
    expect(swatch, findsNothing,
        reason: 'ink paints in colour, chosen in the tools sheet');
  });

  testWidgets('active tool control fits a narrow header', (tester) async {
    final editing = await pumpToolbar(tester, width: 320, headerWidth: 52);

    editing.tool = PdfEditTool.note;
    await tester.pump();

    expect(currentTool, findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'the tool control must not overflow a narrow header');
  });

  testWidgets('dismissing the tools sheet keeps the selected tool',
      (tester) async {
    final editing = await pumpToolbar(tester);
    await openToolsSheet(tester);
    final shapes = find.byKey(const ValueKey('pdf-group-tab-shapes'));
    await tester.ensureVisible(shapes);
    await tester.tap(shapes);
    await tester.pumpAndSettle();
    expect(editing.tool, PdfEditTool.rectangle);

    Navigator.of(tester.element(shapes)).pop();
    await tester.pumpAndSettle();
    expect(shapes, findsNothing);
    expect(editing.tool, PdfEditTool.rectangle);
    expect(find.byKey(const ValueKey('pdf-undo')), findsOneWidget);
  });

  testWidgets('current tool control names the tool and opens the tools sheet',
      (tester) async {
    final editing = await pumpToolbar(tester, width: 500);

    editing.tool = PdfEditTool.select;
    await tester.pump();
    editing.tool = PdfEditTool.ink;
    await tester.pump();
    editing.tool = PdfEditTool.rectangle;
    await tester.pump();

    expect(toolName('Rectangle'), findsOneWidget);

    await openToolsSheet(tester);
    expect(find.byKey(const ValueKey('pdf-group-tab-shapes')), findsOneWidget);
    expect(editing.tool, PdfEditTool.rectangle,
        reason: 'opening the sheet does not change the tool');
  });

  testWidgets('armed markup is the current tool', (tester) async {
    final editing = await pumpToolbar(tester, width: 500);
    editing.markupTool = PdfMarkupKind.highlight;
    await tester.pump();

    expect(toolName('Highlight'), findsOneWidget);
    expect(editing.tool, isNull,
        reason: 'markup keeps native text-selection gestures enabled');
  });

  testWidgets('Hand is the resting tool and is visibly distinct',
      (tester) async {
    final editing = await pumpToolbar(tester, width: 590);
    expect(toolName('Hand'), findsOneWidget);
    expect(
        find.descendant(
            of: currentTool, matching: find.byIcon(Icons.pan_tool_alt)),
        findsOneWidget,
        reason: 'the Hand navigation mode is visibly distinct from Select');

    editing.tool = PdfEditTool.note;
    await tester.pump();
    final surface =
        find.byKey(const ValueKey('pdf-mobile-current-tool-surface'));
    expect(find.byKey(const ValueKey('pdf-mobile-clear-tool')), findsNothing);
    expect(tester.getRect(currentTool), tester.getRect(surface),
        reason: 'the tap target fills the entire shaded tool surface');
  });

  testWidgets('Select group offers Hand and Select modes', (tester) async {
    final editing = await pumpToolbar(tester);

    await openToolsSheet(tester);
    await tester.tap(find.byKey(const ValueKey('pdf-group-tab-select')));
    await tester.pumpAndSettle();

    final hand = find.byKey(const ValueKey('pdf-sheet-mode-hand'));
    final select = find.byKey(const ValueKey('pdf-sheet-mode-select'));
    expect(hand, findsOneWidget);
    expect(select, findsOneWidget);
    expect(editing.tool, isNull);

    await tester.tap(hand);
    await tester.pumpAndSettle();
    expect(editing.tool, isNull);
    expect(editing.isHandMode, isTrue);
    expect(hand, findsNothing, reason: 'choosing a mode closes the sheet');

    await openToolsSheet(tester);
    await tester.tap(find.byKey(const ValueKey('pdf-group-tab-select')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pdf-sheet-mode-hand')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pdf-sheet-mode-select')));
    await tester.pumpAndSettle();
    expect(editing.tool, PdfEditTool.select);
    expect(editing.isHandMode, isFalse);
    expect(find.byKey(const ValueKey('pdf-sheet-mode-select')), findsNothing);
  });

  testWidgets('Select group remains available from another armed tool',
      (tester) async {
    final editing = await pumpToolbar(tester);

    Future<void> chooseSelect() async {
      await openToolsSheet(tester);
      final selectGroup = find.byKey(const ValueKey('pdf-group-tab-select'));
      expect(selectGroup, findsOneWidget);

      await tester.tap(selectGroup);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pdf-sheet-mode-select')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pdf-sheet-mode-select')));
      await tester.pumpAndSettle();
      expect(editing.tool, PdfEditTool.select);
      expect(toolName('Select'), findsOneWidget);
      expect(
          find.descendant(of: currentTool, matching: find.byIcon(Icons.near_me)),
          findsOneWidget,
          reason: 'Select keeps its arrow instead of looking like Hand');
      expect(
          find.descendant(
              of: currentTool, matching: find.byIcon(Icons.pan_tool_alt)),
          findsNothing);
      expect(selectGroup, findsNothing,
          reason: 'choosing a mode closes the sheet');
    }

    expect(editing.tool, isNull);
    await chooseSelect();

    editing.tool = PdfEditTool.ink;
    await tester.pump();
    await chooseSelect();
  });

  testWidgets('a selection surfaces quick actions in the dock',
      (tester) async {
    final editing = await pumpToolbar(tester);
    editing.tool = PdfEditTool.ink;
    await tester.pump();
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    // slot 0 is the Square annotation - selectable, unlike the Link/Widget
    // entries the link fixture carries; selecting arms the select tool
    expect(editing.selectAnnotation(0, 0), isTrue);
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget,
        reason: 'a selected annotation can be deleted from the dock');

    // and the action works: tapping it removes the annotation
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(editing.hasAnnotationSelection, isFalse);
    expect(editing.isModified, isTrue, reason: 'the annotation was removed');
  });

  testWidgets('a selected form field exposes its mobile toolbar controls',
      (tester) async {
    final editing = await pumpToolbar(tester, bytes: buildAcroFormPdf());
    expect(editing.selectFormWidgetAt(0, 186, 712), isTrue);
    await tester.pump();

    expect(
        find.byKey(const ValueKey('pdf-selected-form-more')), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'the field controls fit the 380px mobile dock');

    await tester.tap(find.byKey(const ValueKey('pdf-selected-form-more')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('pdf-selected-form-edit')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('pdf-selected-form-rename')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('pdf-selected-form-style')), findsOneWidget);
    expect(find.byKey(const ValueKey('pdf-selected-form-type-text')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('pdf-selected-form-type-checkbox')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('pdf-selected-form-type-button')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('pdf-selected-form-delete')), findsOneWidget);
    expect(find.byKey(const ValueKey('pdf-selected-form-flatten')),
        findsOneWidget);
  });

  testWidgets('a selected content element surfaces mobile edit actions',
      (tester) async {
    final editing = await pumpToolbar(tester, bytes: buildMultiPagePdf(1));
    editing.tool = PdfEditTool.content;
    expect(editing.selectElementAt(0, 80, 725), isTrue);
    await tester.pump();

    expect(find.byKey(const ValueKey('pdf-mobile-delete-element')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('pdf-replace-element-text')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('pdf-reflow-element-text')), findsOneWidget);
    expect(swatch, findsNothing,
        reason: 'content element actions take precedence over swatches');

    await tester.tap(find.byKey(const ValueKey('pdf-mobile-delete-element')));
    await tester.pump();
    expect(editing.selectedElement, isNull);
    expect(editing.elementsOn(0).elements, isEmpty);
  });
}
