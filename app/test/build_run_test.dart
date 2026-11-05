import 'dart:convert';

import 'package:dart_pdf_editor_app/build_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String runs(String status, String? conclusion, {String title = '#222 Prova'}) =>
    jsonEncode({
      'workflow_runs': [
        {
          'id': 99,
          'status': status,
          'conclusion': conclusion,
          'run_number': 7,
          'display_title': title,
          'run_started_at': '2026-11-05T08:00:00Z',
          'html_url': 'https://github.com/tesonepdf/dart-pdf/actions/runs/99',
        },
      ],
    });

final jobs = jsonEncode({
  'jobs': [
    {
      'name': 'version',
      'status': 'completed',
      'steps': [
        {'name': 'a', 'status': 'completed', 'number': 1},
      ],
    },
    {
      'name': 'apk',
      'status': 'in_progress',
      'steps': [
        {'name': 'Set up job', 'status': 'completed', 'number': 1},
        {'name': 'Checkout', 'status': 'completed', 'number': 2},
        {'name': 'Build APK', 'status': 'in_progress', 'number': 3},
        {'name': 'Upload', 'status': 'queued', 'number': 4},
      ],
    },
  ],
});

void main() {
  test('the build number comes from the commit title', () {
    final run = BuildRun.fromRunsJson(runs('completed', 'success'));
    expect(run.state, BuildRunState.succeeded);
    expect(run.number, 222);
    expect(run.url, isNotNull);
    expect(run.inProgress, isFalse);
  });

  test('without a number in the title the run number is used', () {
    final run = BuildRun.fromRunsJson(
      runs('completed', 'failure', title: 'Build manuale'),
    );
    expect(run.state, BuildRunState.failed);
    expect(run.number, 7);
  });

  test('queued and running builds are in progress', () {
    expect(
      BuildRun.fromRunsJson(runs('queued', null)).state,
      BuildRunState.queued,
    );
    final running = BuildRun.fromRunsJson(runs('in_progress', null));
    expect(running.state, BuildRunState.running);
    expect(running.inProgress, isTrue);
    expect(running.startedAt, isNotNull);
  });

  test('a cancelled run is cancelled, no runs is none', () {
    expect(
      BuildRun.fromRunsJson(runs('completed', 'cancelled')).state,
      BuildRunState.cancelled,
    );
    expect(
      BuildRun.fromRunsJson(jsonEncode({'workflow_runs': []})).state,
      BuildRunState.none,
    );
  });

  test('the running job and step are read from the jobs list', () {
    final run = BuildRun.fromRunsJson(runs('in_progress', null)).withJobs(jobs);
    expect(run.job, 'apk');
    expect(run.step, 'Build APK');
    expect(run.stepsDone, 2);
    expect(run.stepCount, 4);
    expect(run.number, 222);
  });

  test('fetch asks for the jobs only while the build runs', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/jobs')) return http.Response(jobs, 200);
      return http.Response(runs('in_progress', null), 200);
    });
    final run = await BuildRun.fetch(client: client);
    expect(run.step, 'Build APK');
    expect(paths.length, 2);

    paths.clear();
    final done = await BuildRun.fetch(
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(runs('completed', 'success'), 200);
      }),
    );
    expect(done.state, BuildRunState.succeeded);
    expect(paths.length, 1);
  });

  test('an API error or rate limit is unavailable', () async {
    final run = await BuildRun.fetch(
      client: MockClient((_) async => http.Response('{}', 403)),
    );
    expect(run.state, BuildRunState.unavailable);
  });
}
