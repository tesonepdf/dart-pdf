import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_log.dart';
import 'build_check.dart';

/// I flussi di GitHub che finiscono nel Log: file e nome mostrato.
const List<(String file, String label)> workflowLogFiles = [
  ('build.yml', 'Build'),
  ('ci.yml', 'CI'),
  ('secret-scan.yml', 'Secret scan'),
];

const _seenKey = 'dart_pdf_editor_app.workflow_log_seen_v1';
const _seenMax = 300;

/// Una voce del Log che viene da GitHub, con la chiave che serve a non
/// scriverla due volte.
class WorkflowLogItem {
  const WorkflowLogItem({
    required this.key,
    required this.level,
    required this.context,
    required this.message,
    required this.time,
  });

  final String key;
  final AppLogLevel level;
  final String context;
  final String message;
  final DateTime time;
}

String _firstLine(String text) => text.split('\n').first.trim();

/// Trasforma la risposta di GitHub per un flusso in voci del Log:
/// - per ogni commit nuovo, "Push riuscito" (la run esiste, quindi il push
///   e' arrivato);
/// - per ogni run finita, un esito: riuscita nel Log, fallita negli Errori.
/// Le run in corso, annullate o piu' vecchie di 14 giorni non entrano.
@visibleForTesting
List<WorkflowLogItem> workflowLogItemsFromRuns(
  String label,
  String body, {
  required DateTime now,
}) {
  final out = <WorkflowLogItem>[];
  try {
    final decoded = jsonDecode(body);
    final runs = decoded is Map ? decoded['workflow_runs'] : null;
    if (runs is! List) return out;
    final oldest = now.subtract(const Duration(days: 14));
    for (final run in runs.whereType<Map>()) {
      final sha = '${run['head_sha'] ?? ''}';
      final short = sha.length >= 7 ? sha.substring(0, 7) : sha;
      final head = run['head_commit'];
      final title = _firstLine(
        head is Map
            ? '${head['message'] ?? ''}'
            : '${run['display_title'] ?? ''}',
      );
      final branch = '${run['head_branch'] ?? 'main'}';
      final number = run['run_number'];
      final url = '${run['html_url'] ?? ''}';
      final created = DateTime.tryParse('${run['created_at']}')?.toLocal();
      final updated =
          DateTime.tryParse('${run['updated_at']}')?.toLocal() ?? created;
      if (sha.isNotEmpty && created != null && created.isAfter(oldest)) {
        out.add(WorkflowLogItem(
          key: 'push:$sha',
          level: AppLogLevel.ok,
          context: 'Commit e push',
          message: 'Push riuscito su $branch: $short $title',
          time: created,
        ));
      }
      if ('${run['status']}' != 'completed' ||
          updated == null ||
          updated.isBefore(oldest)) {
        continue;
      }
      final conclusion = '${run['conclusion']}';
      if (conclusion == 'cancelled' ||
          conclusion == 'skipped' ||
          conclusion == 'neutral' ||
          conclusion == 'stale') {
        continue;
      }
      final ok = conclusion == 'success';
      out.add(WorkflowLogItem(
        key: 'run:${run['id']}:$conclusion',
        level: ok ? AppLogLevel.ok : AppLogLevel.errore,
        context: 'Workflows',
        message: '$label #$number: $conclusion - $title\n'
            'Commit: $short\n'
            'Pagina della run: $url',
        time: updated,
      ));
    }
  } catch (_) {
    // risposta non leggibile: nessuna voce
  }
  return out;
}

bool _syncing = false;

/// Legge da GitHub le ultime run di build, CI e secret scan e scrive nel Log
/// quelle che non ci sono ancora. Si chiama all'avvio e quando si apre "Log e
/// problemi". Ritorna quante voci nuove ha scritto.
Future<int> syncWorkflowLog({http.Client? client, DateTime? now}) async {
  if (_syncing) return 0;
  _syncing = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    final seen = <String>{...?prefs.getStringList(_seenKey)};
    final items = <WorkflowLogItem>[];
    for (final (file, label) in workflowLogFiles) {
      final body = await fetchWorkflowRunsBody(file, client: client);
      if (body == null) continue;
      items.addAll(
        workflowLogItemsFromRuns(label, body, now: now ?? DateTime.now()),
      );
    }
    items.sort((a, b) => a.time.compareTo(b.time));
    var added = 0;
    for (final item in items) {
      if (!seen.add(item.key)) continue;
      AppLog.instance.addAt(
        item.level,
        item.context,
        item.message,
        item.time,
      );
      added++;
    }
    if (added > 0) {
      final keep = seen.length > _seenMax
          ? seen.skip(seen.length - _seenMax).toList()
          : seen.toList();
      await prefs.setStringList(_seenKey, keep);
    }
    return added;
  } catch (_) {
    return 0;
  } finally {
    _syncing = false;
  }
}
