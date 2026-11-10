import 'dart:async';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_info.dart';
import 'app_log_dialog.dart';
import 'build_check.dart';
import 'save_folder.dart';
import 'cached_documents_settings.dart';
import 'l10n/app_l10n.dart';
import 'l10n/app_localizations.dart';
import 'language_names.dart';
import 'measure_scale_setting.dart';
import 'ocr.dart';
import 'ocr_auto.dart';
import 'official_update.dart';
import 'open_with_rank.dart';
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

/// Opens the app settings sheet: theme mode, recent-files management and
/// editor preferences. App information is available from the Updates+ screen
/// ([showAppUpdates]). Style defaults (tool colours, stroke,
/// font) are edited live from the editor toolbar and persist through
/// [PdfEditingPreferences], so they aren't duplicated here.
Future<void> showAppSettings(
  BuildContext context, {
  required PdfEditingPreferences prefs,
  required RecentsStore recents,
  VoidCallback? onOpenDevTools,
  AutoOcrSetting? autoOcr,
}) {
  return showPdfDialog<void>(
    context: context,
    builder: (context) => _SettingsDialog(
      prefs: prefs,
      recents: recents,
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
    this.onOpenDevTools,
    required this.autoOcr,
  });

  final PdfEditingPreferences prefs;
  final RecentsStore recents;
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
    final Widget body = ListenableBuilder(
            listenable: Listenable.merge([widget.prefs, widget.recents]),
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsSection(
                  title: 'Aspetto e lingua',
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
                  ],
                ),
                _SettingsSection(
                  title: 'File recenti',
                  children: [
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
                  ],
                ),
                if (SaveFolder.supported)
                  const _SettingsSection(
                    title: 'Salvataggio',
                    children: [_SaveFolderTile()],
                  ),
                _SettingsSection(
                  title: 'Strumenti',
                  children: [
                    _MenuHoldSection(prefs: widget.prefs),
                    const Divider(height: 32),
                    _ArrowStepsSection(prefs: widget.prefs),
                    const Divider(height: 32),
                    MeasureScaleSettingsSection(prefs: widget.prefs),
                  ],
                ),
                if ((SignatureTrust.platformDefault?.aatl != null) ||
                    OnDeviceOcr.isSupported)
                  _SettingsSection(
                    title: 'Testo e firme',
                    children: [
                      if (SignatureTrust.platformDefault case final trust?
                          when trust.aatl != null)
                        _SignatureTrustSection(
                            trust: trust, setting: trust.aatl!),
                      if (SignatureTrust.platformDefault?.aatl != null &&
                          OnDeviceOcr.isSupported)
                        const Divider(height: 32),
                      if (OnDeviceOcr.isSupported)
                        _TextRecognitionSection(setting: widget.autoOcr),
                    ],
                  ),
                _SettingsSection(
                  title: 'Sistema',
                  children: [
                    ListTile(
                      key: const ValueKey('settings-default-app'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.assignment_turned_in_outlined),
                      title: Text(appL10n(context).settingsSetUpAsDefault),
                      subtitle: Text(_defaultAppSubtitle(context)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showDefaultAppSetup(context),
                    ),
                    if (OpenWithRank.supported)
                      ListTile(
                        key: const ValueKey('settings-open-with-rank'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.vertical_align_top),
                        title: const Text('Visualizzazione app in "Apri con"'),
                        subtitle: const Text(
                            'Apre l\'elenco di sistema: tocca DartPDF per '
                            'farlo comparire tra le prime app'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => OpenWithRank.show(),
                      ),
                    if (kIsWeb) const WebChannelSwitchTile(),
                    if (widget.onOpenDevTools != null)
                      ListTile(
                        key: const ValueKey('settings-devtools'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.build_outlined),
                        title: Text(appL10n(context).settingsDeveloperTools),
                        subtitle: Text(
                            appL10n(context).settingsDeveloperToolsSubtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onOpenDevTools!();
                        },
                      ),
                  ],
                ),
                _SettingsSection(
                  title: 'Log e problemi',
                  children: [
                    ListTile(
                      key: const ValueKey('settings-app-log'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.fact_check_outlined),
                      title: const Text('Apri il Log'),
                      subtitle: const Text(
                          'Cosa e\' andato bene e cosa no, con la spiegazione'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showAppLog(context),
                    ),
                  ],
                ),
              ],
            ),
          );
    // sul telefono le Impostazioni occupano tutto lo schermo
    if (MediaQuery.sizeOf(context).width < 600) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(appL10n(context).settingsTitle),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: appL10n(context).close,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: body,
            ),
          ),
        ),
      );
    }
    return AlertDialog(
      title: Text(appL10n(context).settingsTitle),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: body,
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

/// Settings block for the touch context menu: how long a finger must stay
/// still on an element before the menu opens.
class _MenuHoldSection extends StatelessWidget {
  const _MenuHoldSection({required this.prefs});

  final PdfEditingPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Menu del tocco prolungato',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Quanto tieni premuto fermo su un elemento prima che compaia il '
          'menu. Se muovi il dito prima, l\'elemento si sposta e il menu '
          'non compare.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ListenableBuilder(
          listenable: prefs,
          builder: (context, _) => Row(
            children: [
              Expanded(
                child: Slider(
                  key: const ValueKey('settings-menu-hold'),
                  min: 300,
                  max: 1000,
                  divisions: 14,
                  value: prefs.menuHoldMs.clamp(300, 1000).toDouble(),
                  label: '${prefs.menuHoldMs} ms',
                  onChanged: (v) => prefs.menuHoldMs = v.round(),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text('${prefs.menuHoldMs} ms', textAlign: TextAlign.end),
              ),
            ],
          ),
        ),
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
        const SizedBox(height: 12),
        Text('Allineamento con le altre caselle',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Con le frecce, quando la casella e\' a meno di un tocco da un '
          'allineamento compare la linea rossa e il tocco successivo '
          'allinea. Scegli i lati (di base sinistro e inferiore). '
          'Spostando a mano non c\'e\' nessun aggancio.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ListenableBuilder(
          listenable: prefs,
          builder: (context, _) => Column(
            children: [
              SwitchListTile(
                key: const ValueKey('settings-nudge-align-enabled'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Agganci'),
                value: prefs.nudgeAlignEnabled,
                onChanged: (v) => prefs.nudgeAlignEnabled = v,
              ),
              for (final (label, key, get, set) in <(
                String,
                String,
                bool Function(),
                void Function(bool)
              )>[
                (
                  'Bordo sinistro',
                  'left',
                  () => prefs.nudgeAlignLeft,
                  (v) => prefs.nudgeAlignLeft = v
                ),
                (
                  'Bordo destro',
                  'right',
                  () => prefs.nudgeAlignRight,
                  (v) => prefs.nudgeAlignRight = v
                ),
                (
                  'Bordo inferiore',
                  'bottom',
                  () => prefs.nudgeAlignBottom,
                  (v) => prefs.nudgeAlignBottom = v
                ),
                (
                  'Bordo superiore',
                  'top',
                  () => prefs.nudgeAlignTop,
                  (v) => prefs.nudgeAlignTop = v
                ),
              ])
                SwitchListTile(
                  key: ValueKey('settings-nudge-align-$key'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(label),
                  value: get(),
                  onChanged: prefs.nudgeAlignEnabled ? set : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String appUpdatesPlusTitle(BuildContext context) =>
    '${appL10n(context).settingsUpdates}+';

List<Widget> _appInformationChildren(BuildContext context) {
  final theme = Theme.of(context);
  return [
      Text(
        '${AppInfo.displayName} ${AppInfo.displayVersion}',
        style: theme.textTheme.bodyMedium,
      ),
      Text(AppInfo.tagline, style: theme.textTheme.bodySmall),
      if (AppInfo.buildCommit != 'unknown') const _BuildCheckTile(),
      const _BuildRunTile(),
      const _LatestWorkflowTile(
        tileKey: 'settings-latest-ci',
        label: 'Test dell\'ultima build',
        workflow: 'ci.yml',
      ),
      const _LatestWorkflowTile(
        tileKey: 'settings-latest-secret-scan',
        label: 'Scansione segreti dell\'ultimo commit',
        workflow: 'secret-scan.yml',
      ),
      const SizedBox(height: 4),
      TextButton.icon(
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        icon: const Icon(Icons.code, size: 18),
        label: Text(appL10n(context).settingsViewSource),
        onPressed: () => launchUrl(Uri.parse(AppInfo.sourceUrl),
            mode: LaunchMode.externalApplication),
      ),
      ListTile(
        key: const ValueKey('updates-info-report-issue'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.bug_report_outlined),
        title: Text(appL10n(context).settingsReportIssue),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => launchUrl(Uri.parse(AppInfo.feedbackIssueUrl),
            mode: LaunchMode.externalApplication),
      ),
      ListTile(
        key: const ValueKey('updates-info-whats-new'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.new_releases_outlined),
        title: Text(appL10n(context).whatsNew),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showWhatsNew(context),
      ),
      ListTile(
        key: const ValueKey('updates-info-licenses'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.article_outlined),
        title: Text(MaterialLocalizations.of(context).viewLicensesButtonLabel),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showLicensePage(
          context: context,
          applicationName: AppInfo.displayName,
          applicationVersion: AppInfo.displayVersion,
        ),
      ),
  ];
}

/// Opens the Updates screen (menu: next to Settings). Two drop-downs - this
/// app's own releases and the upstream (official) ones - each with its own
/// three check options and its own manual check button. Both can be open at
/// once, and holding a title for half a second moves it up or down (the order
/// is remembered).
Future<void> showAppUpdates(
  BuildContext context, {
  required UpdateService updates,
  UpdateInstaller? updateInstaller,
}) {
  return showPdfDialog<void>(
    context: context,
    builder: (context) =>
        _UpdatesDialog(updates: updates, installer: updateInstaller),
  );
}

class _UpdatesDialog extends StatefulWidget {
  const _UpdatesDialog({required this.updates, this.installer});

  final UpdateService updates;
  final UpdateInstaller? installer;

  @override
  State<_UpdatesDialog> createState() => _UpdatesDialogState();
}

class _UpdatesDialogState extends State<_UpdatesDialog> {
  static const _orderKey = 'dart_pdf_editor_app.updates_order';

  /// L'ordine scelto dall'utente per i blocchi (id), salvato.
  List<String> _order = const [];

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_orderKey);
      if (saved != null && mounted) setState(() => _order = saved);
    } catch (_) {
      // senza archivio resta l'ordine di fabbrica
    }
  }

  Future<void> _saveOrder(List<String> ids) async {
    setState(() => _order = ids);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_orderKey, ids);
    } catch (_) {}
  }

  static String _t(BuildContext context, String it, String en) =>
      Localizations.localeOf(context).languageCode == 'it' ? it : en;

  @override
  Widget build(BuildContext context) {
    final sections = <String, Widget>{
      'own': _SettingsSection(
        title: _t(context, 'Il mio repo (tesonepdf)',
            'My repository (tesonepdf)'),
        children: [
          _OwnUpdatePanel(
              updates: widget.updates, installer: widget.installer),
          const Divider(height: 24),
          ..._appInformationChildren(context),
        ],
      ),
      'official': _SettingsSection(
        title: _t(context, 'Repo ufficiale (ben-milanko)',
            'Official repository (ben-milanko)'),
        children: const [_OfficialUpdatePanel()],
      ),
    };
    final ids = _order.where(sections.containsKey).toList();
    for (final id in sections.keys) {
      if (!ids.contains(id)) ids.add(id);
    }
    // Tenendo premuto 500 ms sul titolo di un blocco lo si sposta su o giu'.
    final Widget body = ReorderableListView(
      key: const ValueKey('updates-sections'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        final moved = List<String>.of(ids);
        moved.insert(newIndex, moved.removeAt(oldIndex));
        unawaited(_saveOrder(moved));
      },
      children: [
        for (var i = 0; i < ids.length; i++)
          ReorderableDelayedDragStartListener(
            key: ValueKey('updates-section-${ids[i]}'),
            index: i,
            child: sections[ids[i]]!,
          ),
      ],
    );
    // sul telefono la schermata occupa tutto lo schermo
    if (MediaQuery.sizeOf(context).width < 600) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(appUpdatesPlusTitle(context)),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: appL10n(context).close,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: body,
            ),
          ),
        ),
      );
    }
    return AlertDialog(
      title: Text(appUpdatesPlusTitle(context)),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(child: body),
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
              'Nessuna novita\' ufficiale oltre la ${checker.mergedLabel}.'
                  '${checker.latestVersion == null ? '' : ' Ultima ufficiale trovata: ${checker.latestLabel}${checker.isSkipped ? ' (saltata)' : ''}.'}',
              'Nothing newer upstream than ${checker.mergedLabel}.'
                  '${checker.latestVersion == null ? '' : ' Latest upstream found: ${checker.latestLabel}${checker.isSkipped ? ' (skipped)' : ''}.'}'),
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
            for (final entry in [
              (
                UpdateCheckMode.everyOpen,
                _t(context, 'A ogni apertura', 'Every time the app opens'),
                _t(
                  context,
                  'Controlla ogni volta che apri l\'app o la riporti in primo '
                      'piano. Consigliata.',
                  'Checks every time you open the app or bring it to the '
                      'foreground. Recommended.',
                ),
              ),
              (
                UpdateCheckMode.startOnly,
                _t(context, 'Solo all\'avvio da zero', 'Only on a cold start'),
                _t(
                  context,
                  'Controlla solo quando l\'app parte da chiusa del tutto.',
                  'Checks only when the app starts from fully closed.',
                ),
              ),
              (
                UpdateCheckMode.manual,
                _t(context, 'Solo manuale', 'Manual only'),
                _t(
                  context,
                  'Nessun controllo automatico: usa il pulsante qui sotto.',
                  'No automatic check: use the button below.',
                ),
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: checker.checkMode == entry.$1
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: ValueKey('settings-official-mode-${entry.$1.name}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => checker.setCheckMode(entry.$1),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${checker.checkMode == entry.$1 ? '\u25CF' : '\u25CB'} ${entry.$2}',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(entry.$3, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
            if (checker.isSkipped) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                key: const ValueKey('settings-official-restore'),
                onPressed: checker.restoreSkipped,
                child: Text(_t(context, 'Ripristina versione saltata',
                    'Restore skipped version')),
              ),
            ],
            if (checker.status == OfficialUpdateStatus.newer) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
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
              onPressed: checking
                  ? null
                  : () {
                      // controlla la versione e rilegge anche test e build
                      refreshBuildStatus();
                      updates.checkForUpdates(force: true);
                    },
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


/// Impostazioni: la cartella dove si salvano i PDF (solo Android).
class _SaveFolderTile extends StatelessWidget {
  const _SaveFolderTile();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SaveFolder.changes,
      builder: (context, _, __) => FutureBuilder<({String uri, String name})?>(
        future: SaveFolder.current(),
        builder: (context, snapshot) {
          final folder = snapshot.data;
          return ListTile(
            key: const ValueKey('settings-save-folder'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Cartella di salvataggio'),
            subtitle: Text(folder?.name ??
                'Non impostata: la scegli al primo salvataggio'),
            trailing: folder == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Rimuovi',
                    onPressed: SaveFolder.clear,
                  ),
            onTap: SaveFolder.pick,
          );
        },
      ),
    );
  }
}


/// Una sezione delle Impostazioni: scheda chiusa con il titolo, che si apre
/// toccandola (come un menu a tendina).
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: ValueKey('settings-section-$title'),
            title: Text(
              title.toUpperCase(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}


/// Esito dei test automatici (CI) della build installata: così non serve
/// andare su GitHub per sapere se la build è passata.
class _BuildCheckTile extends StatefulWidget {
  const _BuildCheckTile();

  @override
  State<_BuildCheckTile> createState() => _BuildCheckTileState();
}

class _BuildCheckTileState extends State<_BuildCheckTile> {
  late Future<BuildCheck> _check = BuildCheck.fetch();

  void _reload() => setState(() {
        _check = BuildCheck.fetch();
      });

  @override
  void initState() {
    super.initState();
    buildStatusRefresh.addListener(_reload);
  }

  @override
  void dispose() {
    buildStatusRefresh.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<BuildCheck>(
      future: _check,
      builder: (context, snapshot) {
        final check = snapshot.data;
        final (IconData icon, Color color, String text) = switch (check?.state) {
          null => (
              Icons.hourglass_empty,
              scheme.onSurfaceVariant,
              'Controllo i test della build #${AppInfo.buildNumber}…'
            ),
          BuildCheckState.passed => (
              Icons.check_circle,
              Colors.green,
              'Test automatici superati (build #${AppInfo.buildNumber})'
            ),
          BuildCheckState.failed => (
              Icons.cancel,
              scheme.error,
              'Test automatici FALLITI (build #${AppInfo.buildNumber}). '
                  'Tocca per i dettagli'
            ),
          BuildCheckState.running => (
              Icons.autorenew,
              Colors.orange,
              'Test automatici ancora in corso (build #${AppInfo.buildNumber}). '
                  'Tocca per ricontrollare'
            ),
          BuildCheckState.notStarted => (
              Icons.schedule,
              Colors.orange,
              'Test automatici non ancora partiti. Tocca per ricontrollare'
            ),
          BuildCheckState.unavailable => (
              Icons.help_outline,
              scheme.onSurfaceVariant,
              'Esito dei test non disponibile. Tocca per riprovare'
            ),
        };
        return ListTile(
          key: const ValueKey('settings-build-check'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(icon, color: color),
          title: Text(text),
          onTap: check == null
              ? null
              : (check.state == BuildCheckState.failed && check.url != null)
                  ? () => launchUrl(check.url!,
                      mode: LaunchMode.externalApplication)
                  : _reload,
        );
      },
    );
  }
}


/// Esito dell'ultimo flusso di GitHub su `main` (test o scansione segreti).
class _LatestWorkflowTile extends StatefulWidget {
  const _LatestWorkflowTile({
    required this.tileKey,
    required this.label,
    required this.workflow,
  });

  final String tileKey;
  final String label;
  final String workflow;

  @override
  State<_LatestWorkflowTile> createState() => _LatestWorkflowTileState();
}

class _LatestWorkflowTileState extends State<_LatestWorkflowTile> {
  late Future<BuildCheck> _check = fetchLatestWorkflowCheck(widget.workflow);

  void _reload() => setState(() {
        _check = fetchLatestWorkflowCheck(widget.workflow);
      });

  @override
  void initState() {
    super.initState();
    buildStatusRefresh.addListener(_reload);
  }

  @override
  void dispose() {
    buildStatusRefresh.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<BuildCheck>(
      future: _check,
      builder: (context, snapshot) {
        final check = snapshot.data;
        final (IconData icon, Color color, String text) = switch (check?.state) {
          null => (
              Icons.hourglass_empty,
              scheme.onSurfaceVariant,
              '${widget.label}: controllo…'
            ),
          BuildCheckState.passed => (
              Icons.check_circle,
              Colors.green,
              '${widget.label}: superati'
            ),
          BuildCheckState.failed => (
              Icons.cancel,
              scheme.error,
              '${widget.label}: FALLITI. Tocca per i dettagli'
            ),
          BuildCheckState.running => (
              Icons.autorenew,
              Colors.orange,
              '${widget.label}: in corso. Tocca per ricontrollare'
            ),
          BuildCheckState.notStarted => (
              Icons.schedule,
              Colors.orange,
              '${widget.label}: non ancora partiti. Tocca per ricontrollare'
            ),
          BuildCheckState.unavailable => (
              Icons.help_outline,
              scheme.onSurfaceVariant,
              '${widget.label}: non disponibile. Tocca per riprovare'
            ),
        };
        return ListTile(
          key: ValueKey(widget.tileKey),
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(icon, color: color),
          title: Text(text),
          onTap: check == null
              ? null
              : (check.state == BuildCheckState.failed && check.url != null)
                  ? () => launchUrl(check.url!,
                      mode: LaunchMode.externalApplication)
                  : _reload,
        );
      },
    );
  }
}


/// Stato dell'ultima build su GitHub: se ce n'è una in elaborazione mostra a
/// che punto è (lavoro, passo e da quanto tempo), altrimenti com'è finita
/// l'ultima. Mentre la schermata è aperta e la build è in corso si aggiorna da
/// sola; toccando si ricontrolla subito.
class _BuildRunTile extends StatefulWidget {
  const _BuildRunTile();

  @override
  State<_BuildRunTile> createState() => _BuildRunTileState();
}

class _BuildRunTileState extends State<_BuildRunTile> {
  /// Ogni controllo chiede 2 cose a GitHub, che senza chiave ne concede 60
  /// all'ora: si ricontrolla da soli solo per un po', poi serve toccare.
  static const _autoRefresh = Duration(seconds: 60);
  static const _maxAutoRefreshes = 5;

  BuildRun? _run;
  bool _loading = false;
  int _autoCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    buildStatusRefresh.addListener(_onRefresh);
    unawaited(_load());
  }

  @override
  void dispose() {
    buildStatusRefresh.removeListener(_onRefresh);
    _timer?.cancel();
    super.dispose();
  }

  void _onRefresh() {
    _autoCount = 0;
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) return;
    _timer?.cancel();
    setState(() => _loading = true);
    final run = await BuildRun.fetch();
    if (!mounted) return;
    setState(() {
      _run = run;
      _loading = false;
    });
    if (run.inProgress && _autoCount < _maxAutoRefreshes) {
      _timer = Timer(_autoRefresh, () {
        _autoCount++;
        unawaited(_load());
      });
    }
  }

  static String? _elapsed(DateTime? start) {
    if (start == null) return null;
    final minutes = DateTime.now().toUtc().difference(start.toUtc()).inMinutes;
    return minutes < 1 ? 'da meno di un minuto' : 'da $minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final run = _run;
    final n = run?.number == null ? '' : ' #${run!.number}';

    final (Widget leading, String title) = switch (run?.state) {
      null => (
          Icon(Icons.hourglass_empty, color: scheme.onSurfaceVariant),
          'Controllo la build su GitHub…'
        ),
      BuildRunState.queued => (
          const Icon(Icons.schedule, color: Colors.orange),
          'Build$n in coda su GitHub'
        ),
      BuildRunState.running => (
          const SizedBox(
            width: 24,
            height: 24,
            child: Padding(
              padding: EdgeInsets.all(2),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
          'Build$n in elaborazione'
        ),
      BuildRunState.succeeded => (
          const Icon(Icons.check_circle, color: Colors.green),
          'Ultima build$n completata'
        ),
      BuildRunState.failed => (
          Icon(Icons.cancel, color: scheme.error),
          'Ultima build$n FALLITA. Tocca per i dettagli'
        ),
      BuildRunState.cancelled => (
          Icon(Icons.block, color: scheme.onSurfaceVariant),
          'Ultima build$n annullata'
        ),
      BuildRunState.none => (
          Icon(Icons.help_outline, color: scheme.onSurfaceVariant),
          'Nessuna build trovata'
        ),
      BuildRunState.unavailable => (
          Icon(Icons.help_outline, color: scheme.onSurfaceVariant),
          'Stato della build non disponibile. Tocca per riprovare'
        ),
    };

    final details = <String>[];
    if (run != null && run.state == BuildRunState.running) {
      final count = run.stepCount ?? 0;
      if (run.job != null) details.add(run.job!);
      if (count > 0) {
        final now = (run.stepsDone ?? 0) + 1;
        details.add('passo ${now > count ? count : now} di $count');
      }
      if (run.step != null) details.add(run.step!);
    }
    if (run != null && run.inProgress) {
      final elapsed = _elapsed(run.startedAt);
      if (elapsed != null) details.add(elapsed);
    }
    if (run != null &&
        run.number != null &&
        AppInfo.buildNumber.isNotEmpty &&
        '${run.number}' != AppInfo.buildNumber) {
      details.add('Questa app è la build #${AppInfo.buildNumber}');
    }
    final progress = (run != null &&
            run.state == BuildRunState.running &&
            (run.stepCount ?? 0) > 0)
        ? ((run.stepsDone ?? 0) / run.stepCount!).clamp(0.0, 1.0)
        : null;

    return ListTile(
      key: const ValueKey('settings-build-run'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: leading,
      title: Text(title),
      subtitle: (details.isEmpty && progress == null)
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (details.isNotEmpty) Text(details.join(' · ')),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(value: progress),
                  ),
              ],
            ),
      onTap: _loading
          ? null
          : (run?.state == BuildRunState.failed && run?.url != null)
              ? () => launchUrl(run!.url!, mode: LaunchMode.externalApplication)
              : _load,
    );
  }
}
