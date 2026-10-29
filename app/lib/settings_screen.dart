import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_info.dart';
import 'cached_documents_settings.dart';
import 'l10n/app_l10n.dart';
import 'l10n/app_localizations.dart';
import 'language_names.dart';
import 'ocr.dart';
import 'ocr_auto.dart';
import 'official_update.dart';
import 'pdf_cache.dart';
import 'recents.dart';
import 'signature_trust.dart';
import 'update.dart';
import 'update_install_flow.dart';
import 'update_installer.dart';
import 'web_channel.dart';
import 'whats_new.dart';

// The platform-specific default-app help lives in the ARB as one ICU `select`
// key each (branches: web/windows/macos/linux/android/ios/other), resolved from
// this selector. Both consumers below have a BuildContext, so no literal needs
// to live at the no-context data site any more.
String get _defaultAppPlatform {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows => 'windows',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.linux => 'linux',
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

String _defaultAppSubtitle(BuildContext context) =>
    appL10n(context).settingsDefaultAppSubtitle(_defaultAppPlatform);

String _defaultAppInstructions(BuildContext context) =>
    appL10n(context).settingsDefaultAppInstructions(_defaultAppPlatform);

bool get _canOpenDefaultAppsSettings =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

Future<void> _openDefaultAppsSettings(BuildContext context) async {
  final uri = Uri.parse('ms-settings:defaultapps');
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(appL10n(context).settingsCouldNotOpenSystemSettings),
    ));
  }
}

Future<void> _showDefaultAppSetup(BuildContext context) {
  return showPdfDialog<void>(
    context: context,
    builder: (context) {
      void close() => Navigator.of(context).pop();
      void openSettings() {
        Navigator.of(context).pop();
        _openDefaultAppsSettings(context);
      }

      final closeButton = TextButton(
        onPressed: close,
        child: Text(appL10n(context).close),
      );
      return AlertDialog(
        title: Text(appL10n(context).settingsSetUpAsDefault),
        content: Text(_defaultAppInstructions(context)),
        actions: [
          if (_canOpenDefaultAppsSettings) closeButton,
          PdfDialogSubmit.action(
            onSubmit: _canOpenDefaultAppsSettings ? openSettings : close,
            child: _canOpenDefaultAppsSettings
                ? FilledButton.icon(
                    key: const ValueKey('default-app-open-settings'),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(appL10n(context).settingsOpenSettings),
                    onPressed: openSettings,
                  )
                : closeButton,
          ),
        ],
      );
    },
  );
}

/// Opens the app settings sheet: theme mode, recent-files management, the
/// update check, and the About section. Style defaults (tool colours, stroke,
/// font) are edited live from the editor toolbar and persist through
/// [PdfEditingPreferences], so they aren't duplicated here.
Future<void> showAppSettings(
  BuildContext context, {
  required PdfEditingPreferences prefs,
  required RecentsStore recents,
  UpdateService? updates,
  UpdateInstaller? updateInstaller,
  VoidCallback? onOpenDevTools,
  AutoOcrSetting? autoOcr,
}) {
  return showPdfDialog<void>(
    context: context,
    builder: (context) => _SettingsDialog(
      prefs: prefs,
      recents: recents,
      updates: updates,
      updateInstaller: updateInstaller,
      onOpenDevTools: onOpenDevTools,
      autoOcr: autoOcr ?? AutoOcrSetting.instance,
    ),
  );
}

