import 'package:dart_pdf_editor_app/ocr_background.dart';
import 'package:dart_pdf_editor_app/ocr_lifecycle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.milanko.dartpdf/ocr_service');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() async {
    await OcrBackgroundService.stop();
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  void mockService({required bool accepts}) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return call.method == 'start' ? accepts : null;
    });
  }

  test('without the service a hidden app pauses OCR', () {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(OcrBackgroundService.active, isFalse);
    expect(ocrShouldPause, isTrue);
  });

  test('with the service running a hidden app keeps going', () async {
    mockService(accepts: true);
    await OcrBackgroundService.start(title: 'a.pdf', page: 1, pageCount: 3);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(OcrBackgroundService.active, isTrue);
    expect(ocrShouldPause, isFalse);

    await OcrBackgroundService.update(title: 'a.pdf', page: 2, pageCount: 3);
    await OcrBackgroundService.stop();
    expect(OcrBackgroundService.active, isFalse);
    expect(ocrShouldPause, isTrue);
    expect(calls, ['start', 'update', 'stop']);
  });

  test('a refused service leaves the normal pause in place', () async {
    mockService(accepts: false);
    await OcrBackgroundService.start(title: 'a.pdf', page: 1, pageCount: 3);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(OcrBackgroundService.active, isFalse);
    expect(ocrShouldPause, isTrue);
  });

  test('a missing plugin is not an error', () async {
    await OcrBackgroundService.start(title: 'a.pdf', page: 1, pageCount: 3);
    expect(OcrBackgroundService.active, isFalse);
  });
}
