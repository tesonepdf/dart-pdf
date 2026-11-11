import 'dart:convert';

/// Nome del file con l'elenco delle patch, nella release Android.
const String kPatchManifestName = 'patches.json';

/// Un APK completo della release (la base o la build corrente), come lo scrive
/// tool/apk_patch.py in patches.json.
class PatchPiece {
  const PatchPiece({
    required this.build,
    required this.asset,
    required this.sha256,
    required this.size,
  });

  final int build;
  final String asset;
  final String sha256;
  final int size;
}

/// Una patch che porta l'APK della build [from] a quello della build [to].
class PatchEdge {
  const PatchEdge({
    required this.from,
    required this.to,
    required this.asset,
    required this.size,
    required this.fromSha,
    required this.toSha,
  });

  final int from;
  final int to;
  final String asset;
  final int size;
  final String fromSha;
  final String toSha;
}

/// Il contenuto di patches.json.
class PatchManifest {
  const PatchManifest({
    required this.base,
    required this.current,
    required this.edges,
  });

  /// L'APK completo che sta nella release (di solito l'ultima base).
  final PatchPiece base;

  /// La build piu' recente.
  final PatchPiece current;

  /// Le patch pubblicate, ognuna da una build alla successiva.
  final List<PatchEdge> edges;

  static PatchManifest? tryParse(String source) {
    try {
      final json = jsonDecode(source);
      if (json is! Map<String, dynamic>) return null;
      return PatchManifest(
        base: _piece(json['base']),
        current: _piece(json['current']),
        edges: [
          for (final e in (json['patches'] as List<dynamic>? ?? const []))
            _edge(e),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  static PatchPiece _piece(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    return PatchPiece(
      build: (m['build'] as num).toInt(),
      asset: (m['asset'] as String?) ?? '',
      sha256: m['sha256'] as String,
      size: (m['size'] as num).toInt(),
    );
  }

  static PatchEdge _edge(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    return PatchEdge(
      from: (m['from'] as num).toInt(),
      to: (m['to'] as num).toInt(),
      asset: m['asset'] as String,
      size: (m['size'] as num).toInt(),
      fromSha: m['from_sha'] as String,
      toSha: m['to_sha'] as String,
    );
  }
}

/// Cosa scaricare e in che ordine per arrivare alla build corrente.
class PatchPlan {
  const PatchPlan({
    required this.useBase,
    required this.base,
    required this.target,
    required this.edges,
    required this.downloadBytes,
  });

  /// true: si parte dall'APK completo della base (da scaricare); false: si
  /// parte dall'APK gia' installato.
  final bool useBase;
  final PatchPiece base;
  final PatchPiece target;

  /// Le patch da applicare, nell'ordine.
  final List<PatchEdge> edges;

  /// Quanto si scarica in tutto.
  final int downloadBytes;
}

/// Sceglie la strada piu' leggera per portare l'app dalla build
/// [installedBuild] a quella corrente: le patch dalla versione installata, se
/// c'e' una catena continua e pesa meno dell'APK completo; altrimenti l'APK
/// base piu' le patch che da li' arrivano alla build corrente. Con
/// [forceFull] parte sempre dalla base (reinstallazione completa).
/// Null se non c'e' niente da fare o nessuna strada.
PatchPlan? planUpdate(
  PatchManifest m,
  int installedBuild, {
  bool forceFull = false,
}) {
  if (!forceFull && installedBuild >= m.current.build) return null;

  List<PatchEdge>? chainFrom(int from) {
    final out = <PatchEdge>[];
    var b = from;
    while (b != m.current.build) {
      PatchEdge? next;
      for (final e in m.edges) {
        if (e.from == b) {
          next = e;
          break;
        }
      }
      if (next == null || out.length > 200) return null;
      out.add(next);
      b = next.to;
    }
    return out;
  }

  int sum(List<PatchEdge> list) => list.fold(0, (s, e) => s + e.size);

  PatchPlan? viaPatches;
  if (!forceFull) {
    final chain = chainFrom(installedBuild);
    if (chain != null && chain.isNotEmpty) {
      viaPatches = PatchPlan(
        useBase: false,
        base: m.base,
        target: m.current,
        edges: chain,
        downloadBytes: sum(chain),
      );
    }
  }

  PatchPlan? viaBase;
  final baseChain = chainFrom(m.base.build);
  if (baseChain != null && m.base.asset.isNotEmpty) {
    viaBase = PatchPlan(
      useBase: true,
      base: m.base,
      target: m.current,
      edges: baseChain,
      downloadBytes: m.base.size + sum(baseChain),
    );
  }

  if (viaPatches != null &&
      (viaBase == null || viaPatches.downloadBytes < viaBase.downloadBytes)) {
    return viaPatches;
  }
  return viaBase;
}
