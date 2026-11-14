import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:dart_pdf_editor_app/photo_source_store.dart';

void main() {
  late Directory root;
  late PathProviderPlatform originalPathProvider;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    root = Directory.systemTemp.createTempSync('dartpdf_photo_source_test');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TempPathProvider(root.path);
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    root.deleteSync(recursive: true);
  });

  test('la foto si ritrova dai byte del PDF che ne e\' nato', () async {
    final pdf = Uint8List.fromList(List<int>.generate(300, (i) => i % 251));
    final photo = Uint8List.fromList([9, 8, 7, 6, 5]);

    await rememberPhotoSource(pdf, photo);

    expect(await recallPhotoSource(pdf), photo);
  });

  test('un PDF qualsiasi non trova nessuna foto', () async {
    final pdf = Uint8List.fromList(List<int>.generate(300, (i) => i % 251));
    await rememberPhotoSource(pdf, Uint8List.fromList([1, 2, 3]));

    // stessa lunghezza ma contenuto diverso, e lunghezza diversa
    final sameLength = Uint8List.fromList(List<int>.filled(300, 7));
    expect(await recallPhotoSource(sameLength), isNull);
    expect(await recallPhotoSource(Uint8List(10)), isNull);
  });

  test('senza nessuna foto ricordata non si trova niente', () async {
    expect(await recallPhotoSource(Uint8List.fromList([1, 2, 3])), isNull);
  });

  test('si tengono solo le 20 foto piu recenti', () async {
    for (var i = 0; i < 25; i++) {
      final pdf = Uint8List.fromList(List<int>.filled(50 + i, i));
      await rememberPhotoSource(pdf, Uint8List.fromList([i]));
    }

    final files = Directory('${root.path}/photo_sources')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.photo'))
        .toList();
    expect(files.length, 20);
  });
}

class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}
