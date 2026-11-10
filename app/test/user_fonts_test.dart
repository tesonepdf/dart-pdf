import 'dart:io';
import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:dart_pdf_editor_app/user_fonts.dart';

/// The fonts the person imports from the phone: several files at once, one
/// file per family, normal face only, kept on the device and offered in the
/// editor's font menu.
void main() {
  late Directory root;
  final fonts = '../packages/dart_pdf_editor_assets/assets/fonts';

  Uint8List bytesOf(String file) => File('$fonts/$file').readAsBytesSync();

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    root = Directory.systemTemp.createTempSync('dartpdf_user_fonts_test');
    PathProviderPlatform.instance = _TempPathProvider(root.path);
    // a clean slate: nothing imported, no system fonts
    UserFonts.instance.setSystemFonts(const []);
    await UserFonts.instance.load();
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    pdfPlatformFonts = const [];
  });

  test('italic and style detection from the file name', () {
    expect(looksItalic('Carlito-Italic.ttf'), isTrue);
    expect(looksItalic('Font-BoldOblique.otf'), isTrue);
    expect(looksItalic('Font-It.ttf'), isTrue);
    expect(looksItalic('Carlito-Regular.ttf'), isFalse);
    expect(looksItalic('Carlito-Bold.ttf'), isFalse);
    expect(styleRank('Carlito-Regular.ttf'), 0);
    expect(styleRank('Carlito.ttf'), 0);
    expect(styleRank('Carlito-Bold.ttf'), 1);
  });

  test('several files at once: one per family, normal face only', () async {
    final result = await UserFonts.instance.import([
      UserFontSource('Carlito-Bold.ttf', bytesOf('Carlito-Bold.ttf')),
      UserFontSource('Carlito-Italic.ttf', bytesOf('Carlito-Italic.ttf')),
      UserFontSource('Carlito-Regular.ttf', bytesOf('Carlito-Regular.ttf')),
      UserFontSource('Tinos-Regular.ttf', bytesOf('Tinos-Regular.ttf')),
      UserFontSource('notes.ttf', Uint8List.fromList([1, 2, 3, 4])),
    ]);
    expect(result.added.toSet(), {'Carlito', 'Tinos'});
    expect(result.italic, 1);
    expect(result.invalid, 1);

    final imported = UserFonts.instance.imported;
    expect(imported.map((f) => f.family), ['Carlito', 'Tinos']);
    // the regular face was kept, not the bold one
    final kept = File(imported.first.path).readAsBytesSync();
    expect(kept, bytesOf('Carlito-Regular.ttf'));
  });

  test('imported fonts head the menu list and embed on pick', () async {
    UserFonts.instance.setSystemFonts([
      PdfPlatformFont(label: 'Zeta', loadBytes: () async => null),
    ]);
    await UserFonts.instance.import([
      UserFontSource('Carlito-Regular.ttf', bytesOf('Carlito-Regular.ttf')),
    ]);
    expect(pdfPlatformFonts.map((f) => f.label),
        ['Carlito (importato)', 'Zeta']);
    final loaded = await pdfPlatformFonts.first.loadBytes();
    expect(loaded, bytesOf('Carlito-Regular.ttf'));
    expect(PdfEmbeddedFont.parse(loaded!).displayName, 'Carlito');
  });

  test('a family already imported is not added twice; remove works',
      () async {
    final regular =
        UserFontSource('Carlito-Regular.ttf', bytesOf('Carlito-Regular.ttf'));
    await UserFonts.instance.import([regular]);
    final again = await UserFonts.instance.import([regular]);
    expect(again.added, isEmpty);
    expect(again.duplicates, 1);
    expect(UserFonts.instance.imported, hasLength(1));

    await UserFonts.instance.remove(UserFonts.instance.imported.single);
    expect(UserFonts.instance.imported, isEmpty);
    expect(pdfPlatformFonts, isEmpty);
  });

  test('the imported fonts are still there on the next launch', () async {
    await UserFonts.instance.import([
      UserFontSource('Tinos-Regular.ttf', bytesOf('Tinos-Regular.ttf')),
    ]);
    // a relaunch reads them from storage alone
    await UserFonts.instance.load();
    expect(UserFonts.instance.imported.map((f) => f.family), ['Tinos']);
  });
}

class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}
