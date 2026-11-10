import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:dart_pdf_editor/src/editing/editing_overlay.dart';
import 'package:pdf_document/pdf_document.dart' show PdfRect;
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';
import 'package:shared_preferences/shared_preferences.dart';

dynamic cursorPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.descendant(
      of: find.byType(EditingPageOverlay),
      matching: find.byType(CustomPaint),
    ))
    .map((paint) => paint.painter)
    .singleWhere(
      (painter) => painter.runtimeType.toString() == '_HoverCursorPainter',
    );

dynamic gridPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.descendant(
      of: find.byType(EditingPageOverlay),
      matching: find.byType(CustomPaint),
    ))
    .map((paint) => paint.painter)
    .singleWhere(
      (painter) => painter.runtimeType.toString() == '_SnapGridPainter',
    );

dynamic alignmentPainter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byKey(
      const ValueKey('pdf-alignment-guides'),
    ))
    .painter;

dynamic rulerPainter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byKey(
      const ValueKey('pdf-page-rulers'),
    ))
    .painter;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // 800px viewport over a 612x792pt page at fit-width.
  const scale = 800 / 612;
  Offset view(double x, double y) => Offset(x * scale, (792 - y) * scale);

  Future<PdfEditingController> pumpEditor(WidgetTester tester) async {
    final editing = PdfEditingController(buildMultiPagePdf(1));
    final viewer = PdfViewerController();
    // prima si smonta la schermata, poi si eliminano i controller
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      editing.dispose();
      viewer.dispose();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: editing,
          builder: (context, _) => PdfViewer(
            initialFit: PdfViewerFit.width,
            document: editing.document,
            controller: viewer,
            editing: editing,
          ),
        ),
      ),
    ));
    await tester.pump();
    return editing;
  }

  Future<void> dragMouse(WidgetTester tester, Offset from, Offset to) async {
    final gesture =
        await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
    await gesture.moveTo(to);
    await gesture.up();
    await tester.pump();
  }

  testWidgets('horizontal and vertical cursor guides follow page hover',
      (tester) async {
    final editing = await pumpEditor(tester);
    editing.preferences
      ..showVerticalCursorGuide = true
      ..showHorizontalCursorGuide = true;
    await tester.pump();

    // Guides alone mount a passive editing overlay even with no tool or
    // annotation selection.
    expect(editing.tool, isNull);
    expect(find.byType(EditingPageOverlay), findsWidgets);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(5, 5));
    addTearDown(gesture.removePointer);
    await gesture.moveTo(view(220, 700));
    await tester.pump();

    final painter = cursorPainter(tester);
    expect(painter.verticalGuide, isTrue);
    expect(painter.horizontalGuide, isTrue);
    expect(painter.guideStrokeWidth, 0.75);
    expect(painter.guideHaloWidth, 1.75);
    expect(painter.guideCursor.dx, closeTo(view(220, 700).dx, 0.1));
    expect(painter.guideCursor.dy, closeTo(view(220, 700).dy, 0.1));

    await gesture.moveTo(const Offset(-30, -30));
    await tester.pump();
    expect(cursorPainter(tester).guideCursor, isNull);
  });

  testWidgets('cursor guides stay on a still mouse while the page scrolls',
      (tester) async {
    final editing = await pumpEditor(tester);
    editing.preferences
      ..showVerticalCursorGuide = true
      ..showHorizontalCursorGuide = true;
    await tester.pump();

    const pointer = Offset(300, 300);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(5, 5));
    addTearDown(gesture.removePointer);
    await gesture.moveTo(pointer);
    await tester.pump();

    final overlay = find.byType(EditingPageOverlay).first;
    Offset pageTop() => tester.getTopLeft(overlay);
    final topBefore = pageTop();
    expect(cursorPainter(tester).guideCursor, pointer - topBefore);

    // wheel-scroll without moving the mouse: no hover event arrives
    tester.binding.handlePointerEvent(const PointerScrollEvent(
      kind: PointerDeviceKind.mouse,
      position: pointer,
      scrollDelta: Offset(0, 120),
    ));
    await tester.pumpAndSettle();

    final topAfter = pageTop();
    expect(topAfter.dy, lessThan(topBefore.dy), reason: 'the page scrolled');
    final cursor = cursorPainter(tester).guideCursor as Offset;
    expect(cursor.dx, closeTo((pointer - topAfter).dx, 0.1));
    expect(cursor.dy, closeTo((pointer - topAfter).dy, 0.1),
        reason: 'the guides track the pointer, not the scrolled content');
  });

  testWidgets('visible snap grid follows the page-space snapping interval',
      (tester) async {
    final editing = await pumpEditor(tester);
    editing.preferences
      ..gridSpacing = 25
      ..showSnapGrid = true;
    await tester.pump();

    // A visible grid alone mounts the otherwise passive overlay. It does not
    // require snapping or an editing tool to be enabled.
    expect(editing.tool, isNull);
    expect(editing.preferences.snapToGrid, isFalse);
    expect(find.byKey(const ValueKey('pdf-snap-grid')), findsWidgets);
    final painter = gridPainter(tester);
    expect(painter.gridSpacing, 25);
    expect(painter.strokeWidth, 0.5);

    final paint = find.byKey(const ValueKey('pdf-snap-grid')).first;
    final segments = List<dynamic>.from(
        painter.segmentsFor(tester.getSize(paint)) as Iterable);
    expect(
      segments.any((segment) =>
          (segment.$1 - view(100, 0)).distance < 0.1 &&
          (segment.$2 - view(100, 792)).distance < 0.1),
      isTrue,
      reason: 'the x=100pt grid line should span the crop box',
    );
  });

  testWidgets('creation, movement and resizing are free: no grid, no guides',
      (tester) async {
    final editing = await pumpEditor(tester);
    // even with the old preferences switched on, nothing snaps any more
    editing.preferences
      ..gridSpacing = 25
      ..snapToGrid = true
      ..smartAlignmentGuides = true;
    editing.tool = PdfEditTool.rectangle;
    await tester.pump();

    await dragMouse(tester, view(103, 703), view(247, 612));
    var rect = editing.document.page(0).annotations.single.rect;
    expect(rect.left, closeTo(103, 0.5));
    expect(rect.bottom, closeTo(612, 0.5));
    expect(rect.right, closeTo(247, 0.5));
    expect(rect.top, closeTo(703, 0.5));

    editing
      ..tool = PdfEditTool.select
      ..selectAnnotation(0, 0);
    await tester.pump();

    await dragMouse(tester, view(175, 650), view(188, 633));
    rect = editing.document.page(0).annotations.single.rect;
    expect(rect.left, closeTo(116, 0.5));
    expect(rect.bottom, closeTo(595, 0.5));

    // il bordo destro e' a 260 (103+144+13): si parte da li', non da 263
    await dragMouse(tester, view(260, 595), view(280, 561));
    rect = editing.document.page(0).annotations.single.rect;
    expect(rect.right, closeTo(280, 0.5));
    expect(rect.bottom, closeTo(561, 0.5));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
  });

  testWidgets('moving next to another annotation does not snap to it',
      (tester) async {
    final editing = await pumpEditor(tester);
    editing.preferences.smartAlignmentGuides = true;
    editing
      ..addRectangle(0, const PdfRect(100, 650, 200, 750))
      ..addRectangle(0, const PdfRect(300, 500, 400, 600))
      ..tool = PdfEditTool.select
      ..selectAnnotation(0, 0);
    await tester.pump();

    final gesture = await tester.startGesture(view(150, 700),
        kind: PointerDeviceKind.mouse);
    // two points shy of the other box on x: it stays where it is dropped
    await gesture.moveTo(view(348, 550));
    await tester.pump();
    expect(find.byKey(const ValueKey('pdf-alignment-guides')), findsNothing);

    await gesture.up();
    await tester.pump();
    final moved = editing.document.page(0).annotations[0].rect;
    expect(moved.left, closeTo(298, 0.5));
    expect(moved.bottom, closeTo(500, 0.5));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
  });

  testWidgets('resizing next to another annotation does not snap to it',
      (tester) async {
    final editing = await pumpEditor(tester);
    editing
      ..addRectangle(0, const PdfRect(100, 600, 200, 700))
      ..addRectangle(0, const PdfRect(300, 500, 400, 600))
      ..tool = PdfEditTool.select
      ..selectAnnotation(0, 0);
    await tester.pump();

    await dragMouse(tester, view(200, 600), view(298, 502));
    final resized = editing.document.page(0).annotations[0].rect;
    expect(resized.right, closeTo(298, 0.5));
    expect(resized.bottom, closeTo(502, 0.5));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
  });

  testWidgets('optional page rulers use adaptive point ticks and hover marks',
      (tester) async {
    final editing = await pumpEditor(tester);
    editing.preferences.showPageRulers = true;
    await tester.pump();

    expect(find.byKey(const ValueKey('pdf-page-rulers')), findsOneWidget);
    var painter = rulerPainter(tester);
    expect(painter.bandWidth, 24);
    expect(painter.majorStepFor(const Size(800, 1035)), 50);
    expect(painter.cursor, isNull);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(5, 5));
    addTearDown(gesture.removePointer);
    await gesture.moveTo(view(220, 700));
    await tester.pump();
    painter = rulerPainter(tester);
    expect(painter.cursor.dx, closeTo(view(220, 700).dx, 0.1));
    expect(painter.cursor.dy, closeTo(view(220, 700).dy, 0.1));
  });

  testWidgets('page rulers follow the visible slice when zoomed in',
      (tester) async {
    final editing = PdfEditingController(buildMultiPagePdf(1));
    final viewer = PdfViewerController();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      editing.dispose();
      viewer.dispose();
    });
    editing.preferences.showPageRulers = true;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PdfViewer(
          initialFit: PdfViewerFit.width,
          controller: viewer,
          editing: editing,
        ),
      ),
    ));
    await tester.pump();

    // fit-width: the whole page width is on screen, rulers at its edges
    final pageSize = tester.getSize(find.byKey(const ValueKey(
      'pdf-page-rulers',
    )));
    var visible = rulerPainter(tester).visibleRectFor(pageSize)!;
    expect(visible.left, closeTo(0, 0.5));
    expect(visible.top, closeTo(0, 0.5));

    // zoomed 3x around the viewport centre the page's top-left corner is
    // off screen: the rulers must hang from the visible slice instead
    viewer.setZoom(3 * scale);
    await tester.pump();
    final region = viewer.visiblePageRegion(0)!;
    expect(region.left, greaterThan(0.1));
    expect(region.top, greaterThan(0.1));
    final zoomedSize = tester.getSize(find.byKey(const ValueKey(
      'pdf-page-rulers',
    )));
    visible = rulerPainter(tester).visibleRectFor(zoomedSize)!;
    expect(visible.left, closeTo(region.left * zoomedSize.width, 0.5));
    expect(visible.top, closeTo(region.top * zoomedSize.height, 0.5));
    // the step still adapts to the on-screen zoom
    expect(rulerPainter(tester).majorStepFor(zoomedSize), lessThan(50));
  });

  testWidgets('editor settings exposes persistent guide and grid controls',
      (tester) async {
    final preferences = PdfEditingPreferences();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      preferences.dispose();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PdfEditorView(
          bytes: buildMultiPagePdf(1),
          preferences: preferences,
        ),
      ),
    ));
    await tester.pump();

    expect(find.byKey(const ValueKey('pdf-editing-guides')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pdf-shell-view-options')),
        kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    // il foglio delle opzioni scorre: porta la voce in vista prima del tocco
    final guidesEntry = find.byKey(const ValueKey('pdf-shell-editing-guides'));
    await tester.ensureVisible(guidesEntry);
    await tester.pumpAndSettle();
    await tester.tap(guidesEntry, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pdf-guides-dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('pdf-smart-alignment-guides')), findsNothing);
    expect(find.byKey(const ValueKey('pdf-grid-snap')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pdf-page-rulers')));
    await tester.tap(find.byKey(const ValueKey('pdf-cursor-guide-vertical')));
    await tester.tap(find.byKey(const ValueKey('pdf-grid-visible')));
    await tester.pump();

    expect(preferences.showPageRulers, isTrue);
    expect(preferences.showVerticalCursorGuide, isTrue);
    expect(preferences.showSnapGrid, isTrue);

    await tester.tap(find.byKey(const ValueKey('pdf-guides-done')));
    await tester.pumpAndSettle();
  });

  test('guide and grid preferences persist', () async {
    final first = PdfEditingPreferences();
    await first.ready;
    first
      ..smartAlignmentGuides = false
      ..showPageRulers = true
      ..showVerticalCursorGuide = true
      ..showHorizontalCursorGuide = true
      ..showSnapGrid = true
      ..snapToGrid = true
      ..gridSpacing = 12.5;
    await pumpEventQueue();

    final second = PdfEditingPreferences();
    await second.ready;
    expect(second.smartAlignmentGuides, isFalse);
    expect(second.showPageRulers, isTrue);
    expect(second.showVerticalCursorGuide, isTrue);
    expect(second.showHorizontalCursorGuide, isTrue);
    expect(second.showSnapGrid, isTrue);
    expect(second.snapToGrid, isTrue);
    expect(second.gridSpacing, 12.5);
    first.dispose();
    second.dispose();
  });
}
