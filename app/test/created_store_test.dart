// Le creazioni recenti: elenco salvato e sezione nella schermata Crea.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/create_screen.dart';
import 'package:dart_pdf_editor_app/created_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('la piu\' recente sta in cima', () async {
    final store = CreatedStore();
    await store.add(kind: 'Scansione', title: 'a');
    await store.add(kind: 'Fumetto', title: 'b');
    expect([for (final i in store.items) i.title], ['b', 'a']);
    expect(store.items.first.kind, 'Fumetto');
  });

  test('si ricordano al massimo ${CreatedStore.maxItems} creazioni', () async {
    final store = CreatedStore();
    for (var i = 0; i < CreatedStore.maxItems + 5; i++) {
      await store.add(kind: 'Nuovo documento', title: 'd$i');
    }
    expect(store.items.length, CreatedStore.maxItems);
    expect(store.items.first.title, 'd${CreatedStore.maxItems + 4}');
  });

  test('restano dopo aver riaperto l\'app', () async {
    await CreatedStore().add(kind: 'Libro', title: 'romanzo');
    final again = CreatedStore();
    await again.load();
    expect(again.items.single.title, 'romanzo');
    expect(again.items.single.kind, 'Libro');
  });

  Future<void> pump(WidgetTester tester, CreatedStore store,
      ValueChanged<CreatedFile> onOpen) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const ValueKey('go'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => CreateScreen(
                  sections: const [],
                  store: store,
                  onOpenCreated: onOpen,
                ),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();
  }

  testWidgets('senza creazioni lo dice', (tester) async {
    await pump(tester, CreatedStore(), (_) {});
    expect(find.text('Creazioni recenti'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-recent-empty')), findsOneWidget);
  });

  testWidgets('elenca le creazioni e toccandone una la riapre',
      (tester) async {
    final store = CreatedStore();
    await tester.runAsync(() async {
      await store.add(kind: 'Scansione', title: 'Scansione 1');
      await store.add(kind: 'Fumetto', title: 'Topolino');
    });
    CreatedFile? opened;
    await pump(tester, store, (c) => opened = c);

    expect(find.text('Topolino'), findsOneWidget);
    expect(find.text('Scansione 1'), findsOneWidget);
    expect(find.textContaining('Fumetto \u2022 '), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('create-recent-0')));
    await tester.pumpAndSettle();
    expect(opened?.title, 'Topolino');
    expect(find.byKey(const ValueKey('create-screen')), findsNothing);
  });
}
