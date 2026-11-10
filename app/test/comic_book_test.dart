// Fumetti .cbz (comic_book.dart): nomi, ordine, lettura dello zip e PDF.
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_document/pdf_document.dart';

import 'package:dart_pdf_editor_app/comic_book.dart';
import 'package:dart_pdf_editor_app/pdf_conversions.dart';

Uint8List _png(int width) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: 4)));

Uint8List _zip(Map<String, List<int>> files) {
  final archive = Archive();
  files.forEach((name, bytes) =>
      archive.addFile(ArchiveFile.bytes(name, Uint8List.fromList(bytes))));
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  group('nomi', () {
    test('si tengono solo le immagini vere', () {
      expect(isComicImageName('001.jpg'), isTrue);
      expect(isComicImageName('cap1/pag02.PNG'), isTrue);
      expect(isComicImageName('ComicInfo.xml'), isFalse);
      expect(isComicImageName('__MACOSX/001.jpg'), isFalse);
      expect(isComicImageName('.DS_Store'), isFalse);
      expect(isComicImageName('Thumbs.db'), isFalse);
      expect(isComicImageName('senzaestensione'), isFalse);
    });

    test('l\'ordine è naturale: 2 prima di 10, maiuscole ininfluenti', () {
      final names = ['pag10.jpg', 'Pag2.jpg', 'pag1.jpg', 'pag3.jpg']
        ..sort(naturalCompare);
      expect(names, ['pag1.jpg', 'Pag2.jpg', 'pag3.jpg', 'pag10.jpg']);
    });

    test('il titolo toglie .cbz e aggiunge .pdf', () {
      expect(comicTitle('Dylan Dog 1.cbz'), 'Dylan Dog 1.pdf');
      expect(comicTitle('storia.ZIP'), 'storia.pdf');
      expect(comicTitle('.cbz'), 'fumetto.pdf');
    });
  });

  group('lo zip', () {
    test('legge le immagini in ordine e salta il resto', () {
      final a = _png(1);
      final b = _png(2);
      final c = _png(3);
      final cbz = _zip({
        'pag10.png': c,
        'ComicInfo.xml': [60, 62],
        'pag2.png': b,
        '__MACOSX/pag1.png': [1, 2, 3],
        'pag1.png': a,
      });
      final images = comicImages(cbz);
      expect(images, [a, b, c]);
    });

    test('uno zip senza immagini o un file che non è uno zip danno errore', () {
      expect(() => comicImages(_zip({'testo.txt': [65]})),
          throwsA(isA<FormatException>()));
      expect(() => comicImages(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<FormatException>()));
    });
  });

  test('il PDF ha una pagina per immagine', () async {
    final images = comicImages(_zip({'1.png': _png(2), '2.png': _png(3)}));
    final result = await photosToPdfAsync(images, PhotoPdfPage.photoSize);
    expect(PdfDocument.open(result.bytes).pageCount, 2);
    expect(result.skipped, 0);
  });

  group('capitoli e informazioni', () {
    test('le cartelle diventano capitoli, tolta quella comune', () {
      expect(
        comicChapterNames(['serie/cap1/01.png', 'serie/cap1/02.png', 'serie/cap2/01.png']),
        ['cap1', 'cap1', 'cap2'],
      );
    });

    test('con una sola cartella non ci sono capitoli', () {
      expect(comicChapterNames(['a/1.png', 'a/2.png']), [null, null]);
      expect(comicChapterNames(['1.png', '2.png']), [null, null]);
    });

    test('ComicInfo.xml: titolo, serie e numero', () {
      final info = parseComicInfo(
          '<ComicInfo><Title>La &amp; fine</Title><Series>Dylan</Series><Number>3</Number></ComicInfo>');
      expect(info, (title: 'La & fine', series: 'Dylan', number: '3'));
      expect(comicTitleFor('x.cbz', info), 'Dylan 3 - La & fine.pdf');
      expect(comicTitleFor('x.cbz', null), 'x.pdf');
    });
  });

  test('comicToPdf: una pagina per immagine e segnalibri per capitolo', () {
    final cbz = _zip({
      'cap1/1.png': _png(2),
      'cap1/2.png': _png(3),
      'cap2/1.png': _png(4),
      'ComicInfo.xml': utf8.encode('<ComicInfo><Series>S</Series></ComicInfo>'),
    });
    final result = comicToPdf(cbz);
    expect(result.pages, 3);
    expect(result.skipped, 0);
    expect(result.chapters.map((c) => c.title), ['cap1', 'cap2']);
    expect(result.chapters.map((c) => c.page), [0, 2]);
    expect(result.info?.series, 'S');
    expect(PdfDocument.open(result.bytes).pageCount, 3);
  });
}
