// File .md (markdown_book.dart): blocchi di testo e PDF.
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_document/pdf_document.dart';

import 'package:dart_pdf_editor_app/markdown_book.dart';

void main() {
  test('titoli, elenchi e paragrafi', () {
    final blocks = markdownToBlocks('# Titolo\n\nUn **paragrafo** con `codice`\n'
        'su due righe.\n\n## Sezione\n\n- uno\n- due\n\n1. primo\n');
    expect(blocks.map((b) => b.text).toList(), [
      'Titolo',
      'Un paragrafo con codice su due righe.',
      'Sezione',
      '- uno',
      '- due',
      '1. primo',
    ]);
    expect(blocks[0].level, 1);
    expect(blocks[0].chapterStart, isTrue);
    expect(blocks[2].level, 2);
    expect(blocks[2].chapterStart, isFalse);
  });

  test('collegamenti, citazioni, tabelle e codice', () {
    final blocks = markdownToBlocks('Vedi [il sito](https://example.com).\n\n'
        '> citazione\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n```\nriga di codice\n```\n');
    expect(blocks.map((b) => b.text).toList(),
        ['Vedi il sito.', 'citazione', 'a | b', '1 | 2', 'riga di codice']);
    expect(blocks[1].italic, isTrue);
  });

  test('un testo vuoto non si apre', () {
    expect(() => markdownToPdf(Uint8List.fromList(utf8.encode('\n\n'))),
        throwsFormatException);
  });

  test('il PDF ha almeno una pagina', () {
    final result = markdownToPdf(
        Uint8List.fromList(utf8.encode('# Ciao\n\nUn testo di prova.\n')));
    expect(result.pages, greaterThanOrEqualTo(1));
    final doc = PdfDocument.open(result.bytes);
    expect(doc.pageCount, result.pages);
  });

  test('riconosce i nomi .md', () {
    expect(isMarkdownFileName('note.md'), isTrue);
    expect(isMarkdownFileName('LEGGIMI.Markdown'), isTrue);
    expect(isMarkdownFileName('note.pdf'), isFalse);
    expect(isMarkdownFileName('md'), isFalse);
  });

  test('riconosce un testo senza estensione dal contenuto', () {
    Uint8List t(String x) => Uint8List.fromList(utf8.encode(x));
    expect(looksLikeMarkdownText(t('# Titolo\n\nUn testo con à è ù.\n')), isTrue);
    expect(looksLikeMarkdownText(t('%PDF-1.7\n1 0 obj')), isFalse);
    expect(looksLikeMarkdownText(t('<?xml version="1.0"?><xfdf/>')), isFalse);
    expect(looksLikeMarkdownText(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0])),
        isFalse);
    expect(looksLikeMarkdownText(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
        isFalse);
    expect(looksLikeMarkdownText(Uint8List(0)), isFalse);
  });

  test('titolo della scheda', () {
    expect(markdownTitle('note.md'), 'note.pdf');
    expect(markdownTitle('LEGGIMI.MARKDOWN'), 'LEGGIMI.pdf');
    expect(markdownTitle('.md'), 'testo.pdf');
  });
}
