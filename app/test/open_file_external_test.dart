import 'dart:typed_data';

import 'package:dart_pdf_editor_app/open_file_external.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.milanko.dartpdf/openfile');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void answer(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  Future<String?> open() => OpenFileExternal.view(
        Uint8List.fromList([1, 2, 3]),
        name: 'prova.docx',
        mimeType: 'application/msword',
        appName: 'Word',
      );

  test('su Android passa nome, tipo e contenuto e restituisce null', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    MethodCall? seen;
    answer((call) async {
      seen = call;
      return 'ok';
    });
    expect(await open(), isNull);
    expect(seen?.method, 'view');
    final args = seen!.arguments as Map;
    expect(args['name'], 'prova.docx');
    expect(args['mime'], 'application/msword');
    expect(args['bytes'], Uint8List.fromList([1, 2, 3]));
  });

  test('se nessuna app apre il file lo dice in italiano', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    answer((call) async => throw PlatformException(code: 'noapp'));
    final message = await open();
    expect(message, contains('nessuna app'));
    expect(message, contains('Word'));
  });

  test('un altro errore mostra il suo messaggio', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    answer((call) async =>
        throw PlatformException(code: 'openfile', message: 'guasto'));
    expect(await open(), contains('guasto'));
  });

  test('fuori da Android avvisa e non chiama il canale', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    var called = false;
    answer((call) async {
      called = true;
      return 'ok';
    });
    expect(await open(), contains('solo su Android'));
    expect(called, isFalse);
  });
}
