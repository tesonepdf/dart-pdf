import 'dart:convert';

import 'package:dart_pdf_editor_app/windows_files.dart';
import 'package:flutter_test/flutter_test.dart';

final _h1 = 'a' * 64;
final _h2 = 'b' * 64;
final _h3 = 'c' * 64;

String _manifestJson(List<Map<String, Object>> files) =>
    jsonEncode({'build': 487, 'version': '6.325.1708', 'files': files});

Map<String, Object> _file(String path, String hash, {int size = 10}) =>
    {'path': path, 'size': size, 'sha256': hash};

void main() {
  group('WindowsFilesManifest.tryParse', () {
    test('reads the list, even with a leading BOM', () {
      final text = '\uFEFF${_manifestJson([
            _file('dartpdf.exe', _h1, size: 9000),
            _file('data/app.so', _h2),
          ])}';
      final manifest = WindowsFilesManifest.tryParse(text);
      expect(manifest, isNotNull);
      expect(manifest!.build, 487);
      expect(manifest.version, '6.325.1708');
      expect(manifest.files, hasLength(2));
      expect(manifest.files.first.path, 'dartpdf.exe');
      expect(manifest.files.first.size, 9000);
      expect(manifest.files.first.assetName, '$_h1.gz');
    });

    test('rejects paths that leave the app folder', () {
      for (final bad in [
        '../evil.dll',
        'data/../../evil.dll',
        '/abs/evil.dll',
        'C:/evil.dll',
        r'data\evil.dll',
        'data//evil.dll',
        '',
      ]) {
        expect(
          WindowsFilesManifest.tryParse(_manifestJson([_file(bad, _h1)])),
          isNull,
          reason: 'path "$bad" must be refused',
        );
      }
    });

    test('rejects a malformed checksum', () {
      expect(
        WindowsFilesManifest.tryParse(_manifestJson([_file('a.dll', 'ABC')])),
        isNull,
      );
      expect(
        WindowsFilesManifest.tryParse(
            _manifestJson([_file('a.dll', 'A' * 64)])),
        isNull,
      );
    });

    test('rejects text that is not a file list', () {
      expect(WindowsFilesManifest.tryParse('not json'), isNull);
      expect(WindowsFilesManifest.tryParse('[]'), isNull);
      expect(WindowsFilesManifest.tryParse('{"build": 1}'), isNull);
    });
  });

  group('download plan', () {
    final manifest = WindowsFilesManifest.tryParse(_manifestJson([
      _file('a.dll', _h1),
      _file('b.dll', _h2),
      _file('c.dll', _h3),
    ]))!;

    test('only missing or different files are downloaded', () {
      final needed = windowsFilesToDownload(manifest, {
        'a.dll': _h1, // identical: skipped
        'b.dll': 'd' * 64, // different
        // c.dll missing
      });
      expect(needed.map((f) => f.path), ['b.dll', 'c.dll']);
    });

    test('nothing to download when every file matches', () {
      final needed = windowsFilesToDownload(manifest, {
        'a.dll': _h1,
        'b.dll': _h2,
        'c.dll': _h3,
      });
      expect(needed, isEmpty);
    });

    test('files with the same content share one download', () {
      final twins = WindowsFilesManifest.tryParse(_manifestJson([
        _file('x/one.bin', _h1),
        _file('y/two.bin', _h1),
        _file('z.bin', _h2),
      ]))!;
      final byHash = windowsDownloadsByHash(twins.files);
      expect(byHash.keys, [_h1, _h2]);
      expect(byHash[_h1]!.map((f) => f.path), ['x/one.bin', 'y/two.bin']);
    });
  });

  group('buildWindowsApplyScript', () {
    final script = buildWindowsApplyScript(
      pid: 1234,
      stagingDir: r'C:\Temp\dartpdf-update-files',
      installDir: r'C:\Users\me\DartPDF',
      exePath: r'C:\Users\me\DartPDF\dartpdf.exe',
    );

    test('waits for the app, copies the files and relaunches', () {
      expect(script, contains('set "PID=1234"'));
      expect(script, contains(r'set "STAGING=C:\Temp\dartpdf-update-files"'));
      expect(script, contains(r'set "INSTALL=C:\Users\me\DartPDF"'));
      expect(script, contains('robocopy "%STAGING%" "%INSTALL%" /E'));
      expect(script, contains('start "" "%EXE%"'));
      expect(script.trimRight().endsWith('del "%~f0"'), isTrue);
    });

    test('uses CRLF line endings only', () {
      expect(script.contains('\r\n'), isTrue);
      expect(script.replaceAll('\r\n', '').contains('\n'), isFalse);
    });

    test('doubles percent signs in paths', () {
      final withPercent = buildWindowsApplyScript(
        pid: 1,
        stagingDir: r'C:\100%\staging',
        installDir: r'C:\100%\app',
        exePath: r'C:\100%\app\dartpdf.exe',
      );
      expect(withPercent, contains(r'set "STAGING=C:\100%%\staging"'));
    });
  });
}
