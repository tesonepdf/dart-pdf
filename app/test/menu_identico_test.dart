// Paletto 1 (conflittiFusione.md): il menu e' identico su tutti i sistemi,
// stesse voci, stesso ordine, stessi nomi. Cambia solo come ci si arriva.
// Qui si costruisce il menu per Android, iOS, Windows, macOS e Linux e si
// confronta con quello di Android. Il web ha la stessa prova in
// `flutter test --platform chrome test/menu_identico_test.dart`
// (il web e' un solo sistema: kIsWeb non si puo' simulare).
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/bottom_bar_setting.dart';
import 'package:dart_pdf_editor_app/editor_screen.dart';
import 'test_finders.dart';

/// Elenco ordinato di "id|titolo" di ogni voce del menu e di ogni macroarea.
List<String> _menuEntries(WidgetTester tester) {
  final out = <String>[];
  // Ogni riga del menu ha come chiave l'id del comando (anche senza il
  // prefisso "menu-"): si prendono tutte le chiavi di testo dentro il menu.
  final rows = find.descendant(
    of: find.byKey(const ValueKey('app-menu')),
    matching: find.byWidgetPredicate((w) => w.key is ValueKey<String>),
  );
  for (final element in rows.evaluate()) {
    final id = (element.widget.key! as ValueKey<String>).value;
    final texts = find
        .descendant(of: find.byWidget(element.widget), matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        // Le scorciatoie (Ctrl+K su Windows, Cmd+K su Mac) cambiano per
        // sistema: e' il "come ci si arriva", non il menu.
        .where((t) => t.isNotEmpty && !RegExp(r'Ctrl|⌘|⇧|⌥|Cmd').hasMatch(t))
        .join('')
        // Il testo puo' andare a capo in modo diverso: si confronta senza spazi.
        .replaceAll(RegExp(r'\s+'), '');
    out.add('$id|$texts');
  }
  return out;
}

/// I gruppi del menu, nell'ordine concordato (menu.md, passo 1).
const _groupOrder = [
  'create',
  'file',
  'view',
  'pages',
  'tools',
  'sign',
  'ocr',
  'export',
  'share',
  'app',
  'other',
];

/// Con un documento aperto questi gruppi ci sono sempre.
const _groupsAlwaysThere = ['create', 'file', 'pages', 'tools', 'share', 'app'];

/// I gruppi presenti nell'elenco, in ordine di comparsa: devono seguire
/// [_groupOrder], e quelli sempre presenti non devono mancare.
void _checkGroupOrder(List<String> entries) {
  const prefix = 'app-menu-group-';
  final present = [
    for (final e in entries)
      if (e.startsWith(prefix)) e.split('|').first.substring(prefix.length),
  ];
  for (final id in _groupsAlwaysThere) {
    expect(present, contains(id), reason: 'gruppo $id mancante: $present');
  }
  final indexes = [for (final id in present) _groupOrder.indexOf(id)];
  expect(indexes, isNot(contains(-1)), reason: 'gruppo sconosciuto: $present');
  expect(indexes, orderedEquals([...indexes]..sort()),
      reason: 'gruppi fuori ordine: $present');
}

/// Le chiavi di testo che iniziano con [prefix], in ordine di comparsa.
List<String> _keysWith(String prefix) => [
      for (final element in find
          .byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(prefix))
          .evaluate())
        (element.widget.key! as ValueKey<String>).value,
    ];

void main() {
  late PdfEditingPreferences prefs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefs = PdfEditingPreferences();
  });
  tearDown(() {
    BottomBarSetting.instance.value = false;
    prefs.dispose();
  });

  /// Le azioni della schermata Crea e gli strumenti di ogni scheda della
  /// schermata Strumenti, come li mostra [platform].
  Future<Map<String, List<String>>> screens(
      WidgetTester tester, TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.physicalSize = const Size(1400, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      key: ValueKey(platform),
      home: EditorScreen(
        prefs: prefs,
        initialDocument: (bytes: buildClassicPdf(), title: 'Report.pdf'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await BottomBarSetting.instance.save(true);
    await tester.pumpAndSettle();

    final out = <String, List<String>>{};
    await tester.tap(find.byKey(const ValueKey('bottom-bar-create')));
    await tester.pumpAndSettle();
    out['crea'] = _keysWith('create-action-');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bottom-bar-tools')));
    await tester.pumpAndSettle();
    for (final tab in ['all', 'read', 'create', 'edit', 'convert', 'other']) {
      await tester.tap(find.byKey(ValueKey('tools-tab-$tab')));
      await tester.pumpAndSettle();
      out['strumenti-$tab'] = _keysWith('tool-');
    }
    return out;
  }

  Future<List<String>> build(WidgetTester tester, TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    // Finestra alta e larga: nessuna voce resta fuori dalla lista.
    tester.view.physicalSize = const Size(1400, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      key: ValueKey(platform),
      home: EditorScreen(
        prefs: prefs,
        initialDocument: (bytes: buildClassicPdf(), title: 'Report.pdf'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await openAppMenu(tester);
    return _menuEntries(tester);
  }

  testWidgets('il menu e\' identico su Android, iOS, Windows, macOS e Linux',
      (tester) async {
    try {
      await _check(tester, build);
    } finally {
      // Prima che il test finisca, altrimenti Flutter segnala la variabile.
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
      'Crea e Strumenti hanno le stesse voci su Android, iOS, Windows, '
      'macOS e Linux', (tester) async {
    try {
      await _checkScreens(tester, screens);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _checkScreens(
  WidgetTester tester,
  Future<Map<String, List<String>>> Function(WidgetTester, TargetPlatform)
      screens,
) async {
  final android = await screens(tester, TargetPlatform.android);
  expect(android['crea'], contains('create-action-new-document'));
  expect(android['strumenti-all'], isNotEmpty);
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ]) {
    await tester.pumpWidget(const SizedBox());
    final other = await screens(tester, platform);
    for (final name in android.keys) {
      expect(other[name], orderedEquals(android[name]!),
          reason: '$name diverso su ${platform.name}');
    }
  }
}

Future<void> _check(
  WidgetTester tester,
  Future<List<String>> Function(WidgetTester, TargetPlatform) build,
) async {
  {
    final android = await build(tester, TargetPlatform.android);
    expect(android, isNotEmpty);
    _checkGroupOrder(android);
    // Le voci che prima sparivano su alcuni sistemi ci sono sempre.
    for (final id in [
      'open-in-word',
      'open-in-excel',
      'open-with-rank',
      'whatsapp-contact',
      'whatsapp',
      'share',
      'tools',
      'ocr',
      'updates',
    ]) {
      // L'id della riga puo' avere o no il prefisso "menu-".
      expect(
          android.any((e) => e.startsWith('$id|') || e.startsWith('menu-$id|')),
          isTrue,
          reason: '$id manca. Voci trovate: ${android.map((e) => e.split('|').first).join(', ')}');
    }
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    ]) {
      await tester.pumpWidget(const SizedBox());
      final other = await build(tester, platform);
      if (other.join('\n') != android.join('\n')) {
        final diff = <String>[];
        final n = other.length > android.length ? other.length : android.length;
        for (var i = 0; i < n && diff.length < 12; i++) {
          final a = i < android.length ? android[i] : '(niente)';
          final b = i < other.length ? other[i] : '(niente)';
          if (a != b) diff.add('#$i android: $a  |  ${platform.name}: $b');
        }
        fail('menu diverso su ${platform.name}:\n${diff.join('\n')}');
      }
    }
  }
}
