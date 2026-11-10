import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf_document/pdf_document.dart';

import 'user_fonts_model.dart';

const bool userFontsSupported = true;

Future<Directory> _fontsDir() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory('${base.path}${Platform.pathSeparator}user_fonts');
  await dir.create(recursive: true);
  return dir;
}

/// The fonts imported so far, by family name.
Future<List<UserFontFile>> loadUserFontFiles() async {
  try {
    final dir = await _fontsDir();
    final fonts = <UserFontFile>[];
    for (final entry in dir.listSync(followLinks: false)) {
      if (entry is! File) continue;
      final name = entry.path.split(Platform.pathSeparator).last;
      final dot = name.lastIndexOf('.');
      if (dot <= 0) continue;
      final ext = name.substring(dot + 1).toLowerCase();
      if (ext != 'ttf' && ext != 'otf') continue;
      fonts.add(UserFontFile(family: name.substring(0, dot), path: entry.path));
    }
    fonts.sort(
        (a, b) => a.family.toLowerCase().compareTo(b.family.toLowerCase()));
    return fonts;
  } catch (_) {
    return const []; // no storage available: the menu just has no imports
  }
}

Future<Uint8List?> readUserFontFile(String path) async {
  try {
    return await File(path).readAsBytes();
  } catch (_) {
    return null;
  }
}

/// Imports the picked font files: one file per family, the normal face only
/// (italic files are skipped), files that are not fonts are skipped.
Future<UserFontImportResult> importUserFontFiles(
    List<UserFontSource> files) async {
  final dir = await _fontsDir();
  final best = <String, ({UserFontSource source, String family})>{};
  var italic = 0;
  var invalid = 0;
  for (final file in files) {
    if (looksItalic(file.name)) {
      italic++;
      continue;
    }
    final String family;
    try {
      family = PdfEmbeddedFont.parse(file.bytes).displayName.trim();
    } catch (_) {
      invalid++;
      continue;
    }
    if (family.isEmpty) {
      invalid++;
      continue;
    }
    final key = family.toLowerCase();
    final previous = best[key];
    if (previous == null ||
        styleRank(file.name) < styleRank(previous.source.name)) {
      best[key] = (source: file, family: family);
    }
  }
  final existing = {
    for (final font in await loadUserFontFiles()) font.family.toLowerCase(),
  };
  final added = <String>[];
  var duplicates = 0;
  for (final entry in best.values) {
    if (existing.contains(entry.family.toLowerCase())) {
      duplicates++;
      continue;
    }
    final ext = entry.source.name.toLowerCase().endsWith('.otf') ? 'otf' : 'ttf';
    final safe = entry.family.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '_');
    await File('${dir.path}${Platform.pathSeparator}$safe.$ext')
        .writeAsBytes(entry.source.bytes, flush: true);
    added.add(entry.family);
  }
  return UserFontImportResult(
    added: added,
    italic: italic,
    invalid: invalid,
    duplicates: duplicates,
  );
}

Future<void> deleteUserFontFile(String path) async {
  try {
    await File(path).delete();
  } catch (_) {}
}
