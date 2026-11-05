import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf_document/pdf_document.dart';

import 'ocr_jobs.dart';

/// La memoria dell'OCR già fatto.
///
/// Quando un documento viene letto con l'OCR, il testo riconosciuto (pagina
/// per pagina) resta salvato qui, con chiave l'impronta del file. Alla
/// riapertura dello stesso file il testo si rimette subito sulle pagine, senza
/// rifare la scansione e senza aspettare.
///
/// Usa lo stesso archivio privato dei lavori OCR ([OcrJobStorage]), con chiavi
/// che iniziano per `cache_`: non si mescola con i lavori in corso.
class OcrCache {
  OcrCache(this.storage, {this.maxEntries = 150});

  final OcrJobStorage storage;

  /// Quanti documenti tenere al massimo: oltre, si eliminano i più vecchi.
  final int maxEntries;

  static const _indexKey = 'cache_index';
  static const _version = 1;

  /// L'impronta del file: la chiave con cui si ritrova il suo OCR.
  static String keyFor(Uint8List bytes) => sha256.convert(bytes).toString();

  String _key(String hash) => 'cache_$hash';

  /// Il testo riconosciuto per [hash], o null se quel file non è in memoria
  /// (o se la copia salvata non corrisponde al numero di pagine [pageCount]).
  Future<Map<int, List<PdfOcrSpan>>?> load(
    String hash, {
    required int pageCount,
  }) async {
    final bytes = await storage.read(_key(hash));
    if (bytes == null) return null;
    try {
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (map['v'] != _version || map['pageCount'] != pageCount) return null;
      final pages = map['pages'] as List;
      if (pages.length != pageCount) return null;
      return {
        for (var i = 0; i < pages.length; i++)
          i: [
            for (final value in pages[i] as List)
              PdfOcrSpan(
                text: (value as List)[0] as String,
                bounds: PdfRect(
                  (value[1] as num).toDouble(),
                  (value[2] as num).toDouble(),
                  (value[3] as num).toDouble(),
                  (value[4] as num).toDouble(),
                ),
                confidence: (value[5] as num).toDouble(),
              ),
          ],
      };
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Salva il testo riconosciuto per [hash]. Anche una scansione senza nessun
  /// testo si ricorda, così non viene rifatta a ogni apertura.
  Future<void> save(
    String hash,
    int pageCount,
    Map<int, List<PdfOcrSpan>> pages,
  ) async {
    final encoded = jsonEncode({
      'v': _version,
      'pageCount': pageCount,
      'pages': [
        for (var i = 0; i < pageCount; i++)
          [
            for (final s in pages[i] ?? const <PdfOcrSpan>[])
              [
                s.text,
                s.bounds.left,
                s.bounds.bottom,
                s.bounds.right,
                s.bounds.top,
                s.confidence,
              ],
          ],
      ],
    });
    await storage.write(_key(hash), Uint8List.fromList(utf8.encode(encoded)));
    final index = await _readIndex();
    index
      ..remove(hash)
      ..add(hash);
    while (index.length > maxEntries) {
      await storage.remove(_key(index.removeAt(0)));
    }
    await storage.write(
      _indexKey,
      Uint8List.fromList(utf8.encode(jsonEncode(index))),
    );
  }

  /// Dimentica l'OCR di [hash] (per esempio per rifarlo da capo).
  Future<void> forget(String hash) async {
    await storage.remove(_key(hash));
    final index = await _readIndex();
    index.remove(hash);
    await storage.write(
      _indexKey,
      Uint8List.fromList(utf8.encode(jsonEncode(index))),
    );
  }

  Future<List<String>> _readIndex() async {
    try {
      final bytes = await storage.read(_indexKey);
      if (bytes == null) return [];
      return [
        for (final value in jsonDecode(utf8.decode(bytes)) as List)
          value as String,
      ];
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  /// Come [save], ma senza mai far fallire chi lo chiama: la memoria è un
  /// aiuto, non deve mai bloccare il lavoro dell'OCR.
  Future<void> saveQuietly(
    String hash,
    int pageCount,
    Map<int, List<PdfOcrSpan>> pages,
  ) async {
    try {
      await save(hash, pageCount, pages);
    } catch (error) {
      debugPrint('OCR cache not saved: $error');
    }
  }

  /// Come [load], ma un errore di lettura vale "non in memoria".
  Future<Map<int, List<PdfOcrSpan>>?> loadQuietly(
    String hash, {
    required int pageCount,
  }) async {
    try {
      return await load(hash, pageCount: pageCount);
    } catch (error) {
      debugPrint('OCR cache not readable: $error');
      return null;
    }
  }
}
