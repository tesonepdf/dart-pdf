import 'dart:typed_data';

import 'user_fonts_model.dart';

/// No device storage to keep imported fonts in (web): the feature is hidden.
const bool userFontsSupported = false;

Future<List<UserFontFile>> loadUserFontFiles() async => const [];

Future<Uint8List?> readUserFontFile(String path) async => null;

Future<UserFontImportResult> importUserFontFiles(
        List<UserFontSource> files) async =>
    const UserFontImportResult();

Future<void> deleteUserFontFile(String path) async {}
