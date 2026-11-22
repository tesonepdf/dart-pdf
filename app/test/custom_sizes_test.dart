import 'package:dart_pdf_editor_app/custom_sizes.dart';
import 'package:dart_pdf_editor_app/image_to_pdf.dart';
import 'package:dart_pdf_editor_app/standard_sizes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late CustomSizesStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = CustomSizesStore()..resetForTest();
  });

  tearDown(() => kCustomSizes.clear());

  test('una misura con nome si salva e si trova per id come le predefinite',
      () async {
    final size = await store.add('Tessera palestra', 90, 50);
    expect(size.name, 'Tessera palestra');
    expect(size.widthMm, 90);
    expect(size.heightMm, 50);
    expect(size.id, startsWith('mia_'));
    expect(standardSizeById(size.id), same(size));
    // le predefinite si trovano ancora
    expect(standardSizeById('card_cie'), isNotNull);
    expect(standardSizeById('mia_inesistente'), isNull);
  });

  test('i calcoli dei dpi usano la misura personalizzata', () async {
    final size = await store.add('Cornice', 100, 150);
    // 800 x 1200 pixel a 100 x 150 mm sono 203,2 dpi
    expect(photoDpi(800, 1200, size.id), closeTo(203.2, 0.01));
  });

  test('senza nome, il nome sono le misure; i nomi lunghi si accorciano',
      () async {
    final unnamed = await store.add('   ', 90, 50.5);
    expect(unnamed.name, '90 x 50,5 mm');
    final long = await store.add('x' * 200, 10, 10);
    expect(long.name.length, kMaxCustomSizeName);
  });

  test('lo stesso nome sostituisce la misura invece di duplicarla', () async {
    final first = await store.add('Foto cornice', 100, 150);
    final second = await store.add('foto CORNICE', 130, 180);
    expect(store.sizes, hasLength(1));
    expect(second.id, first.id);
    expect(standardSizeById(first.id)!.widthMm, 130);
  });

  test('le misure restano salvate e si rileggono', () async {
    await store.add('Cornice', 100, 150);
    await store.add('Tessera palestra', 90, 50);
    store.resetForTest();
    expect(store.sizes, isEmpty);
    await store.load();
    expect(store.sizes.map((s) => s.name), ['Cornice', 'Tessera palestra']);
    expect(store.sizes.last.widthMm, 90);
    expect(store.sizes.last.heightMm, 50);
  });

  test('una misura eliminata sparisce subito e anche dopo la rilettura',
      () async {
    final a = await store.add('Cornice', 100, 150);
    await store.add('Tessera palestra', 90, 50);
    await store.remove(a.id);
    expect(store.sizes.map((s) => s.name), ['Tessera palestra']);
    expect(standardSizeById(a.id), isNull);
    store.resetForTest();
    await store.load();
    expect(store.sizes.map((s) => s.name), ['Tessera palestra']);
  });

  test('i dati salvati rovinati non rompono la lettura', () async {
    SharedPreferences.setMockInitialValues({
      'dart_pdf_editor_app.custom_sizes':
          '[{"id":"mia_1","name":"Buona","w":90,"h":50},'
              '{"id":"","name":"Senza id","w":90,"h":50},'
              '{"id":"mia_3","name":"Zero","w":0,"h":50},'
              '"non una misura"]',
    });
    await store.load();
    expect(store.sizes.map((s) => s.name), ['Buona']);
    store.resetForTest();
    SharedPreferences.setMockInitialValues({
      'dart_pdf_editor_app.custom_sizes': 'non e\' json',
    });
    await store.load();
    expect(store.sizes, isEmpty);
  });

  test('limiti: da 1 mm a 5 m', () {
    expect(isValidCustomSizeMm(1, 1), isTrue);
    expect(isValidCustomSizeMm(5000, 5000), isTrue);
    expect(isValidCustomSizeMm(0.5, 10), isFalse);
    expect(isValidCustomSizeMm(10, 5001), isFalse);
    expect(isValidCustomSizeMm(double.nan, 10), isFalse);
  });

  testWidgets('la finestra crea una misura con nome e la elimina',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCustomSizesDialog(context, store: store),
            child: const Text('apri'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('custom-sizes-dialog')), findsOneWidget);
    expect(find.textContaining('Nessuna misura salvata'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('custom-size-name')), 'Tessera palestra');
    await tester.enterText(
        find.byKey(const ValueKey('custom-size-width')), '9');
    await tester.enterText(
        find.byKey(const ValueKey('custom-size-height')), '5,5');
    await tester.tap(find.byKey(const ValueKey('custom-size-save')));
    await tester.pumpAndSettle();

    expect(store.sizes, hasLength(1));
    expect(store.sizes.single.name, 'Tessera palestra');
    // cm di default: 9 x 5,5 cm = 90 x 55 mm
    expect(store.sizes.single.widthMm, closeTo(90, 0.001));
    expect(store.sizes.single.heightMm, closeTo(55, 0.001));
    expect(find.text('Tessera palestra'), findsOneWidget);
    expect(find.text('90 × 55 mm'), findsOneWidget);

    await tester.tap(find.byKey(
        ValueKey('custom-size-delete-${store.sizes.single.id}')));
    await tester.pumpAndSettle();
    expect(store.sizes, isEmpty);
    expect(find.textContaining('Nessuna misura salvata'), findsOneWidget);
  });

  testWidgets('la finestra rifiuta misure mancanti o fuori dai limiti',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCustomSizesDialog(context, store: store),
            child: const Text('apri'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('custom-size-save')));
    await tester.pumpAndSettle();
    expect(find.text('Scrivi larghezza e altezza.'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('custom-size-width')), '900');
    await tester.enterText(
        find.byKey(const ValueKey('custom-size-height')), '10');
    await tester.tap(find.byKey(const ValueKey('custom-size-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('fuori dai limiti'), findsOneWidget);
    expect(store.sizes, isEmpty);
  });
}