/// The Settings UI-language dropdown: "System default" plus every locale the
/// app ships translations for, each shown by its native name. Writes the
/// choice to [PdfEditingPreferences.locale] (null = follow the platform),
/// which `app.dart` feeds to `MaterialApp.locale`.
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.prefs});

  final PdfEditingPreferences prefs;

  @override
  Widget build(BuildContext context) {
    // Sort supported locales by native name so the list reads naturally; the
    // "System default" entry (value null) always leads.
    final locales = AppLocalizations.supportedLocales.toList()
      ..sort((a, b) => languageDisplayName(a)
          .toLowerCase()
          .compareTo(languageDisplayName(b).toLowerCase()));
    // Match the stored preference to a supported locale by value; an
    // unsupported stored tag falls back to showing "System default" without
    // discarding the preference.
    Locale? selected;
    for (final locale in locales) {
      if (locale == prefs.locale) {
        selected = locale;
        break;
      }
    }
    return DropdownButtonFormField<Locale?>(
      key: const ValueKey('settings-language'),
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        prefixIcon: Icon(Icons.language),
      ),
      items: [
        DropdownMenuItem<Locale?>(
          value: null,
          child: Text(appL10n(context).settingsLanguageSystem),
        ),
        for (final locale in locales)
          DropdownMenuItem<Locale?>(
            value: locale,
            child: Text(languageDisplayName(locale)),
          ),
      ],
      onChanged: (value) => prefs.locale = value,
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({
    required this.prefs,
    required this.recents,
    this.updates,
    this.updateInstaller,
    this.onOpenDevTools,
    required this.autoOcr,
  });

  final PdfEditingPreferences prefs;
  final RecentsStore recents;
  final UpdateService? updates;
  final UpdateInstaller? updateInstaller;
  final AutoOcrSetting autoOcr;

  /// Non-null in debug/profile builds: closes the dialog and opens the
  /// developer tools panel (same as F12).
  final VoidCallback? onOpenDevTools;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(appL10n(context).settingsTitle),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: Listenable.merge([widget.prefs, widget.recents]),
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appL10n(context).settingsAppearance,
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<PdfThemePreference>(
                  segments: [
                    ButtonSegment(
                        value: PdfThemePreference.system,
                        icon: const Icon(Icons.brightness_auto),
                        label: Text(appL10n(context).settingsThemeSystem)),
                    ButtonSegment(
                        value: PdfThemePreference.light,
                        icon: const Icon(Icons.light_mode),
                        label: Text(appL10n(context).settingsThemeLight)),
                    ButtonSegment(
                        value: PdfThemePreference.dark,
                        icon: const Icon(Icons.dark_mode),
                        label: Text(appL10n(context).settingsThemeDark)),
                  ],
                  selected: {widget.prefs.themePreference},
                  onSelectionChanged: (s) =>
                      widget.prefs.themePreference = s.first,
                ),
                const SizedBox(height: 16),
                Text(appL10n(context).settingsLanguage,
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                _LanguagePicker(prefs: widget.prefs),
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Text(appL10n(context).settingsRecentFiles,
                          style: theme.textTheme.titleSmall),
                    ),
                    TextButton(
                      onPressed: widget.recents.isEmpty
                          ? null
                          : () => widget.recents.clear(),
                      child: Text(appL10n(context).clear),
                    ),
                  ],
                ),
                Text(
                  appL10n(context)
                      .settingsRecentCount(widget.recents.items.length),
                  style: theme.textTheme.bodySmall,
                ),
                if (canManageCachedPdfs) ...[
                  const Divider(height: 32),
                  CachedDocumentsSettings(recents: widget.recents),
                ],
                if (SignatureTrust.platformDefault case final trust?
                    when trust.aatl != null) ...[
                  const Divider(height: 32),
                  _SignatureTrustSection(trust: trust, setting: trust.aatl!),
                ],
                if (OnDeviceOcr.isSupported) ...[
                  const Divider(height: 32),
                  _TextRecognitionSection(setting: widget.autoOcr),
                ],
                const Divider(height: 32),
                _ArrowStepsSection(prefs: widget.prefs),
                const Divider(height: 32),
                Text(appL10n(context).settingsSystem,
                    style: theme.textTheme.titleSmall),
                ListTile(
                  key: const ValueKey('settings-default-app'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.assignment_turned_in_outlined),
                  title: Text(appL10n(context).settingsSetUpAsDefault),
                  subtitle: Text(_defaultAppSubtitle(context)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDefaultAppSetup(context),
                ),
                if (kIsWeb) const WebChannelSwitchTile(),
                if (widget.onOpenDevTools != null)
                  ListTile(
                    key: const ValueKey('settings-devtools'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.build_outlined),
                    title: Text(appL10n(context).settingsDeveloperTools),
                    subtitle:
                        Text(appL10n(context).settingsDeveloperToolsSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onOpenDevTools!();
                    },
                  ),
                if (widget.updates != null && widget.updates!.supported) ...[
                  const Divider(height: 32),
                  _UpdateSection(
                    updates: widget.updates!,
                    installer: widget.updateInstaller,
                  ),
                ],
                const Divider(height: 32),
                Text(appL10n(context).settingsAbout,
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  AppInfo.buildNumber.isEmpty
                      ? '${AppInfo.displayName} ${AppInfo.displayVersion}'
                      : '${AppInfo.displayName} ${AppInfo.displayVersion} #${AppInfo.buildNumber}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(AppInfo.tagline, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  icon: const Icon(Icons.code, size: 18),
                  label: Text(appL10n(context).settingsViewSource),
                  onPressed: () => launchUrl(Uri.parse(AppInfo.sourceUrl),
                      mode: LaunchMode.externalApplication),
                ),
                ListTile(
                  key: const ValueKey('settings-report-issue'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text(appL10n(context).settingsReportIssue),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(Uri.parse(AppInfo.feedbackIssueUrl),
                      mode: LaunchMode.externalApplication),
                ),
                ListTile(
                  key: const ValueKey('settings-whats-new'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.new_releases_outlined),
                  title: Text(appL10n(context).whatsNew),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showWhatsNew(context),
                ),
                ListTile(
                  key: const ValueKey('settings-licenses'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.article_outlined),
                  title: Text(MaterialLocalizations.of(context)
                      .viewLicensesButtonLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: AppInfo.displayName,
                    applicationVersion: AppInfo.displayVersion,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        PdfDialogSubmit.action(
            onSubmit: () => Navigator.of(context).pop(),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(appL10n(context).close),
            )),
      ],
    );
  }
}

