import 'dart:convert';

import 'package:dart_pdf_editor_app/app_log.dart';
import 'package:dart_pdf_editor_app/workflow_log.dart';
import 'package:flutter_test/flutter_test.dart';

String runs(String conclusion, {String status = 'completed'}) => jsonEncode({
      'workflow_runs': [
        {
          'id': 77,
          'run_number': 189,
          'status': status,
          'conclusion': conclusion,
          'head_sha': 'a722015abcdef',
          'head_branch': 'main',
          'head_commit': {'message': '#363 Log e problemi\n\ndettagli'},
          'html_url': 'https://github.com/tesonepdf/dart-pdf/actions/runs/77',
          'created_at': '2026-11-12T10:00:00Z',
          'updated_at': '2026-11-12T10:05:00Z',
        }
      ]
    });

void main() {
  final now = DateTime.utc(2026, 11, 12, 12);

  test('una CI riuscita da una voce di push e una voce nel Log', () {
    final items = workflowLogItemsFromRuns('CI', runs('success'), now: now);
    expect(items.length, 2);
    expect(items[0].context, 'Commit e push');
    expect(items[0].message, startsWith('Push riuscito su main: a722015'));
    expect(items[1].level, AppLogLevel.ok);
    expect(items[1].context, 'Workflows');
    expect(items[1].message, startsWith('CI #189: success'));
  });

  test('una build fallita finisce negli errori', () {
    final items = workflowLogItemsFromRuns('Build', runs('failure'), now: now);
    expect(items.last.level, AppLogLevel.errore);
    expect(items.last.context, 'Workflows');
  });

  test('una run in corso da solo il push', () {
    final items = workflowLogItemsFromRuns(
      'Build',
      runs('', status: 'in_progress'),
      now: now,
    );
    expect(items.length, 1);
    expect(items.single.context, 'Commit e push');
  });

  test('una run annullata non da voci di esito', () {
    final items =
        workflowLogItemsFromRuns('CI', runs('cancelled'), now: now);
    expect(items.where((i) => i.context == 'Workflows'), isEmpty);
  });

  test('i tipi nuovi e le frasi in italiano', () {
    expect(appLogTypeOf('Workflows'), AppLogType.workflows);
    expect(appLogTypeOf('Commit e push'), AppLogType.workflows);
    expect(appLogTypeOf('Apertura documento'), AppLogType.documenti);
    expect(appLogTypeOf('Chiusura documento'), AppLogType.documenti);
    final entry = AppLogEntry(
      time: now,
      level: AppLogLevel.ok,
      context: 'Workflows',
      message: 'Build #339: success - titolo',
    );
    expect(describeLogEntry(entry), contains('build #339'));
    final open = AppLogEntry(
      time: now,
      level: AppLogLevel.info,
      context: 'Apertura documento',
      message: 'Aperto "a.pdf"',
    );
    expect(describeLogEntry(open), 'Il documento "a.pdf" è stato aperto.');
  });
}
