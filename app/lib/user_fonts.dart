import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/foundation.dart';

import 'user_fonts_model.dart';
import 'user_fonts_stub.dart' if (dart.library.io) 'user_fonts_io.dart' as impl;

export 'user_fonts_model.dart';

/// The fonts the person imported from the phone, offered in the editor's font
/// menu (right after the bundled fonts, before the system fonts) and embedded
/// into the PDF when picked.
class UserFonts extends ChangeNotifier {
  UserFonts._();

  static final UserFonts instance = UserFonts._();

  List<PdfPlatformFont> _system = const [];
  List<UserFontFile> _imported = const [];

  /// The imported fonts, by family name.
  List<UserFontFile> get imported => _imported;

  /// Whether this platform can keep imported fonts (not the web).
  bool get supported => impl.userFontsSupported;

  /// Reads the imported fonts from storage and offers them in the menu.
  Future<void> load() async {
    _imported = await impl.loadUserFontFiles();
    _publish();
    notifyListeners();
  }

  /// The OS-installed fonts, kept after the imported ones in the menu.
  void setSystemFonts(List<PdfPlatformFont> fonts) {
    _system = fonts;
    _publish();
  }

  /// Imports the picked files and refreshes the menu.
  Future<UserFontImportResult> import(List<UserFontSource> files) async {
    final result = await impl.importUserFontFiles(files);
    await load();
    return result;
  }

  /// Removes an imported font.
  Future<void> remove(UserFontFile font) async {
    await impl.deleteUserFontFile(font.path);
    await load();
  }

  void _publish() {
    pdfPlatformFonts = [
      for (final font in _imported)
        PdfPlatformFont(
          label: '${font.family} (importato)',
          loadBytes: () => impl.readUserFontFile(font.path),
        ),
      ..._system,
    ];
  }
}
