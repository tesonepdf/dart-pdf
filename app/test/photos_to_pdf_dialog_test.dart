// La finestra "Foto in PDF": elenco delle foto, rimozione, scelta della
// pagina. Il trascinamento usa lo stesso ReorderableListView della finestra di
// unione dei PDF e non si prova qui con il gesto.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';

import 'package:dart_pdf_editor_app/pdf_conversions.dart';
import 'package:dart_pdf_editor_app/photos_to_pdf_dialog.dart';

Uint8List png() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)));

void main() {
  final items = [
    PhotoItem('a.png', png()),
    PhotoItem('b.png', png()),
    PhotoItem('c.png', png()),
  ];

  ({List<PhotoItem> photos, PhotoPdfPage page})? result;
  var closed = false;

  Future<void> open(WidgetTester tester) async {
    result = null;
    closed = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showPhotosToPdfDialog(context, items);
              closed = true;
            },
            child: const Text('apri'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  testWidgets('elenca le foto, una pagina ciascuna, e di base usa A4',
      (tester) async {
    await open(tester);
    expect(find.text('Foto in PDF (3)'), findsOneWidget);
    expect(find.text('a.png'), findsOneWidget);
    expect(find.text('b.png'), findsOneWidget);
    expect(find.text('c.png'), findsOneWidget);
    expect(find.text('Pagina 1'), findsOneWidget);
    expect(find.text('Pagina 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('photos-pdf-confirm')));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect([for (final p in result!.photos) p.name], ['a.png', 'b.png', 'c.png']);
    expect(result!.page, PhotoPdfPage.a4);
  });

  testWidgets('si può scegliere la misura della foto', (tester) async {
    await open(tester);
    await tester.ensureVisible(find.text('Misura della foto'));
    await tester.tap(find.text('Misura della foto'));
    await tester.pump();
    expect(find.text(photoPdfPageHint(PhotoPdfPage.photoSize)),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('photos-pdf-confirm')));
    await tester.pumpAndSettle();
    expect(result!.page, PhotoPdfPage.photoSize);
  });

  testWidgets('togliere una foto dall\'elenco la esclude e rinumera',
      (tester) async {
    await open(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('photos-pdf-remove-1')));
    await tester.tap(find.byKey(const ValueKey('photos-pdf-remove-1')));
    await tester.pump();
    expect(find.text('Foto in PDF (2)'), findsOneWidget);
    expect(find.text('b.png'), findsNothing);
    expect(find.text('Pagina 3'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('photos-pdf-confirm')));
    await tester.pumpAndSettle();
    expect([for (final p in result!.photos) p.name], ['a.png', 'c.png']);
  });

  testWidgets('con l\'elenco vuoto non si può creare il PDF', (tester) async {
    await open(tester);
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(find.byKey(const ValueKey('photos-pdf-remove-0')));
      await tester.tap(find.byKey(const ValueKey('photos-pdf-remove-0')));
      await tester.pump();
    }
    expect(find.text('Foto in PDF (0)'), findsOneWidget);
    final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('photos-pdf-confirm')));
    expect(button.onPressed, isNull);
  });

  testWidgets('Annulla chiude senza risultato', (tester) async {
    await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });
}
