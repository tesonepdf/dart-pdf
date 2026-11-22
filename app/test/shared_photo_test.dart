import 'dart:typed_data';

import 'package:dart_pdf_editor_app/image_to_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  final image = img.Image(width: 8, height: 8);

  test('le foto si riconoscono dai primi byte, senza il nome del file', () {
    expect(looksLikeImageBytes(Uint8List.fromList(img.encodePng(image))), isTrue);
    expect(looksLikeImageBytes(Uint8List.fromList(img.encodeJpg(image))), isTrue);
    expect(looksLikeImageBytes(Uint8List.fromList(img.encodeGif(image))), isTrue);
    expect(looksLikeImageBytes(Uint8List.fromList(img.encodeBmp(image))), isTrue);
    expect(looksLikeImageBytes(Uint8List.fromList(img.encodeTiff(image))), isTrue);
  });

  test('WebP e HEIC si riconoscono dall\'intestazione', () {
    final webp = Uint8List.fromList([
      ...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBPVP8 '.codeUnits, //
    ]);
    expect(looksLikeImageBytes(webp), isTrue);
    final heic = Uint8List.fromList([
      0, 0, 0, 24, ...'ftypheic'.codeUnits, 0, 0, 0, 0, //
    ]);
    expect(looksLikeImageBytes(heic), isTrue);
    final video = Uint8List.fromList([
      0, 0, 0, 24, ...'ftypmp42'.codeUnits, 0, 0, 0, 0, //
    ]);
    expect(looksLikeImageBytes(video), isFalse);
  });

  test('un PDF, un testo o pochi byte non sono foto', () {
    expect(
        looksLikeImageBytes(
            Uint8List.fromList('%PDF-1.7\nfinto contenuto\n%%EOF'.codeUnits)),
        isFalse);
    expect(
        looksLikeImageBytes(
            Uint8List.fromList('BMW e altre auto, un testo qualunque'.codeUnits)),
        isFalse);
    expect(looksLikeImageBytes(Uint8List.fromList([0xFF, 0xD8, 0xFF])), isFalse);
    expect(looksLikeImageBytes(Uint8List(0)), isFalse);
  });
}
