import 'dart:typed_data';

/// A font file the person picked, before it is imported.
class UserFontSource {
  const UserFontSource(this.name, this.bytes);

  /// The file name, e.g. `Calibri-Regular.ttf`.
  final String name;

  final Uint8List bytes;
}

/// A font the person imported, kept on the device.
class UserFontFile {
  const UserFontFile({required this.family, required this.path});

  /// The family name shown in the font menu.
  final String family;

  /// Where the font file is stored.
  final String path;
}

/// What an import did, for the one-line message under the button.
class UserFontImportResult {
  const UserFontImportResult({
    this.added = const [],
    this.italic = 0,
    this.invalid = 0,
    this.duplicates = 0,
  });

  /// Families that were added.
  final List<String> added;

  /// Files skipped because they are italic (only the normal face is kept).
  final int italic;

  /// Files skipped because they are not a readable font.
  final int invalid;

  /// Families skipped because they were already imported.
  final int duplicates;

  String get summary {
    final parts = <String>[
      if (added.isNotEmpty)
        added.length == 1
            ? 'Aggiunto: ${added.first}.'
            : 'Aggiunti ${added.length} font: ${added.join(', ')}.',
      if (italic > 0) 'Corsivi saltati: $italic.',
      if (duplicates > 0) 'Già presenti: $duplicates.',
      if (invalid > 0) 'File non validi: $invalid.',
    ];
    return parts.isEmpty ? 'Nessun font aggiunto.' : parts.join(' ');
  }
}

/// Whether a font file name says it is an italic or oblique face. Imported
/// fonts keep only the normal face.
bool looksItalic(String fileName) {
  final name = fileName.toLowerCase();
  return name.contains('italic') ||
      name.contains('oblique') ||
      RegExp(r'[-_ ]it(\.[a-z0-9]+)?$').hasMatch(name);
}

/// 0 for a plain/Regular face, 1 for any other style (Bold, Light, ...).
/// When several files of one family are picked, the lowest rank is kept.
int styleRank(String fileName) {
  final name = fileName.toLowerCase();
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  final dash = stem.lastIndexOf('-');
  if (dash < 0) return 0;
  final style = stem.substring(dash + 1);
  return style == 'regular' ||
          style == 'book' ||
          style == 'roman' ||
          style == 'normal'
      ? 0
      : 1;
}
