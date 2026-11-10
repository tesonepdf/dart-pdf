import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_info.dart';
import 'update.dart' show dartPdfAndroidTag;

/// Risposte di GitHub tenute in memoria: GitHub senza chiave concede 60
/// richieste all'ora, quindi le righe di Informazioni condividono le stesse
/// richieste (come nell'app Turni: un'ultima run per flusso) e, se GitHub
/// blocca o manca la rete, si mostra l'ultimo esito buono.
final Map<String, ({DateTime at, String body})> _githubCache = {};
final Map<String, Future<String?>> _githubInflight = {};
const _githubTtl = Duration(seconds: 30);

Future<String?> _githubFetch(Uri uri, String key) async {
  final c = http.Client();
  try {
    final response = await c
        .get(uri, headers: const {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      _githubCache[key] = (at: DateTime.now(), body: response.body);
      return response.body;
    }
  } catch (_) {
    // rete o limite: si ripiega sull'ultimo esito buono
  } finally {
    c.close();
  }
  return _githubCache[key]?.body;
}

/// Corpo della risposta di GitHub per [path], o null se non disponibile.
/// Con un [client] di prova chiama sempre direttamente, senza memoria.
Future<String?> _githubBody(
  String path,
  Map<String, String> query, {
  http.Client? client,
}) async {
  final uri = Uri.https('api.github.com', path, query);
  if (client != null) {
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200 ? response.body : null;
    } catch (_) {
      return null;
    }
  }
  final key = uri.toString();
  final cached = _githubCache[key];
  if (cached != null && DateTime.now().difference(cached.at) < _githubTtl) {
    return cached.body;
  }
  final running = _githubInflight[key];
  if (running != null) return running;
  final f = _githubFetch(uri, key);
  _githubInflight[key] = f;
  unawaited(f.whenComplete(() => _githubInflight.remove(key)));
  return f;
}

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
    if (client == null) {
      // Stessa richiesta della riga "test dell'ultima build": una sola
      // lettura per tutte e due, poi si cerca il commit di questa build.
      final body = await _githubBody(
        '/repos/${AppInfo.repositoryOwner}/${AppInfo.repositoryName}'
        '/actions/workflows/ci.yml/runs',
        const {'branch': 'main', 'per_page': '10'},
      );
      if (body == null) return const BuildCheck(BuildCheckState.unavailable);
      try {
        final runs = (jsonDecode(body) as Map)['workflow_runs'] as List;
        final mine = runs
            .whereType<Map>()
            .where((r) => r['head_sha'] == commit)
            .firstOrNull;
        if (mine != null) {
          return fromRunsJson(jsonEncode({'workflow_runs': [mine]}));
        }
      } catch (_) {
        return const BuildCheck(BuildCheckState.unavailable);
      }
      // commit piu' vecchio delle ultime 10 run: si chiede proprio quello
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

/// Esito di un flusso di GitHub (test o scansione dei segreti) per l'ultimo
/// commit di `main`, indipendente dalla build installata: serve a vedere subito
/// come sono andati i test di una build nuova.
Future<BuildCheck> fetchLatestWorkflowCheck(
  String workflow, {
  http.Client? client,
}) async {
  final body = await _githubBody(
    '/repos/${AppInfo.repositoryOwner}/${AppInfo.repositoryName}'
    '/actions/workflows/$workflow/runs',
    const {'branch': 'main', 'per_page': '10'},
    client: client,
  );
  if (body == null) return const BuildCheck(BuildCheckState.unavailable);
  try {
    return BuildCheck.fromRunsJson(body);
  } catch (_) {
    return const BuildCheck(BuildCheckState.unavailable);
  }
}

/// Dove sta la compilazione dell'app (la build su GitHub Actions): in coda, in
/// corso (con il passo a cui è arrivata), finita bene, fallita o annullata.
///
/// È diverso da [BuildCheck], che dice come sono andati i test del commit da
/// cui è stata compilata l'app installata: qui si guarda l'ultima build,
/// anche se è ancora in elaborazione e non è ancora l'app installata.
enum BuildRunState {
  queued,
  running,
  succeeded,
  failed,
  cancelled,
  none,
  unavailable,
}

class BuildRun {
  const BuildRun(
    this.state, {
    this.number,
    this.runId,
    this.url,
    this.startedAt,
    this.job,
    this.step,
    this.stepsDone,
    this.stepCount,
  });

  final BuildRunState state;

  /// Il numero della build (il `#N` in testa al titolo del commit).
  final int? number;

  /// L'identificativo della run su GitHub, per chiedere i dettagli.
  final int? runId;

  /// Pagina della run, da aprire per i dettagli.
  final Uri? url;

  /// Quando è partita la run.
  final DateTime? startedAt;

  /// Il lavoro (job) in corso, per esempio "apk".
  final String? job;

  /// Il passo in corso dentro il lavoro.
  final String? step;

  /// Quanti passi del lavoro in corso sono già finiti, e quanti sono in tutto.
  final int? stepsDone;
  final int? stepCount;

  /// Vero se la build è in coda o in elaborazione.
  bool get inProgress =>
      state == BuildRunState.queued || state == BuildRunState.running;

  static final _numberInTitle = RegExp(r'#(\d+)');

  /// Il flusso e il ramo della build di questa app: la build di prova ha il
  /// suo (vedi `.github/workflows/build-prova.yml`).
  static (String workflow, String branch) get _source =>
      dartPdfAndroidTag == 'app-android-prova'
          ? ('build-prova.yml', 'prova-sviluppatore')
          : ('build.yml', 'main');

  /// Legge l'ultima run dalla risposta dell'API `actions/workflows/.../runs`.
  @visibleForTesting
  static BuildRun fromRunsJson(String body) {
    final decoded = jsonDecode(body);
    final runs = decoded is Map ? decoded['workflow_runs'] : null;
    if (runs is! List || runs.isEmpty) {
      return const BuildRun(BuildRunState.none);
    }
    final run = runs.first as Map;
    final status = run['status'] as String?;
    final conclusion = run['conclusion'] as String?;
    final fromTitle =
        _numberInTitle.firstMatch(run['display_title'] as String? ?? '');
    final state = switch ((status, conclusion)) {
      ('completed', 'success') => BuildRunState.succeeded,
      ('completed', 'cancelled' || 'skipped') => BuildRunState.cancelled,
      ('completed', _) => BuildRunState.failed,
      ('queued' || 'waiting' || 'pending' || 'requested', _) =>
        BuildRunState.queued,
      _ => BuildRunState.running,
    };
    return BuildRun(
      state,
      number: fromTitle != null
          ? int.parse(fromTitle.group(1)!)
          : run['run_number'] as int?,
      runId: run['id'] as int?,
      url: Uri.tryParse(run['html_url'] as String? ?? ''),
      startedAt: DateTime.tryParse(
          (run['run_started_at'] ?? run['created_at']) as String? ?? ''),
    );
  }

  /// Aggiunge il lavoro e il passo in corso, letti dalla risposta dell'API
  /// `actions/runs/<id>/jobs`. Se non c'è un lavoro in corso resta com'è.
  @visibleForTesting
  BuildRun withJobs(String body) {
    final decoded = jsonDecode(body);
    final jobs = decoded is Map ? decoded['jobs'] : null;
    if (jobs is! List) return this;
    final current = jobs
        .whereType<Map>()
        .where((j) => j['status'] == 'in_progress')
        .firstOrNull;
    if (current == null) return this;
    final steps = (current['steps'] is List
        ? (current['steps'] as List).whereType<Map>().toList()
        : <Map>[]);
    final running =
        steps.where((s) => s['status'] == 'in_progress').firstOrNull;
    return BuildRun(
      state,
      number: number,
      runId: runId,
      url: url,
      startedAt: startedAt,
      job: current['name'] as String?,
      step: running?['name'] as String?,
      stepsDone: steps.where((s) => s['status'] == 'completed').length,
      stepCount: steps.length,
    );
  }

  /// Chiede a GitHub l'ultima build e, se è in elaborazione, a che punto è.
  /// Il repository è pubblico: non serve nessuna chiave.
  static Future<BuildRun> fetch({http.Client? client}) async {
    final base = '/repos/${AppInfo.repositoryOwner}/${AppInfo.repositoryName}';
    try {
      final (workflow, branch) = _source;
      final body = await _githubBody(
        '$base/actions/workflows/$workflow/runs',
        {'branch': branch, 'per_page': '1'},
        client: client,
      );
      if (body == null) return const BuildRun(BuildRunState.unavailable);
      final run = fromRunsJson(body);
      if (run.state != BuildRunState.running || run.runId == null) return run;
      final jobs = await _githubBody(
        '$base/actions/runs/${run.runId}/jobs',
        const {'per_page': '10'},
        client: client,
      );
      // I dettagli del passo sono un di più: la build in corso si vede lo stesso.
      return jobs == null ? run : run.withJobs(jobs);
    } catch (_) {
      return const BuildRun(BuildRunState.unavailable);
    }
  }
}
