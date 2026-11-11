import 'package:dart_pdf_editor/dart_pdf_editor.dart' show showPdfDialog;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n/app_l10n.dart';
import 'l10n/app_localizations.dart';
import 'patch_update_stub.dart' if (dart.library.io) 'patch_update_io.dart';
import 'update.dart';
import 'update_installer.dart';
import 'update_platform.dart';

/// Runs the interactive "update now" flow for the update [updates] found: on
/// desktop, downloads the artifact in a progress dialog and applies it in place
/// (AppImage self-replace + relaunch) or hands it to the OS installer
/// (macOS/Windows). Where no in-app apply path exists, or on failure, it falls
/// back to opening the browser download.
///
/// Reused by both the Settings "Update now" button and the startup banner.
Future<void> startUpdateInstall(
  BuildContext context, {
  required UpdateService updates,
  required UpdateInstaller installer,
}) async {
  final url = updates.downloadUrl;
  if (url == null) return;
  final assetName = updates.downloadAssetName;

  // Capture the messenger and localizations before any await, so a snackbar
  // still resolves after the async download even if the context is unmounted.
  final messenger = ScaffoldMessenger.of(context);
  final l10n = appL10n(context);

  // No in-app apply path (mobile, a release page only, a Linux tarball): keep
  // the old behaviour and open the download in the browser.
  final mode = installer.modeFor(assetName);
  if (mode == UpdateApplyMode.unsupported) {
    await _openInBrowser(messenger, l10n, url);
    return;
  }

  final progress =
      ValueNotifier<_UpdateProgress>(const _UpdateProgress(fraction: null));
  var cancelled = false;

  final dialogFuture = showPdfDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _UpdateProgressDialog(
      progress: progress,
      onCancel: () => cancelled = true,
    ),
  );

  UpdateInstallOutcome? outcome;
  Object? failure;
  try {
    // Android: prima la strada leggera (solo le patch); se non c'e' o qualcosa
    // non torna, si scarica l'APK completo come sempre.
    final patched = await _tryPatched(
      updates: updates,
      installer: installer,
      progress: progress,
      isCancelled: () => cancelled,
    );
    if (patched == _PatchStep.handedOff) {
      outcome = UpdateInstallOutcome.handedOff;
    } else {
      outcome = await installer.downloadAndApply(
        url: url,
        assetName: assetName!,
        expectedSize: updates.downloadAssetSize,
        isCancelled: () => cancelled,
        onProgress: (received, total) {
          progress.value = _UpdateProgress(
              fraction: (total != null && total > 0) ? received / total : null);
        },
        // The AppImage path relaunches immediately after applying; show a
        // "restarting" state so the dialog isn't frozen at 100% before exit.
        onApplying: mode == UpdateApplyMode.inPlaceRelaunch
            ? () => progress.value = const _UpdateProgress(applying: true)
            : null,
      );
    }
  } on UpdateCancelledException {
    // User cancelled - close the dialog quietly, no toast.
  } catch (e) {
    failure = e;
  }

  // Dismiss the progress dialog. (An AppImage relaunch already exited the
  // process, so this only runs on hand-off, cancel, or failure.)
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  await dialogFuture;
  progress.dispose();

  if (failure != null) {
    final message =
        failure is UpdateInstallException ? failure.message : '$failure';
    messenger.showSnackBar(SnackBar(
      key: const ValueKey('update-install-failed'),
      content: Text(l10n.updateFailed(message)),
      action: SnackBarAction(
        label: l10n.editorDownload,
        onPressed: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ),
    ));
    return;
  }

  if (outcome == UpdateInstallOutcome.handedOff) {
    messenger.showSnackBar(SnackBar(
      key: const ValueKey('update-handed-off'),
      content: Text(l10n.updateHandedOff),
    ));
  }
}

enum _PatchStep {
  /// Non si usano le patch (altra piattaforma, nessun elenco): download normale.
  plainDownload,

  /// L'APK nuovo e' pronto e passato all'installazione di Android.
  handedOff,
}

