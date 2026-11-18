// La Home stile tesone: menu dei tre puntini, vista griglia, selezione,
// peso e data dei file.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/bottom_bar_setting.dart';
import 'package:dart_pdf_editor_app/file_info.dart';
import 'package:dart_pdf_editor_app/home_screen.dart';
import 'package:dart_pdf_editor_app/recents.dart';
import 'package:dart_pdf_editor_app/starred_store.dart';

void main() {
  late RecentsStore recents;
  late StarredStore starred;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    HomeGridSetting.instance.value = false;
    recents = RecentsStore();
    starred = StarredStore();
    await recents.add(title: 'a.pdf', path: '/a.pdf');
    await recents.add(title: 'b.pdf', path: '/b.pdf');
  });
  tearDown(() {
    recents.dispose();
    starred.dispose();
  });

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> pumpHome(WidgetTester tester, {FileInfoReader? fileInfo}) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        embedded: true,
        recents: recents,
        starred: starred,
        fileInfo: fileInfo,
        onOpenRecent: (_) {},
        shortcuts: const [],
      ),
    ));
    await tester.pumpAndSettle();
  }

  // La Home chiama remove() e clear() senza aspettarli, e lo store e' nato in
  // setUp (fuori dal tempo finto): il loro primo await finisce nel tempo
  // vero. Qui si lascia girare, poi si ridisegna.
  Future<void> letStoreFinish(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  testWidgets('niente saluto e niente banner: si parte da Cosa vorresti fare?',
      (tester) async {
    await pumpHome(tester);
    expect(find.text('Cosa vorresti fare?'), findsOneWidget);
    expect(find.text('Bentornato/a'), findsNothing);
  });

  testWidgets('i tre puntini aprono il menu con le tre voci', (tester) async {
    await pumpHome(tester);
    await tester.tap(key('home-menu'));
    await tester.pumpAndSettle();

    expect(find.text('Seleziona tutto'), findsOneWidget);
    expect(find.text('Vista griglia'), findsOneWidget);
    expect(find.text('Cancella recenti'), findsOneWidget);
  });

  testWidgets('Vista griglia mostra i file in griglia e poi torna all\'elenco',
      (tester) async {
    await pumpHome(tester);
    expect(key('home-grid'), findsNothing);

    await tester.tap(key('home-menu'));
    await tester.pumpAndSettle();
    await tester.tap(key('home-menu-view'));
    await tester.pumpAndSettle();
    expect(key('home-grid'), findsOneWidget);
    expect(key('home-file-/a.pdf'), findsOneWidget);

    await tester.tap(key('home-menu'));
    await tester.pumpAndSettle();
    expect(find.text('Vista elenco'), findsOneWidget);
    await tester.tap(key('home-menu-view'));
    await tester.pumpAndSettle();
    expect(key('home-grid'), findsNothing);
  });

  testWidgets('Seleziona tutto e Togli dall\'elenco svuotano i recenti',
      (tester) async {
    await pumpHome(tester);
    await tester.tap(key('home-menu'));
    await tester.pumpAndSettle();
    await tester.tap(key('home-menu-select-all'));
    await tester.pumpAndSettle();

    expect(find.text('2 selezionati'), findsOneWidget);
    expect(key('home-check-/a.pdf'), findsOneWidget);

    await tester.tap(key('home-select-remove'));
    await tester.pumpAndSettle();
    await letStoreFinish(tester);

    expect(key('home-empty'), findsOneWidget);
    expect(key('home-select-count'), findsNothing);
  });

  testWidgets('in selezione toccare un file lo (de)seleziona e non lo apre',
      (tester) async {
    await pumpHome(tester);
    await tester.tap(key('home-menu'));
    await tester.pumpAndSettle();
    await tester.tap(key('home-menu-select-all'));
    await tester.pumpAndSettle();

    await tester.tap(key('home-file-/a.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('1 selezionato'), findsOneWidget);

    await tester.tap(key('home-select-done'));
    await tester.pumpAndSettle();
    expect(key('home-select-count'), findsNothing);
    expect(key('home-tab-recent'), findsOneWidget);
  });

  testWidgets('Cancella recenti svuota l\'elenco', (tester) async {
    await pumpHome(tester);
    await tester.tap(key('home-menu'));
    await tester.pumpAndSettle();
    await tester.tap(key('home-menu-clear'));
    await tester.pumpAndSettle();
    await letStoreFinish(tester);

    expect(key('home-empty'), findsOneWidget);
  });

  testWidgets('ogni file mostra data, ora e peso letti dal file',
      (tester) async {
    final now = DateTime.now();
    final modified = DateTime(now.year, 11, 17, 8, 34);
    await pumpHome(
      tester,
      fileInfo: (path) async =>
          FileInfo(size: 314777, modified: modified),
    );

    expect(find.text('PDF \u2022 17 nov, 08:34 \u2022 307,4 KB'),
        findsNWidgets(2));
  });

  testWidgets('senza lettore dei file resta solo la data, senza peso',
      (tester) async {
    await pumpHome(tester);
    expect(find.textContaining(' KB'), findsNothing);
    expect(find.textContaining('PDF \u2022 '), findsNWidgets(2));
  });
}
