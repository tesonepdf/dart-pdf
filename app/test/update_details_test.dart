import 'dart:convert';

import 'package:dart_pdf_editor_app/patch_manifest.dart';
import 'package:dart_pdf_editor_app/update_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final storico = jsonEncode([
    {'build': 312, 'version': '6.330.0736#312', 'changes': ['uno', 'due']},
    {'build': 311, 'version': '6.330.0237#311', 'changes': ['tre']},
    {'build': 310, 'version': '6.329.2000#310', 'changes': ['quattro']},
  ]);

  test('si vedono solo le build dopo quella installata, dalla piu recente', () {
    final builds = parseBuildChanges(storico, installedBuild: 310);
    expect(builds.map((b) => b.build), [312, 311]);
    expect(builds.first.changes, ['uno', 'due']);
  });

  test('una build piu nuova di quella della release non si mostra', () {
    final builds =
        parseBuildChanges(storico, installedBuild: 310, latestBuild: 311);
    expect(builds.map((b) => b.build), [311]);
  });

  test('con la build installata sconosciuta restano tutte', () {
    expect(parseBuildChanges(storico, installedBuild: 0), hasLength(3));
  });

  test('un file illeggibile da lista vuota', () {
    expect(parseBuildChanges('{non json', installedBuild: 1), isEmpty);
    expect(parseBuildChanges('{"a": 1}', installedBuild: 1), isEmpty);
  });

  test('0.3 MB e mai 0.0', () {
    expect(formatMegabytes(300000), '0.3 MB');
    expect(formatMegabytes(10), '0.1 MB');
    expect(formatMegabytes(5 * 1048576), '5.0 MB');
  });

  test('i pezzi da scaricare: patch una dopo l altra', () {
    const piece = PatchPiece(build: 300, asset: 'a', sha256: 's', size: 40000000);
    const plan = PatchPlan(
      useBase: false,
      base: piece,
      target: piece,
      edges: [
        PatchEdge(
            from: 310,
            to: 311,
            asset: 'p1',
            size: 300000,
            fromSha: 'a',
            toSha: 'b'),
        PatchEdge(
            from: 311,
            to: 312,
            asset: 'p2',
            size: 200000,
            fromSha: 'b',
            toSha: 'c'),
      ],
      downloadBytes: 500000,
    );
    final steps = stepsFromPlan(plan);
    expect(steps.map((s) => s.label), ['Patch 310 → 311', 'Patch 311 → 312']);
    expect(steps.map((s) => s.bytes), [300000, 200000]);
  });

  test('partendo dalla base si scarica prima l APK completo', () {
    const base = PatchPiece(build: 300, asset: 'a', sha256: 's', size: 40000000);
    const plan = PatchPlan(
      useBase: true,
      base: base,
      target: base,
      edges: [],
      downloadBytes: 40000000,
    );
    expect(stepsFromPlan(plan).single.label, 'APK completo (build 300)');
  });
}
