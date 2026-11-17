// Peso e data dei file nella Home.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dart_pdf_editor_app/file_info.dart';

void main() {
  test('il peso ha la virgola e multipli di 1024', () {
    expect(formatFileSize(0), '0 B');
    expect(formatFileSize(512), '512 B');
    expect(formatFileSize(1024), '1,0 KB');
    expect(formatFileSize(314777), '307,4 KB');
    expect(formatFileSize(2 * 1024 * 1024), '2,0 MB');
    expect(formatFileSize(3 * 1024 * 1024 * 1024), '3,0 GB');
  });

  test('la data ha il giorno, il mese e l\'ora; l\'anno solo se e\' diverso',
      () {
    final now = DateTime(2026, 11, 17);
    expect(formatFileDate(DateTime(2026, 11, 17, 8, 5), now), '17 nov, 08:05');
    expect(formatFileDate(DateTime(2025, 1, 3, 23, 59), now),
        '3 gen 2025, 23:59');
  });

  test('legge peso e ultima modifica da un file vero', () async {
    final dir = Directory.systemTemp.createTempSync('file_info_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/a.pdf')..writeAsBytesSync(List.filled(1500, 7));

    final info = await readFileInfo(file.path);
    expect(info?.size, 1500);
    expect(
        DateTime.now().difference(info!.modified).inMinutes.abs(), lessThan(5));
  });

  test('un file che non c\'e\' non da\' informazioni', () async {
    expect(await readFileInfo('/non/esiste.pdf'), isNull);
  });
}