/// Android: ricostruisce l'APK nuovo con le patch (solo la differenza) e lo
/// passa all'installazione. Se non riesce, il download completo e' permesso
/// solo quando l'APK della release e' la build corrente: nelle release con sole
/// patch quello e' la base, piu' vecchia, e Android lo rifiuterebbe come
/// downgrade, quindi in quel caso si lancia un errore.
Future<_PatchStep> _tryPatched({
  required UpdateService updates,
  required UpdateInstaller installer,
  required ValueNotifier<_UpdateProgress> progress,
  required bool Function() isCancelled,
  bool forceFull = false,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return _PatchStep.plainDownload;
  }
  if (installer.modeFor(updates.downloadAssetName) !=
      UpdateApplyMode.openArtifact) {
    return _PatchStep.plainDownload;
  }
  final assets = updates.latest?.assets;
  final installed = int.tryParse(updates.currentBuildNumber);
  if (assets == null || installed == null) return _PatchStep.plainDownload;
  final result = await buildPatchedApk(
    assets: assets,
    installedBuild: installed,
    forceFull: forceFull,
    isCancelled: isCancelled,
    onProgress: (f) => progress.value = _UpdateProgress(fraction: f),
  );
  final apk = result.apkPath;
  if (apk != null) {
    await installer.handOffFile(apk);
    return _PatchStep.handedOff;
  }
  if (result.plainApkIsCurrent) return _PatchStep.plainDownload;
  throw const UpdateInstallException(
      'The update could not be rebuilt from the patches, and the full APK in '
      'the release is not the latest build. Try again later, or use '
      '"Reinstall everything" in Settings.');
}

/// "Reinstalla tutto" (ripristino): riparte dall'APK base della release e
/// applica tutte le patch fino all'ultima build, senza guardare cosa c'e' sul
/// telefono. Serve dopo una cancellazione dei dati o se qualcosa non va.
Future<void> startReinstallAll(
  BuildContext context, {
  required UpdateService updates,
  required UpdateInstaller installer,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final italian = Localizations.localeOf(context).languageCode == 'it';
  String t(String it, String en) => italian ? it : en;

  await updates.checkForUpdates(force: true);
  if (!context.mounted) return;

  final progress =
      ValueNotifier<_UpdateProgress>(const _UpdateProgress(fraction: null));
  var cancelled = false;
  final dialogFuture = showPdfDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _UpdateProgressDialog(
      progress: progress,
      onCancel: () => cancelled = true,
    ),
  );

  var done = false;
  Object? failure;
  try {
    done = await _tryPatched(
          updates: updates,
          installer: installer,
          progress: progress,
          isCancelled: () => cancelled,
          forceFull: true,
        ) ==
        _PatchStep.handedOff;
  } on UpdateCancelledException {
    // annullato: niente avviso
  } catch (e) {
    failure = e;
  }

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  await dialogFuture;
  progress.dispose();

  if (done || cancelled) return;
  final reason = failure is UpdateInstallException
      ? failure.message
      : (failure?.toString() ??
          t('elenco delle patch non disponibile', 'patch list not available'));
  messenger.showSnackBar(SnackBar(
    key: const ValueKey('reinstall-all-failed'),
    content: Text(t('Reinstallazione non riuscita: $reason',
        'Reinstall failed: $reason')),
  ));
}

Future<void> _openInBrowser(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  String url,
) async {
  final opened =
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!opened) {
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.settingsCouldNotOpenDownload),
    ));
  }
}

/// The progress dialog's state: download [fraction] (null before it's known),
/// or [applying] once the download is done and the update is being applied
/// (the AppImage restart).
class _UpdateProgress {
  const _UpdateProgress({this.fraction, this.applying = false});
  final double? fraction;
  final bool applying;
}

/// Modal progress dialog for an in-app update download, with a cancel button.
class _UpdateProgressDialog extends StatelessWidget {
  const _UpdateProgressDialog({required this.progress, required this.onCancel});

  final ValueListenable<_UpdateProgress> progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('update-progress-dialog'),
      title: Text(appL10n(context).updateDownloadingTitle),
      content: ValueListenableBuilder<_UpdateProgress>(
        valueListenable: progress,
        builder: (context, value, _) {
          final l10n = appL10n(context);
          final label = value.applying
              ? l10n.updateRestarting
              : value.fraction == null
                  ? l10n.updatePreparing
                  : l10n.updateDownloadingPercent((value.fraction! * 100)
                      .round());
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label),
              const SizedBox(height: 16),
              // Indeterminate bar (null value) while applying/restarting.
              LinearProgressIndicator(
                  value: value.applying ? null : value.fraction),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          key: const ValueKey('update-progress-cancel'),
          onPressed: onCancel,
          child: Text(appL10n(context).cancel),
        ),
      ],
    );
  }
}
