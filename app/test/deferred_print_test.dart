import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dart_pdf_editor_app/deferred_print.dart';

DeferredPrintItem _item(String id, DateTime at, {String name = 'Gruppo'}) =>
    DeferredPrintItem(
      id: id,
      name: name,
      summary: 'Solo fronte · Verticale · A4',
      pages: 3,
      sheets: 2,
      createdAt: at,
    );

void main() {
  test('il gruppo si salva e si rilegge dal JSON', () {
    final item = _item('a', DateTime(2026, 11, 14, 10, 30), name: 'Contratto');
    final back = DeferredPrintItem.fromJson(item.toJson());
    expect(back, isNotNull);
    expect(back!.id, 'a');
    expect(back.name, 'Contratto');
    expect(back.pages, 3);
    expect(back.sheets, 2);
    expect(back.twoSided, isFalse);
  });

  test('un JSON rotto non da un gruppo', () {
    expect(DeferredPrintItem.fromJson('non e json'), isNull);
    expect(DeferredPrintItem.fromJson('{"id": 5}'), isNull);
  });

  test('la coda elenca dal piu vecchio, rinomina e toglie', () async {
    final store = MemoryDeferredPrintStore();
    await store.add(_item('b', DateTime(2026, 11, 14, 12)), Uint8List(2));
    await store.add(_item('a', DateTime(2026, 11, 14, 9)), Uint8List(1));
    expect((await store.list()).map((i) => i.id), ['a', 'b']);

    await store.rename('a', 'Fattura');
    expect((await store.list()).first.name, 'Fattura');
    expect((await store.read('b'))!.length, 2);

    await store.remove('a');
    expect((await store.list()).map((i) => i.id), ['b']);
    expect(await store.read('a'), isNull);
  });

  test('il riepilogo dice fronte/retro, orientamento e carta', () {
    expect(
      deferredSummary(
          twoSided: true, orientation: 'Orizzontale', paper: 'A4'),
      'Fronte/retro · Orizzontale · A4',
    );
    expect(
      deferredSummary(twoSided: false, orientation: '', paper: ''),
      'Solo fronte',
    );
  });
}
