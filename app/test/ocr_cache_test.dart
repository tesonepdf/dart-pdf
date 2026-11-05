import 'dart:typed_data';

import 'package:dart_pdf_editor_app/ocr_cache.dart';
import 'package:dart_pdf_editor_app/ocr_jobs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_document/pdf_document.dart';

class _MemoryStorage implements OcrJobStorage {
  final Map<String, Uint8List> data = {};

  @override
  Future<List<String>> keys() async => data.keys.toList();
  @override
  Future<Uint8List?> read(String key) async => data[key];
  @override
  Future<void> write(String key, Uint8List bytes) async => data[key] = bytes;
  @override
  Future<void> remove(String key) async => data.remove(key);
  @override
  Future<OcrJobLease?> claim(String id) async => null;
}

PdfOcrSpan _span(String text) =>
    PdfOcrSpan(text: text, bounds: PdfRect(1, 2, 30, 40), confidence: 0.9);

void main() {
  test('saved OCR text comes back page by page', () async {
    final cache = OcrCache(_MemoryStorage());
    final hash = OcrCache.keyFor(Uint8List.fromList([1, 2, 3]));
    await cache.save(hash, 2, {
      0: [_span('ciao')],
      1: [],
    });
    final loaded = await cache.load(hash, pageCount: 2);
    expect(loaded, isNotNull);
    expect(loaded![0]!.single.text, 'ciao');
    expect(loaded[0]!.single.confidence, 0.9);
    expect(loaded[1], isEmpty);
  });

  test('a scan with no text is remembered too', () async {
    final cache = OcrCache(_MemoryStorage());
    await cache.save('abc', 1, {0: []});
    expect(await cache.load('abc', pageCount: 1), {0: isEmpty});
  });

  test('a different page count or unknown file is not a hit', () async {
    final cache = OcrCache(_MemoryStorage());
    await cache.save('abc', 2, {
      0: [_span('x')],
    });
    expect(await cache.load('abc', pageCount: 3), isNull);
    expect(await cache.load('zzz', pageCount: 2), isNull);
  });

  test('a damaged entry reads as not in memory', () async {
    final storage = _MemoryStorage();
    storage.data['cache_abc'] = Uint8List.fromList([123, 34, 118]);
    final cache = OcrCache(storage);
    expect(await cache.loadQuietly('abc', pageCount: 1), isNull);
  });

  test('the oldest documents are dropped past the limit', () async {
    final storage = _MemoryStorage();
    final cache = OcrCache(storage, maxEntries: 2);
    await cache.save('a', 1, {0: []});
    await cache.save('b', 1, {0: []});
    await cache.save('c', 1, {0: []});
    expect(await cache.load('a', pageCount: 1), isNull);
    expect(await cache.load('b', pageCount: 1), isNotNull);
    expect(await cache.load('c', pageCount: 1), isNotNull);
  });

  test('forget removes one document', () async {
    final cache = OcrCache(_MemoryStorage());
    await cache.save('a', 1, {0: []});
    await cache.forget('a');
    expect(await cache.load('a', pageCount: 1), isNull);
  });

  test('same bytes give the same key', () {
    expect(
      OcrCache.keyFor(Uint8List.fromList([1, 2])),
      OcrCache.keyFor(Uint8List.fromList([1, 2])),
    );
    expect(
      OcrCache.keyFor(Uint8List.fromList([1, 2])),
      isNot(OcrCache.keyFor(Uint8List.fromList([2, 1]))),
    );
  });
}
