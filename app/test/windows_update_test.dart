import 'package:dart_pdf_editor_app/update.dart';
import 'package:dart_pdf_editor_app/windows_files.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sha = 'abcdef1234567890abcdef1234567890abcdef12';

ReleaseInfo _windowsRelease({String build = '490', String version = '6.325.0905'}) =>
    ReleaseInfo.fromJson({
      'tag_name': dartPdfWindowsTag,
      'name': 'DartPDF Windows $version#$build',
      'body': '''
Build #$build
<!-- main-sha: $_sha -->
<!-- app-version: $version -->
<!-- app-build: $build -->
''',
      'html_url': 'https://example.test/windows',
      'prerelease': false,
      'assets': [
        {
          'name': kWindowsFilesManifestName,
          'browser_download_url': 'https://example.test/windows-files.json',
          'size': 1000,
        },
        {
          'name': kWindowsZipName,
          'browser_download_url': 'https://example.test/windows-x64.zip',
          'size': 2000,
        },
      ],
    })!;

UpdateService _service({required String currentBuild, required ReleaseInfo release}) =>
    UpdateService(
      currentVersion: '6.325.0800',
      currentBuildNumber: currentBuild,
      platform: TargetPlatform.windows,
      architecture: 'x64',
      fetcher: () async => [release],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the rolling Windows release is parsed with its markers', () {
    final release = _windowsRelease();
    expect(release.isWindowsUpdate, isTrue);
    expect(release.isAndroidUpdate, isFalse);
    expect(release.buildNumber, '490');
    expect(release.versionText, '6.325.0905');
    expect(release.displayVersion, '6.325.0905#490');
    expect(release.identity, '$dartPdfWindowsTag@$_sha');
  });

  test('Windows offers the rolling release and updates file by file', () async {
    final updates =
        _service(currentBuild: '485', release: _windowsRelease(build: '490'));
    addTearDown(updates.dispose);

    await updates.checkForUpdates(force: true);

    expect(updates.status, UpdateStatus.updateAvailable);
    expect(updates.downloadAssetName, kWindowsFilesManifestName);
    expect(updates.downloadUrl, 'https://example.test/windows-files.json');
    expect(updates.windowsZipUrl, 'https://example.test/windows-x64.zip');
  });

  test('the same build is up to date', () async {
    final updates =
        _service(currentBuild: '490', release: _windowsRelease(build: '490'));
    addTearDown(updates.dispose);

    await updates.checkForUpdates(force: true);

    expect(updates.status, UpdateStatus.upToDate);
    expect(updates.downloadUrl, isNull);
  });
}
