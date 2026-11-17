// "Home come schermata iniziale": l'opzione e la Home incorporata.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/bottom_bar_setting.dart';
import 'package:dart_pdf_editor_app/home_screen.dart';
import 'package:dart_pdf_editor_app/recents.dart';
import 'package:dart_pdf_editor_app/starred_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StartHomeSetting.instance.value = false;
  });

  test('di base e\' spenta e si salva sul dispositivo', () async {
    expect(StartHomeSetting.instance.value, isFalse);
    await StartHomeSetting.instance.save(true);
    expect(StartHomeSetting.instance.value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dart_pdf_editor_app.start_home'), isTrue);
  });

  testWidgets('incorporata: senza freccia e toccare una scorciatoia non chiude',
      (tester) async {
    final recents = RecentsStore();
    final starred = StarredStore();
    addTearDown(recents.dispose);
    addTearDown(starred.dispose);
    var ran = 0;
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        embedded: true,
        recents: recents,
        starred: starred,
        onOpenRecent: (_) {},
        shortcuts: [
          HomeShortcut(
              id: 'new-document',
              icon: Icons.note_add_outlined,
              label: 'Nuovo',
              run: () => ran++),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Cosa vorresti fare?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-shortcut-new-document')));
    await tester.pumpAndSettle();

    expect(ran, 1);
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
  });
}