/// Settings block for the free-text cursor arrows: how many document pixels
/// one tap moves the text box, separately for the horizontal and the vertical
/// axis.
class _ArrowStepsSection extends StatelessWidget {
  const _ArrowStepsSection({required this.prefs});

  final PdfEditingPreferences prefs;

  Widget _slider({
    required Key key,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 108, child: Text(label)),
        Expanded(
          child: Slider(
            key: key,
            min: 1,
            max: 40,
            divisions: 39,
            value: value.clamp(1, 40).toDouble(),
            label: '${value.round()} px',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text('${value.round()} px', textAlign: TextAlign.end),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Frecce di posizionamento testo',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Pixel di spostamento della casella a ogni tocco di freccia, '
          'in unita del documento.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        _slider(
          key: const ValueKey('settings-arrow-step-x'),
          label: 'Orizzontale',
          value: prefs.lineArrowStepX,
          onChanged: (v) => prefs.lineArrowStepX = v.roundToDouble(),
        ),
        _slider(
          key: const ValueKey('settings-arrow-step-y'),
          label: 'Verticale',
          value: prefs.lineArrowStepY,
          onChanged: (v) => prefs.lineArrowStepY = v.roundToDouble(),
        ),
      ],
    );
  }
}

/// The updates block: a drop-down picks which project is checked - this app's
/// own releases or the upstream (official) project's - each with its own
/// status.
class _UpdateSection extends StatefulWidget {
  const _UpdateSection({required this.updates, this.installer});

  final UpdateService updates;
  final UpdateInstaller? installer;

  @override
  State<_UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<_UpdateSection> {
  bool _official = false;

  static String _t(BuildContext context, String it, String en) =>
      Localizations.localeOf(context).languageCode == 'it' ? it : en;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(appL10n(context).settingsUpdates,
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        DropdownButton<bool>(
          key: const ValueKey('settings-update-source'),
          isExpanded: true,
          value: _official,
          items: [
            DropdownMenuItem(
              value: false,
              child: Text(_t(context, 'Il mio repo (tesonepdf)',
                  'My repository (tesonepdf)')),
            ),
            DropdownMenuItem(
              value: true,
              child: Text(_t(context, 'Repo ufficiale (ben-milanko)',
                  'Official repository (ben-milanko)')),
            ),
          ],
          onChanged: (value) => setState(() => _official = value ?? false),
        ),
        const SizedBox(height: 6),
        if (_official)
          const _OfficialUpdatePanel()
        else
          _OwnUpdatePanel(
              updates: widget.updates, installer: widget.installer),
      ],
    );
  }
}

/// The upstream project's releases: compared with the version this copy is
/// based on, opened in the browser (the builds are signed with another key,
/// so they cannot be installed over this app).
class _OfficialUpdatePanel extends StatelessWidget {
  const _OfficialUpdatePanel();

