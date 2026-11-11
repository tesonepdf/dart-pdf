import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_pdf_editor_app/dpat_apply.dart';
import 'package:dart_pdf_editor_app/patch_manifest.dart';
import 'package:dart_pdf_editor_app/patch_runner_io.dart';

// old.bin / new.bin / patch.dpat sono creati da tool/apk_patch.py: la prova
// controlla che il lato Dart legga il formato scritto dal lato Python.
final _old = File('test/data/dpat/old.bin').readAsBytesSync();
final _new = File('test/data/dpat/new.bin').readAsBytesSync();
final _patch = File('test/data/dpat/patch.dpat').readAsBytesSync();

String _sha(List<int> bytes) => sha256.convert(bytes).toString();

String _manifest() => jsonEncode({
      'version': 1,
      'base': {
        'build': 1,
        'asset': 'DartPDF-Android.apk',
        'sha256': _sha(_old),
        'size': _old.length,
      },
      'current': {'build': 2, 'sha256': _sha(_new), 'size': _new.length},
      'patches': [
        {
          'from': 1,
          'to': 2,
          'asset': 'patch-1-2.dpat',
          'size': _patch.length,
          'from_sha': _sha(_old),
          'to_sha': _sha(_new),
        },
      ],
    });

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('dpat-test-'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('applyDpatFile', () {
    test('ricostruisce il file nuovo dalla patch scritta da Python', () async {
      File('${tmp.path}/old').writeAsBytesSync(_old);
      File('${tmp.path}/p').writeAsBytesSync(_patch);
      await applyDpatFile(
        oldPath: '${tmp.path}/old',
        patchPath: '${tmp.path}/p',
        outPath: '${tmp.path}/out',
      );
      expect(File('${tmp.path}/out').readAsBytesSync(), _new);
    });

    test('rifiuta un file di partenza diverso', () async {
      File('${tmp.path}/old').writeAsBytesSync([..._old]..[0] ^= 1);
      File('${tmp.path}/p').writeAsBytesSync(_patch);
      await expectLater(
        applyDpatFile(
          oldPath: '${tmp.path}/old',
          patchPath: '${tmp.path}/p',
          outPath: '${tmp.path}/out',
        ),
        throwsA(isA<PatchFormatException>()),
      );
    });

    test('rifiuta una patch troncata', () async {
      File('${tmp.path}/old').writeAsBytesSync(_old);
      File('${tmp.path}/p')
          .writeAsBytesSync(_patch.sublist(0, _patch.length ~/ 2));
      await expectLater(
        applyDpatFile(
          oldPath: '${tmp.path}/old',
          patchPath: '${tmp.path}/p',
          outPath: '${tmp.path}/out',
        ),
        throwsA(anything),
      );
    });
  });

  group('planUpdate', () {
    final m = PatchManifest.tryParse(_manifest())!;

    test('dalla build vecchia usa la patch', () {
      final plan = planUpdate(m, 1)!;
      expect(plan.useBase, isFalse);
      expect(plan.edges.single.to, 2);
    });

    test('gia aggiornato: niente da fare', () {
      expect(planUpdate(m, 2), isNull);
    });

    test('build sconosciuta: riparte dalla base', () {
      expect(planUpdate(m, 0)!.useBase, isTrue);
    });

    test('forceFull parte sempre dalla base', () {
      final plan = planUpdate(m, 2, forceFull: true)!;
      expect(plan.useBase, isTrue);
      expect(plan.edges.length, 1);
    });

    test('elenco rotto: null', () {
      expect(PatchManifest.tryParse('non json'), isNull);
      expect(PatchManifest.tryParse('{"x": 1}'), isNull);
    });
  });

  group('runPatchPlan', () {
    final assets = {
      kPatchManifestName: 'https://x/$kPatchManifestName',
      'DartPDF-Android.apk': 'https://x/DartPDF-Android.apk',
      'patch-1-2.dpat': 'https://x/patch-1-2.dpat',
    };
    final files = <String, List<int>>{
      kPatchManifestName: utf8.encode(_manifest()),
      'DartPDF-Android.apk': _old,
      'patch-1-2.dpat': _patch,
    };

    Future<void> download(
      String url,
      String path, {
      int? expectedSize,
      required void Function(int bytes) onBytes,
    }) async {
      final bytes = files[url.split('/').last]!;
      File(path).writeAsBytesSync(bytes);
      onBytes(bytes.length);
    }

    test('dalla build installata scarica solo la patch', () async {
      File('${tmp.path}/installed.apk').writeAsBytesSync(_old);
      final work = Directory('${tmp.path}/work');
      final fractions = <double?>[];
      final result = await runPatchPlan(
        assets: assets,
        installedBuild: 1,
        installedApkPath: '${tmp.path}/installed.apk',
        workDir: work,
        download: download,
        onProgress: fractions.add,
      );
      expect(result, isNotNull);
      expect(File(result!).readAsBytesSync(), _new);
      expect(fractions, contains(1.0));
    });

    test('ripristino: parte dall\'APK base e applica le patch', () async {
      final work = Directory('${tmp.path}/work');
      final result = await runPatchPlan(
        assets: assets,
        installedBuild: 2,
        installedApkPath: null,
        workDir: work,
        download: download,
        forceFull: true,
      );
      expect(File(result!).readAsBytesSync(), _new);
    });

    test('APK installato diverso: ricade sull\'APK base', () async {
      File('${tmp.path}/installed.apk').writeAsBytesSync([..._old]..[10] ^= 1);
      final result = await runPatchPlan(
        assets: assets,
        installedBuild: 1,
        installedApkPath: '${tmp.path}/installed.apk',
        workDir: Directory('${tmp.path}/work'),
        download: download,
      );
      expect(File(result!).readAsBytesSync(), _new);
    });

    test('senza elenco delle patch restituisce null', () async {
      final result = await runPatchPlan(
        assets: {...assets}..remove(kPatchManifestName),
        installedBuild: 1,
        installedApkPath: null,
        workDir: Directory('${tmp.path}/work'),
        download: download,
      );
      expect(result, isNull);
    });

    test('patch corrotta: null e cartella pulita', () async {
      File('${tmp.path}/installed.apk').writeAsBytesSync(_old);
      final work = Directory('${tmp.path}/work');
      Future<void> bad(
        String url,
        String path, {
        int? expectedSize,
        required void Function(int bytes) onBytes,
      }) async {
        final name = url.split('/').last;
        final bytes = [...files[name]!];
        if (name.endsWith('.dpat')) bytes[bytes.length ~/ 2] ^= 0xff;
        File(path).writeAsBytesSync(bytes);
        onBytes(bytes.length);
      }

      final result = await runPatchPlan(
        assets: assets,
        installedBuild: 1,
        installedApkPath: '${tmp.path}/installed.apk',
        workDir: work,
        download: bad,
      );
      expect(result, isNull);
      expect(work.listSync(), isEmpty);
    });

    test('annullamento', () async {
      File('${tmp.path}/installed.apk').writeAsBytesSync(_old);
      await expectLater(
        runPatchPlan(
          assets: assets,
          installedBuild: 1,
          installedApkPath: '${tmp.path}/installed.apk',
          workDir: Directory('${tmp.path}/work'),
          download: download,
          isCancelled: () => true,
        ),
        throwsA(isA<PatchCancelledException>()),
      );
    });
  });
}
