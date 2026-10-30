import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'update.dart' show AppVersion;

/// The upstream project this app was copied from.
const upstreamRepoOwner = 'ben-milanko';
const upstreamRepoName = 'dart-pdf';

/// The upstream version the copy started from (`app/pubspec.yaml` of commit
/// 3e0bd1b0c0e5b4ab336a8d584510a3a0e43e607a, 2026-10-26): 11.0.0+48.
const upstreamBaseVersion = '11.0.0';
const upstreamBaseBuild = 48;
const upstreamBaseCommit = '3e0bd1b0c0e5b4ab336a8d584510a3a0e43e607a';

enum OfficialUpdateStatus { idle, checking, newer, upToDate, error }

/// Read-only check of the upstream project's releases, kept apart from the
/// app's own update service: the upstream builds are signed with another key
/// and carry their own build numbers, so they are compared with the version
/// this copy is based on (and with the last upstream version the user marked as
/// merged), never with this app's own build number.
class OfficialUpdateChecker extends ChangeNotifier {
  OfficialUpdateChecker({http.Client Function()? clientFactory})
      : _clientFactory = clientFactory ?? http.Client.new {
    ready = _restore();
  }

  static final OfficialUpdateChecker instance = OfficialUpdateChecker();

  static const _versionKey = 'dart_pdf_editor_app.official.mergedVersion';
  static const _buildKey = 'dart_pdf_editor_app.official.mergedBuild';
  static const _dismissedKey = 'dart_pdf_editor_app.official.dismissedLabel';
  static const _skippedKey = 'dart_pdf_editor_app.official.skippedLabel';

  final http.Client Function() _clientFactory;

  /// Completes when the persisted state has been restored.
  late final Future<void> ready;

  String? dismissedLabel;
  String? skippedLabel;

  /// True when the user already chose "Later" for the latest official release.
  bool get isDismissed =>
      latestVersion != null && latestLabel == dismissedLabel;

  String mergedVersion = upstreamBaseVersion;
  int mergedBuild = upstreamBaseBuild;

  OfficialUpdateStatus status = OfficialUpdateStatus.idle;
  String? latestVersion;
  int? latestBuild;
  String? latestUrl;
  DateTime? latestPublished;
  String? error;

  String get mergedLabel => '$mergedVersion+$mergedBuild';
  String get latestLabel =>
      latestVersion == null ? '' : '$latestVersion+${latestBuild ?? '?'}';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mergedVersion = prefs.getString(_versionKey) ?? upstreamBaseVersion;
      mergedBuild = prefs.getInt(_buildKey) ?? upstreamBaseBuild;
      dismissedLabel = prefs.getString(_dismissedKey);
      skippedLabel = prefs.getString(_skippedKey);
      notifyListeners();
    } catch (_) {
      // No storage: keep the compiled-in base.
    }
  }

  /// "Later": stop asking for this official release; it stays highlighted in
  /// Settings until it is marked as merged or a newer one appears.
  Future<void> dismissLatest() async {
    final label = latestLabel;
    if (label.isEmpty) return;
    dismissedLabel = label;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedKey, label);
    } catch (_) {}
  }

  /// "Skip this version": stop asking and stop highlighting this official
  /// release; a newer one appears again.
  Future<void> skipLatest() async {
    final label = latestLabel;
    if (label.isEmpty) return;
    skippedLabel = label;
    status = OfficialUpdateStatus.upToDate;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skippedKey, label);
    } catch (_) {}
  }

  /// Marks the latest upstream release as merged into this copy.
  Future<void> markLatestMerged() async {
    final version = latestVersion;
    if (version == null) return;
    mergedVersion = version;
    mergedBuild = latestBuild ?? mergedBuild;
    status = OfficialUpdateStatus.upToDate;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_versionKey, mergedVersion);
      await prefs.setInt(_buildKey, mergedBuild);
    } catch (_) {}
  }

  Future<void> check() async {
    if (status == OfficialUpdateStatus.checking) return;
    status = OfficialUpdateStatus.checking;
    error = null;
    notifyListeners();
    final client = _clientFactory();
    try {
      final response = await client
          .get(
            Uri.https(
              'api.github.com',
              '/repos/$upstreamRepoOwner/$upstreamRepoName/releases',
              {'per_page': '30'},
            ),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('GitHub ${response.statusCode}');
      }
      final list = (jsonDecode(response.body) as List).cast<Map>();
      AppVersion? bestVersion;
      Map? best;
      int? bestBuild;
      for (final raw in list) {
        final tag = (raw['tag_name'] as String?) ?? '';
        if (!tag.startsWith('app-v')) continue;
        if (raw['draft'] == true || raw['prerelease'] == true) continue;
        final version = AppVersion.tryParse(tag);
        if (version == null) continue;
        final name = (raw['name'] as String?) ?? '';
        final build = int.tryParse(
            RegExp(r'\+(\d+)').firstMatch('$name $tag')?.group(1) ?? '');
        final newer = bestVersion == null ||
            version.compareTo(bestVersion) > 0 ||
            (version.compareTo(bestVersion) == 0 &&
                (build ?? 0) > (bestBuild ?? 0));
        if (newer) {
          bestVersion = version;
          best = raw;
          bestBuild = build;
        }
      }
      if (best == null || bestVersion == null) {
        latestVersion = null;
        status = OfficialUpdateStatus.upToDate;
      } else {
        latestVersion = '${bestVersion.major}.${bestVersion.minor}.'
            '${bestVersion.patch}';
        latestBuild = bestBuild;
        latestUrl = best['html_url'] as String?;
        latestPublished = DateTime.tryParse(
            (best['published_at'] as String?) ?? '');
        final merged = AppVersion.tryParse(mergedVersion);
        final order = merged == null ? 1 : bestVersion.compareTo(merged);
        final isNewer = order > 0 ||
            (order == 0 && (bestBuild ?? 0) > mergedBuild);
        status = isNewer && latestLabel != skippedLabel
            ? OfficialUpdateStatus.newer
            : OfficialUpdateStatus.upToDate;
      }
    } catch (e) {
      error = '$e';
      status = OfficialUpdateStatus.error;
    } finally {
      client.close();
      notifyListeners();
    }
  }
}