  static String _t(BuildContext context, String it, String en) =>
      Localizations.localeOf(context).languageCode == 'it' ? it : en;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checker = OfficialUpdateChecker.instance;
    return ListenableBuilder(
      listenable: checker,
      builder: (context, _) {
        final checking = checker.status == OfficialUpdateStatus.checking;
        final status = switch (checker.status) {
          OfficialUpdateStatus.newer => _t(
              context,
              'Nuova versione ufficiale: ${checker.latestLabel}',
              'New official version: ${checker.latestLabel}'),
          OfficialUpdateStatus.upToDate => _t(
              context,
              'Nessuna novita\' ufficiale oltre la ${checker.mergedLabel}.',
              'Nothing newer upstream than ${checker.mergedLabel}.'),
          OfficialUpdateStatus.error => _t(context,
              'Controllo non riuscito: ${checker.error}',
              'Check failed: ${checker.error}'),
          _ => '',
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                context,
                'Versione ufficiale da cui e\' partita questa copia: '
                    '${checker.mergedLabel}. Le novita\' ufficiali si '
                    'vedono qui, ma non si installano sopra questa app.',
                'Official version this copy started from: '
                    '${checker.mergedLabel}. Upstream news shows here but '
                    'is not installed over this app.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey('settings-check-official-updates'),
              onPressed: checking ? null : checker.check,
              child: checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_t(context, 'Controlla versione ufficiale',
                      'Check official version')),
            ),
            if (status.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(status, style: theme.textTheme.bodySmall),
            ],
            if (checker.status == OfficialUpdateStatus.newer) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    key: const ValueKey('settings-open-official-release'),
                    onPressed: checker.latestUrl == null
                        ? null
                        : () => launchUrl(Uri.parse(checker.latestUrl!),
                            mode: LaunchMode.externalApplication),
                    child: Text(_t(context, 'Apri la release',
                        'Open the release')),
                  ),
                  OutlinedButton(
                    key: const ValueKey('settings-official-merged'),
                    onPressed: checker.markLatestMerged,
                    child: Text(_t(context, 'Segna come integrata',
                        'Mark as merged')),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}


/// The Settings "Updates" block: a "Check for updates" button and a status
/// line that reflects the [UpdateService]'s latest result, with a Download
/// button (opening the platform artifact or release page) when a newer build
/// is available.
class _OwnUpdatePanel extends StatelessWidget {
  const _OwnUpdatePanel({required this.updates, this.installer});

  final UpdateService updates;

  /// The in-app updater; null defaults to a real one (tests inject a fake).
  final UpdateInstaller? installer;

