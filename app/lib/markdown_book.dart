import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show compute;

import 'epub_book.dart';

// File .md (Markdown): si legge il testo, si riconoscono titoli, elenchi,
// citazioni, tabelle e blocchi di codice, si tolgono i simboli (** _ ` e i
// collegamenti) e lo si scrive in un PDF nuovo con lo stesso motore degli
// .epub (`epubContentToPdf`), che si apre in una scheda. I titoli di primo
// livello iniziano una pagina nuova e diventano segnalibri quando sono almeno
// due. Il collegamento al menu è in `editor_screen.dart` (`_openMarkdown`).

/// I file che si scelgono per aprire un testo Markdown.
XTypeGroup markdownTypeGroup() => const XTypeGroup(
      label: 'Testo Markdown (.md)',
      extensions: ['md', 'markdown'],
      mimeTypes: [
        'text/markdown',
        'text/x-markdown',
        'text/plain',
        'application/octet-stream',
      ],
      uniformTypeIdentifiers: [
        'net.daringfireball.markdown',
        'public.plain-text',
        'public.data',
      ],
    );

/// Vero se [fileName] finisce con .md o .markdown (qualunque maiuscola).
bool isMarkdownFileName(String fileName) {
  final lower = fileName.trim().toLowerCase();
  return lower.endsWith('.md') || lower.endsWith('.markdown');
}

/// Chiede un file .md, o null se si annulla.
Future<XFile?> pickMarkdownFile() =>
    openFile(acceptedTypeGroups: [markdownTypeGroup()]);

/// Toglie dal testo di una riga i simboli del Markdown: grassetto, corsivo,
/// barrato, codice, immagini e collegamenti (resta il testo) e i tag HTML.
String markdownInlineToText(String line) {
  var t = line;
  t = t.replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1)!);
  t = t.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1)!);
  t = t.replaceAll(RegExp(r'<[^>]+>'), '');
  t = t.replaceAllMapped(RegExp(r'`+([^`]+)`+'), (m) => m.group(1)!);
  t = t.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!);
  t = t.replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m.group(1)!);
  t = t.replaceAllMapped(RegExp(r'~~(.+?)~~'), (m) => m.group(1)!);
  t = t.replaceAllMapped(RegExp(r'\*([^*\s][^*]*?)\*'), (m) => m.group(1)!);
  t = t.replaceAllMapped(
      RegExp(r'(?<![A-Za-z0-9])_([^_\s][^_]*?)_(?![A-Za-z0-9])'),
      (m) => m.group(1)!);
  t = t.replaceAllMapped(RegExp(r'\\([\\`*_{}\[\]()#+\-.!|>])'), (m) => m.group(1)!);
  return pdfSafeText(t).replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Il testo Markdown come blocchi di titoli (livelli 1-3) e paragrafi.
List<EpubBlock> markdownToBlocks(String source) {
  final blocks = <EpubBlock>[];
  final paragraph = <String>[];
  var inCode = false;

  void flush() {
    if (paragraph.isEmpty) return;
    final text = markdownInlineToText(paragraph.join(' '));
    paragraph.clear();
    if (text.isNotEmpty) blocks.add(EpubBlock(text));
  }

  for (final raw in source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    final line = raw.trimRight();
    final trimmed = line.trimLeft();

    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      flush();
      inCode = !inCode;
      continue;
    }
    if (inCode) {
      final code = pdfSafeText(line).trim();
      if (code.isNotEmpty) blocks.add(EpubBlock(code));
      continue;
    }
    if (trimmed.isEmpty) {
      flush();
      continue;
    }
    final heading = RegExp(r'^(#{1,6})\s+(.*?)\s*#*\s*$').firstMatch(trimmed);
    if (heading != null) {
      flush();
      final text = markdownInlineToText(heading.group(2)!);
      if (text.isEmpty) continue;
      final level = heading.group(1)!.length;
      blocks.add(EpubBlock(text,
          level: level > 3 ? 3 : level, chapterStart: level == 1));
      continue;
    }
    if (RegExp(r'^([-*_]\s*){3,}$').hasMatch(trimmed)) {
      flush();
      continue;
    }
    final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
    if (bullet != null) {
      flush();
      final text = markdownInlineToText(bullet.group(1)!);
      if (text.isNotEmpty) blocks.add(EpubBlock('- $text'));
      continue;
    }
    final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
    if (numbered != null) {
      flush();
      final text = markdownInlineToText(numbered.group(2)!);
      if (text.isNotEmpty) blocks.add(EpubBlock('${numbered.group(1)}. $text'));
      continue;
    }
    if (trimmed.startsWith('>')) {
      flush();
      final text = markdownInlineToText(trimmed.replaceFirst(RegExp(r'^>+\s*'), ''));
      if (text.isNotEmpty) blocks.add(EpubBlock(text, italic: true));
      continue;
    }
    if (trimmed.startsWith('|')) {
      flush();
      if (RegExp(r'^\|[\s:|-]+\|?$').hasMatch(trimmed)) continue;
      final cells = trimmed
          .split('|')
          .map(markdownInlineToText)
          .where((c) => c.isNotEmpty)
          .join(' | ');
      if (cells.isNotEmpty) blocks.add(EpubBlock(cells));
      continue;
    }
    paragraph.add(trimmed);
  }
  flush();
  return blocks;
}

/// Legge [bytes] (testo UTF-8) e lo trasforma in un PDF. Lancia
/// [FormatException] se il file non ha testo.
EpubPdfResult markdownToPdf(Uint8List bytes) {
  final blocks = markdownToBlocks(utf8.decode(bytes, allowMalformed: true));
  if (blocks.isEmpty) {
    throw const FormatException('il file non ha testo');
  }
  String? title;
  for (final b in blocks) {
    if (b.level == 1) {
      title = b.text;
      break;
    }
  }
  return epubContentToPdf((
    title: title,
    chapters: blocks.where((b) => b.chapterStart).length,
    blocks: blocks,
    cover: null,
  ));
}

/// [markdownToPdf] fuori dal filo dell'interfaccia: un testo lungo è lento.
Future<EpubPdfResult> markdownToPdfAsync(Uint8List bytes) =>
    compute(markdownToPdf, bytes, debugLabel: 'markdown to PDF');

/// Il titolo della scheda: il nome del file senza `.md`, più `.pdf`.
String markdownTitle(String fileName) {
  var stem = fileName.trim();
  final lower = stem.toLowerCase();
  if (lower.endsWith('.markdown')) {
    stem = stem.substring(0, stem.length - 9).trim();
  } else if (lower.endsWith('.md')) {
    stem = stem.substring(0, stem.length - 3).trim();
  }
  if (stem.isEmpty) stem = 'testo';
  return '$stem.pdf';
}
