import 'dart:convert';

import 'package:http/http.dart' as http;

import 'patch_manifest.dart';
import 'update.dart' show ReleaseInfo;

/// Nome del file, nella release, con le modifiche di ogni build (lo scrive
/// tool/storico_build.py).
const String kBuildChangesName = 'build-changes.json';

/// Cosa e' cambiato in una build.
class BuildChanges {
  const BuildChanges({
    required this.build,
    required this.version,
    required this.changes,
  });

  final int build;

  /// Come si scrive la versione, per esempio `6.330.0736#312`.
  final String version;
  final List<String> changes;
}

/// Un pezzo da scaricare: una patch o l'APK completo.
class UpdateStep {
  const UpdateStep({required this.label, required this.bytes});

  final String label;
  final int bytes;
}

/// Quello che la finestra di aggiornamento mostra oltre al testo delle note:
/// le modifiche di ogni build che si salta e i pezzi da scaricare.
class UpdateDetails {
  const UpdateDetails({this.builds = const [], this.steps = const []});

  /// Dalla piu' recente alla piu' vecchia, solo le build dopo quella
  /// installata.
  final List<BuildChanges> builds;
  final List<UpdateStep> steps;

  bool get isEmpty => builds.isEmpty && steps.isEmpty;
}

/// Le build di [source] (il contenuto di build-changes.json) piu' nuove di
/// [installedBuild] e al piu' [latestBuild], dalla piu' recente. Con una build
/// installata sconosciuta (0 o meno) restano tutte. Vuota se il file e'
/// illeggibile.
List<BuildChanges> parseBuildChanges(
  String source, {
  required int installedBuild,
  int? latestBuild,
}) {
  try {
    final json = jsonDecode(source);
    if (json is! List) return const [];
    final out = <BuildChanges>[];
    for (final item in json) {
      if (item is! Map) continue;
      final build = item['build'];
      if (build is! int) continue;
      if (installedBuild > 0 && build <= installedBuild) continue;
      if (latestBuild != null && build > latestBuild) continue;
      out.add(BuildChanges(
        build: build,
        version: (item['version'] as String?) ?? '#$build',
        changes: [
          for (final c in (item['changes'] as List? ?? const []))
            if (c is String && c.trim().isNotEmpty) c.trim(),
        ],
      ));
    }
    out.sort((a, b) => b.build.compareTo(a.build));
    return out;
  } catch (_) {
    return const [];
  }
}

/// I pezzi da scaricare di un piano di aggiornamento, nell'ordine in cui si
/// applicano: l'APK completo se si parte dalla base, poi ogni patch.
List<UpdateStep> stepsFromPlan(PatchPlan plan) => [
      if (plan.useBase)
        UpdateStep(
          label: 'APK completo (build ${plan.base.build})',
          bytes: plan.base.size,
        ),
      for (final edge in plan.edges)
        UpdateStep(
          label: 'Patch ${edge.from} → ${edge.to}',
          bytes: edge.size,
        ),
    ];

/// "0.3 MB": mai 0.0, almeno 0.1.
String formatMegabytes(int bytes) {
  final mb = bytes / 1048576;
  return '${(mb < 0.1 ? 0.1 : mb).toStringAsFixed(1)} MB';
}

typedef TextFetcher = Future<String> Function(String url);

Future<String> _fetchText(String url) async {
  final response =
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }
  return utf8.decode(response.bodyBytes);
}

/// Legge dalla [release] le modifiche di ogni build saltata e, se ci sono le
/// patch, quelle da scaricare. Non lancia mai: se un file manca o non si legge
/// resta quello che c'e' e la finestra mostra le note come prima.
Future<UpdateDetails> loadUpdateDetails(
  ReleaseInfo release, {
  required int installedBuild,
  TextFetcher fetch = _fetchText,
}) async {
  final latestBuild = int.tryParse(release.buildNumber ?? '');
  var builds = const <BuildChanges>[];
  final changesUrl = release.assets[kBuildChangesName];
  if (changesUrl != null) {
    try {
      builds = parseBuildChanges(
        await fetch(changesUrl),
        installedBuild: installedBuild,
        latestBuild: latestBuild,
      );
    } catch (_) {}
  }
  var steps = const <UpdateStep>[];
  final manifestUrl = release.assets[kPatchManifestName];
  if (manifestUrl != null && installedBuild > 0) {
    try {
      final manifest = PatchManifest.tryParse(await fetch(manifestUrl));
      final plan = manifest == null ? null : planUpdate(manifest, installedBuild);
      if (plan != null) steps = stepsFromPlan(plan);
    } catch (_) {}
  }
  return UpdateDetails(builds: builds, steps: steps);
}