  Future<void> _install(BuildContext context) => startUpdateInstall(
        context,
        updates: updates,
        installer: installer ?? UpdateInstaller(),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        final checking = updates.status == UpdateStatus.checking;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                context,
                'Scegli quando l\'app controlla se c\'e\' una versione nuova. '
                    'Se c\'e\', compare un avviso con la scelta di scaricarla.',
                'Choose when the app checks for a new version. If there is '
                    'one, a notice lets you download it.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _modeOption(
              context,
              UpdateCheckMode.everyOpen,
              _t(context, 'A ogni apertura', 'Every time the app opens'),
              _t(
                context,
                'Controlla ogni volta che apri l\'app o la riporti in primo '
                    'piano. Consigliata.',
                'Checks every time you open the app or bring it to the '
                    'foreground. Recommended.',
              ),
              checking,
            ),
            _modeOption(
              context,
              UpdateCheckMode.startOnly,
              _t(context, 'Solo all\'avvio da zero', 'Only on a cold start'),
              _t(
                context,
                'Controlla solo quando l\'app parte da chiusa del tutto.',
                'Checks only when the app starts from fully closed.',
              ),
              checking,
            ),
            _modeOption(
              context,
              UpdateCheckMode.manual,
              _t(context, 'Solo manuale', 'Manual only'),
              _t(
                context,
                'Nessun controllo automatico: usa il pulsante qui sotto.',
                'No automatic check: use the button below.',
              ),
              checking,
            ),
            const SizedBox(height: 4),
            OutlinedButton(
              key: const ValueKey('settings-check-updates'),
              onPressed:
                  checking ? null : () => updates.checkForUpdates(force: true),
              child: checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_t(context, 'Controlla aggiornamenti ora',
                      'Check for updates now')),
            ),
            if (updates.nightlySupported)
              SwitchListTile(
                key: const ValueKey('settings-nightly-updates'),
                contentPadding: EdgeInsets.zero,
                title: Text(appL10n(context).settingsNightlyUpdates),
                subtitle: Text(appL10n(context).settingsNightlyUpdatesSubtitle),
                value: updates.nightlyUpdates,
                onChanged: checking
                    ? null
                    : (value) async {
                        await updates.setNightlyUpdates(value);
                        await updates.checkForUpdates(force: true);
                      },
              ),
            _statusLine(context, theme),
            if (updates.updateAvailable) ...[
              if (updates.isVersionSkipped) ...[
                const SizedBox(height: 8),
                Text(
                  appL10n(context).settingsUpdateSkipped,
                  key: const ValueKey('settings-update-skipped'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  key: const ValueKey('settings-download-update'),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(appL10n(context)
                      .settingsDownloadVersion(updates.latest!.displayVersion)),
                  onPressed: () => _install(context),
                ),
              ),
              if (!updates.isVersionSkipped)
                TextButton(
                  key: const ValueKey('settings-skip-update'),
                  onPressed: () => updates.skipVersion(),
                  child: Text(appL10n(context).updateSkipVersion),
                ),
            ],
          ],
        );
      },
    );
  }

  /// Italian or English text (the update options are not in the ARB files).
  static String _t(BuildContext context, String it, String en) =>
      Localizations.localeOf(context).languageCode == 'it' ? it : en;

  Widget _modeOption(BuildContext context, UpdateCheckMode mode, String title,
      String subtitle, bool busy) {
    final theme = Theme.of(context);
    final selected = updates.checkMode == mode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('settings-update-mode-${mode.name}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => updates.setCheckMode(mode),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selected ? '\u25CF' : '\u25CB'} $title',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusLine(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall;
    return switch (updates.status) {
      UpdateStatus.checking =>
        Text(appL10n(context).settingsCheckingForUpdates, style: style),
      UpdateStatus.updateAvailable => Text(
          appL10n(context).settingsUpdateAvailable(
              updates.latest!.displayVersion, AppInfo.displayVersion),
          key: const ValueKey('settings-update-available'),
          style: style?.copyWith(color: scheme.primary),
        ),
      UpdateStatus.upToDate => Text(
          appL10n(context).settingsUpToDate(AppInfo.displayVersion),
          key: const ValueKey('settings-up-to-date'),
          style: style,
        ),
      UpdateStatus.failed => Text(
          appL10n(context).settingsUpdateFailed,
          key: const ValueKey('settings-update-failed'),
          style: style?.copyWith(color: scheme.error),
        ),
      UpdateStatus.idle => Text(
          appL10n(context)
              .settingsUpdateIdle(AppInfo.displayName, AppInfo.displayVersion),
          style: style,
        ),
    };
  }
}

/// The Settings "Text recognition" block: the "Automatically OCR scans"
/// switch (on by default), shown wherever on-device OCR runs.
class _TextRecognitionSection extends StatefulWidget {
  const _TextRecognitionSection({required this.setting});

  final AutoOcrSetting setting;

  @override
  State<_TextRecognitionSection> createState() =>
      _TextRecognitionSectionState();
}

class _TextRecognitionSectionState extends State<_TextRecognitionSection> {
  @override
  void initState() {
    super.initState();
    // The switch must show the stored choice, not the default, even when
    // Settings opens before the editor has read it.
    widget.setting.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsTextRecognition,
            style: Theme.of(context).textTheme.titleSmall),
        ValueListenableBuilder<bool>(
          valueListenable: widget.setting,
          builder: (context, enabled, _) => SwitchListTile(
            key: const ValueKey('settings-auto-ocr'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.document_scanner_outlined),
            title: Text(l10n.settingsAutoOcrTitle),
            subtitle: Text(l10n.settingsAutoOcrSubtitle),
            value: enabled,
            onChanged: (value) => widget.setting.save(value),
          ),
        ),
      ],
    );
  }
}

/// The Settings "Signatures" block: the opt-in Adobe Approved Trust List
/// switch (off-web only - the web can't reach Adobe).
class _SignatureTrustSection extends StatelessWidget {
  const _SignatureTrustSection({required this.trust, required this.setting});

  final SignatureTrust trust;
  final AatlTrustSetting setting;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsSignatures,
            style: Theme.of(context).textTheme.titleSmall),
        ValueListenableBuilder<bool>(
          valueListenable: setting,
          builder: (context, enabled, _) => SwitchListTile(
            key: const ValueKey('settings-aatl'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.verified_user_outlined),
            title: Text(l10n.settingsAatlTitle),
            subtitle: Text(l10n.settingsAatlSubtitle),
            value: enabled,
            onChanged: (value) => trust.setAatlEnabled(value),
          ),
        ),
      ],
    );
  }
}
