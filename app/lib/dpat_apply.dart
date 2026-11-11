import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Patch non valida, troncata o non adatta all'APK da cui si parte.
class PatchFormatException implements Exception {
  const PatchFormatException(this.message);
  final String message;
  @override
  String toString() => 'Patch: $message';
}

/// L'utente ha annullato mentre si preparava l'aggiornamento.
class PatchCancelledException implements Exception {
  const PatchCancelledException();
  @override
  String toString() => 'Patch annullata';
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// Lettore a blocchi del flusso gia' decompresso della patch.
class _Reader {
  _Reader(Stream<List<int>> source) : _it = StreamIterator<List<int>>(source);

  final StreamIterator<List<int>> _it;
  List<int> _buf = const <int>[];
  int _pos = 0;

  Future<bool> _fill() async {
    while (_pos >= _buf.length) {
      if (!await _it.moveNext()) return false;
      _buf = _it.current;
      _pos = 0;
    }
    return true;
  }

  Future<Uint8List> readExact(int n) async {
    final out = Uint8List(n);
    var got = 0;
    while (got < n) {
      if (!await _fill()) throw const PatchFormatException('patch troncata');
      final take = math.min(n - got, _buf.length - _pos);
      out.setRange(got, got + take, _buf, _pos);
      got += take;
      _pos += take;
    }
    return out;
  }

  Future<Uint8List?> readUpTo(int max) async {
    if (!await _fill()) return null;
    final take = math.min(max, _buf.length - _pos);
    final out = Uint8List.fromList(_buf.sublist(_pos, _pos + take));
    _pos += take;
    return out;
  }

  Future<void> close() => _it.cancel();
}

/// SHA-256 di un file, in esadecimale minuscolo, letto a blocchi.
Future<String> sha256OfFile(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString();

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Applica una patch DPAT1 (vedi tool/apk_patch.py) a [oldPath] e scrive il
/// risultato in [outPath]. Tutto a blocchi: non carica gli APK in memoria.
/// Alla fine confronta lo SHA-256 con quello scritto nella patch e lancia
/// [PatchFormatException] se non coincide.
Future<void> applyDpatFile({
  required String oldPath,
  required String patchPath,
  required String outPath,
  bool Function()? isCancelled,
}) async {
  final oldFile = await File(oldPath).open();
  final out = await File(outPath).open(mode: FileMode.write);
  final reader = _Reader(File(patchPath).openRead().transform(gzip.decoder));
  final sink = _DigestSink();
  final hash = sha256.startChunkedConversion(sink);
  try {
    final head = await reader.readExact(86);
    const magic = [0x44, 0x50, 0x41, 0x54, 0x31, 0x00]; // "DPAT1\0"
    for (var i = 0; i < magic.length; i++) {
      if (head[i] != magic[i]) {
        throw const PatchFormatException("non e' una patch DPAT1");
      }
    }
    final hd = ByteData.sublistView(head);
    final oldSize = hd.getUint64(6, Endian.little);
    final newSize = hd.getUint64(46, Endian.little);
    final newSha = head.sublist(54, 86);
    if (await oldFile.length() != oldSize) {
      throw const PatchFormatException("la patch non e' per questo APK");
    }

    var written = 0;
    while (true) {
      if (isCancelled?.call() ?? false) throw const PatchCancelledException();
      final op = (await reader.readExact(1))[0];
      if (op == 0) break;
      if (op == 1) {
        final b = ByteData.sublistView(await reader.readExact(16));
        final pos = b.getUint64(0, Endian.little);
        var len = b.getUint64(8, Endian.little);
        if (pos + len > oldSize) {
          throw const PatchFormatException("copia fuori dall'APK vecchio");
        }
        await oldFile.setPosition(pos);
        while (len > 0) {
          final chunk = await oldFile.read(math.min(len, 1 << 20));
          if (chunk.isEmpty) {
            throw const PatchFormatException('APK vecchio troncato');
          }
          await out.writeFrom(chunk);
          hash.add(chunk);
          written += chunk.length;
          len -= chunk.length;
        }
      } else if (op == 2) {
        var len = ByteData.sublistView(await reader.readExact(8))
            .getUint64(0, Endian.little);
        while (len > 0) {
          final chunk = await reader.readUpTo(math.min(len, 1 << 20));
          if (chunk == null) {
            throw const PatchFormatException('patch troncata');
          }
          await out.writeFrom(chunk);
          hash.add(chunk);
          written += chunk.length;
          len -= chunk.length;
        }
      } else {
        throw PatchFormatException('operazione sconosciuta ($op)');
      }
    }
    hash.close();
    final digest = sink.value;
    if (digest == null ||
        written != newSize ||
        !_sameBytes(digest.bytes, newSha)) {
      throw const PatchFormatException("l'APK ricostruito non coincide");
    }
  } finally {
    await reader.close();
    await oldFile.close();
    await out.close();
  }
}
