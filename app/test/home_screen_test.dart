// La Home: scorciatoie, schede Recenti / Con stella / Sul dispositivo e stelle.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/home_screen.dart';
import 'package:dart_pdf_editor_app/recents.dart';
import 'package:dart_pdf_editor_app/starred_store.dart';

void main() {
  late RecentsStore recents;
  late StarredStore starred;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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

  Future<void> pumpHome(
    WidgetTester tester, {
    List<HomeShortcut> shortcuts = const [],
    void Function(RecentFile)? onOpenRecent,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('go-home'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => HomeScreen(
                    recents: recents,
                    starred: starred,
                    shortcuts: shortcuts,
                    onOpenRecent: onOpenRecent ?? (_) {},
                  ),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(key('go-home'));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra saluto, scorciatoie e le tre schede', (tester) async {
    await pumpHome(tester, shortcuts: [
      HomeShortcut(
          id: 'open', icon: Icons.folder_open, label: 'Apri', run: () {}),
    ]);

    expect(find.text('Bentornato/a'), findsOneWidget);
    expect(find.text('Cosa vorresti fare?'), findsOneWidget);
    expect(key('home-shortcut-open'), findsOneWidget);
    for (final t in ['recent', 'starred', 'device']) {
      expect(key('home-tab-$t'), findsOneWidget, reason: t);
    }
  });

  testWidgets('Recenti elenca i file con tipo e data', (tester) async {
    await pumpHome(tester);

    expect(key('home-file-/a.pdf'), findsOneWidget);
    expect(key('home-file-/b.pdf'), findsOneWidget);
    expect(find.textContaining('PDF • '), findsNWidgets(2));
  });

  testWidgets('Con stella e' ' vuota finche non si mette una stella',
      (tester) async {
    await pumpHome(tester);

    await tester.tap(key('home-tab-starred'));
    await tester.pumpAndSettle();
    expect(key('home-empty'), findsOneWidget);
    expect(key('home-file-/a.pdf'), findsNothing);

    await tester.tap(key('home-tab-recent'));
    await tester.pumpAndSettle();
    await tester.tap(key('home-star-/a.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(key('home-tab-starred'));
    await tester.pumpAndSettle();

    expect(key('home-file-/a.pdf'), findsOneWidget);
    expect(key('home-file-/b.pdf'), findsNothing);
  });

  testWidgets('Sul dispositivo elenca i file che si possono riaprire',
      (tester) async {
    // L'add scrive su disco (log): nel tempo finto del test non finirebbe mai.
    await tester.runAsync(() => recents.add(title: 'web.pdf'));
    await pumpHome(tester);

    await tester.tap(key('home-tab-device'));
    await tester.pumpAndSettle();

    expect(key('home-file-/a.pdf'), findsOneWidget);
    expect(key('home-file-web.pdf'), findsNothing);
  });

  testWidgets('toccare un file lo apre e chiude la Home', (tester) async {
    RecentFile? opened;
    await pumpHome(tester, onOpenRecent: (e) => opened = e);

    await tester.tap(key('home-file-/b.pdf'));
    await tester.pumpAndSettle();

    expect(opened?.title, 'b.pdf');
    expect(key('home-screen'), findsNothing);
  });

  testWidgets('toccare una scorciatoia la esegue e chiude la Home',
      (tester) async {
    var ran = 0;
    await pumpHome(tester, shortcuts: [
      HomeShortcut(
          id: 'new-document',
          icon: Icons.note_add_outlined,
          label: 'Nuovo',
          run: () => ran++),
    ]);

    await tester.tap(key('home-shortcut-new-document'));
    await tester.pumpAndSettle();

    expect(ran, 1);
    expect(key('home-screen'), findsNothing);
  });

  testWidgets('un titolo lungo va a capo e si legge per intero',
      (tester) async {
    const long = 'Verbale della riunione del consiglio di amministrazione '
        'con allegati e note finali del mese di novembre duemilaventisei.pdf';
    await tester.runAsync(() => recents.add(title: long, path: '/lungo.pdf'));
    await pumpHome(tester);

    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
  });
}
