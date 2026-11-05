import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_info.dart';

/// Come sono andati i test automatici (la CI di GitHub) per il commit da cui
/// è stata compilata questa build.
enum BuildCheckState { passed, failed, running, notStarted, unavailable }

class BuildCheck {
  const BuildCheck(this.state, {this.runNumber, this.url});

  final BuildCheckState state;

  /// Numero della run di GitHub Actions (non è il numero della build).
  final int? runNumber;

  /// Pagina della run, da aprire per i dettagli.
  final Uri? url;

  /// Legge l'esito dalla risposta dell'API `actions/workflows/ci.yml/runs`.
  @visibleForTesting
  static BuildCheck fromRunsJson(String body) {
    final decoded = jsonDecode(body);
    final runs = decoded is Map ? decoded['workflow_runs'] : null;
    if (runs is! List || runs.isEmpty) {
      return const BuildCheck(BuildCheckState.notStarted);
    }
    final run = runs.first as Map;
    final status = run['status'] as String?;
    final conclusion = run['conclusion'] as String?;
    final url = Uri.tryParse(run['html_url'] as String? ?? '');
    final number = run['run_number'] as int?;
    final state = switch ((status, conclusion)) {
      ('completed', 'success') => BuildCheckState.passed,
      ('completed', 'cancelled' || 'skipped') => BuildCheckState.unavailable,
      ('completed', _) => BuildCheckState.failed,
      _ => BuildCheckState.running,
    };
    return BuildCheck(state, runNumber: number, url: url);
  }

  /// Chiede a GitHub l'esito della CI per [commit] (il commit della build).
  /// Il repository è pubblico: non serve nessuna chiave.
  static Future<BuildCheck> fetch({
    String commit = AppInfo.buildCommit,
    http.Client? client,
  }) async {
    if (commit.isEmpty || commit == 'unknown') {
      return const BuildCheck(BuildCheckState.unavailable);
    }
    final own = client == null;
    final c = client ?? http.Client();
    try {
      final response = await c
          .get(
            Uri.https(
              'api.github.com',
              '/repos/${AppInfo.repositoryOwner}/${AppInfo.repositoryName}'
                  '/actions/workflows/ci.yml/runs',
              {'head_sha': commit, 'per_page': '1'},
            ),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return const BuildCheck(BuildCheckState.unavailable);
      }
      return fromRunsJson(response.body);
    } catch (_) {
      return const BuildCheck(BuildCheckState.unavailable);
    } finally {
      if (own) c.close();
    }
  }
}
