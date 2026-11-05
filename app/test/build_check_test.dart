import 'dart:convert';

import 'package:dart_pdf_editor_app/build_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String runs(String status, String? conclusion) => jsonEncode({
      'workflow_runs': [
        {
          'status': status,
          'conclusion': conclusion,
          'run_number': 51,
          'html_url': 'https://github.com/tesonepdf/dart-pdf/actions/runs/1',
        }
      ]
    });

void main() {
  test('a passed run is passed', () {
    final c = BuildCheck.fromRunsJson(runs('completed', 'success'));
    expect(c.state, BuildCheckState.passed);
    expect(c.runNumber, 51);
    expect(c.url, isNotNull);
  });

  test('a failed run is failed', () {
    expect(BuildCheck.fromRunsJson(runs('completed', 'failure')).state,
        BuildCheckState.failed);
  });

  test('a run still going is running', () {
    expect(BuildCheck.fromRunsJson(runs('in_progress', null)).state,
        BuildCheckState.running);
    expect(BuildCheck.fromRunsJson(runs('queued', null)).state,
        BuildCheckState.running);
  });

  test('no run for the commit means not started', () {
    expect(BuildCheck.fromRunsJson(jsonEncode({'workflow_runs': []})).state,
        BuildCheckState.notStarted);
  });

  test('an unknown commit asks nobody', () async {
    final client = MockClient((_) async => throw StateError('no request'));
    final c = await BuildCheck.fetch(commit: 'unknown', client: client);
    expect(c.state, BuildCheckState.unavailable);
  });

  test('fetch asks GitHub for the build commit and reads the answer',
      () async {
    late Uri asked;
    final client = MockClient((request) async {
      asked = request.url;
      return http.Response(runs('completed', 'success'), 200);
    });
    final c = await BuildCheck.fetch(commit: 'abc123', client: client);
    expect(asked.queryParameters['head_sha'], 'abc123');
    expect(asked.path, endsWith('/actions/workflows/ci.yml/runs'));
    expect(c.state, BuildCheckState.passed);
  });

  test('a network error or a bad status is unavailable', () async {
    final bad = MockClient((_) async => http.Response('{}', 403));
    expect((await BuildCheck.fetch(commit: 'abc', client: bad)).state,
        BuildCheckState.unavailable);
    final down = MockClient((_) async => throw http.ClientException('down'));
    expect((await BuildCheck.fetch(commit: 'abc', client: down)).state,
        BuildCheckState.unavailable);
  });
}
