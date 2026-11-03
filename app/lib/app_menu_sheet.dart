// The phone menu uses the same File, This document, and App groups as the
// desktop popup, with full-width touch targets and a recent-files subpage.
import 'package:material_ui/material_ui.dart';

import 'l10n/app_l10n.dart';
import 'middle_ellipsis_text.dart';

/// One tappable thing in the sheet.
@immutable
class AppMenuSheetEntry {
  const AppMenuSheetEntry({
    required this.key,
    required this.icon,
    required this.title,
    required this.run,
    this.subtitle,
    this.enabled = true,
    this.group,
  });

  /// Il gruppo a tendina in cui sta la voce (vedi [kMenuGroups]); null =
  /// "Documento aperto".
  final String? group;
  final Key key;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback run;
  final bool enabled;
}

/// Shows the phone app menu and returns the action the user picked, to run
/// once the sheet is gone (the same contract as the popup's `onSelected`, so
/// a dialog an action opens never stacks on the closing sheet).
Future<VoidCallback?> showAppMenuSheet(
  BuildContext context, {
  String? title,
  required AppMenuSheetEntry search,
  required List<AppMenuSheetEntry> file,
  required List<AppMenuSheetEntry> document,
  required List<AppMenuSheetEntry> recentFiles,
  required AppMenuSheetEntry viewAllRecentFiles,
  required AppMenuSheetEntry? clearRecentFiles,
  required bool? readOnly,
  required VoidCallback onToggleReadOnly,
  required List<AppMenuSheetEntry> app,
  AppMenuSheetEntry? settings,
  List<AppMenuSheetEntry> toOrganize = const [],
  List<AppMenuSheetEntry> importEntries = const [],
}) =>
    showModalBottomSheet<VoidCallback>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => AppMenuSheet(
        title: title,
        search: search,
        file: file,
        document: document,
        recentFiles: recentFiles,
        viewAllRecentFiles: viewAllRecentFiles,
        clearRecentFiles: clearRecentFiles,
        readOnly: readOnly,
        onToggleReadOnly: onToggleReadOnly,
        app: app,
        settings: settings,
        toOrganize: toOrganize,
        importEntries: importEntries,
      ),
    );

class AppMenuSheet extends StatefulWidget {
  const AppMenuSheet({
    super.key,
    this.title,
    required this.search,
    required this.file,
    required this.document,
    required this.recentFiles,
    required this.viewAllRecentFiles,
    required this.clearRecentFiles,
    required this.readOnly,
    required this.onToggleReadOnly,
    required this.app,
    this.settings,
    this.toOrganize = const [],
    this.importEntries = const [],
  });

  /// Le voci di importazione (foto, scanner...).
  final List<AppMenuSheetEntry> importEntries;

  /// The open document's name, shown at the top of the menu.
  final String? title;

  /// The search field: opens the command palette.
  final AppMenuSheetEntry search;

  final List<AppMenuSheetEntry> file;
  final List<AppMenuSheetEntry> document;
  final List<AppMenuSheetEntry> recentFiles;
  final AppMenuSheetEntry viewAllRecentFiles;
  final AppMenuSheetEntry? clearRecentFiles;

  /// Null without a document (no switch to show).
  final bool? readOnly;
  final VoidCallback onToggleReadOnly;

  final List<AppMenuSheetEntry> app;

  /// "Impostazioni": l'ultima riga del menu, fuori dalla sezione APP.
  final AppMenuSheetEntry? settings;

  /// New things from the upstream project that have no place in the groups
  /// above yet: shown in their own "To organize" section.
  final List<AppMenuSheetEntry> toOrganize;

  @override
  State<AppMenuSheet> createState() => _AppMenuSheetState();
}

/// I gruppi a tendina delle azioni sul documento, nell'ordine in cui
/// compaiono: id e titolo.
const List<({String id, String title})> kMenuGroups = [
  (id: 'doc', title: 'Documento aperto'),
  (id: 'send', title: 'Condividi e invia'),
  (id: 'save', title: 'Salva, stampa, esporta'),
  (id: 'sign', title: 'Firma e testo (OCR)'),
  (id: 'pages', title: 'Pagine'),
  (id: 'forms', title: 'Moduli e dati'),
];

/// A page inside the sheet that a folded group opens.
typedef _SubPage = ({String id, String title, List<AppMenuSheetEntry> items});

class _AppMenuSheetState extends State<AppMenuSheet> {
  _SubPage? _page;

  void _pick(AppMenuSheetEntry entry) => Navigator.of(context).pop(entry.run);

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return PopScope(
      // Back on a page returns to the menu; back on the menu closes it.
      canPop: page == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _page = null);
      },
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 8),
            child: page == null ? _buildMain(context) : _buildPage(page),
          ),
        ),
      ),
    );
  }

  Widget _group(String id, String title, List<Widget> children,
          {bool open = false}) =>
      ExpansionTile(
        key: ValueKey('app-menu-group-$id'),
        initiallyExpanded: open,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: EdgeInsets.zero,
        title: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        children: children,
      );

  Widget _buildMain(BuildContext context) {
    final l = appL10n(context);
    final all = [...widget.document, ...widget.toOrganize];
    List<AppMenuSheetEntry> inGroup(String g) => [
          for (final e in all)
            if ((e.group ?? 'doc') == g) e,
        ];
    final appExtra = inGroup('app');
    final hasApp = widget.readOnly != null ||
        widget.app.isNotEmpty ||
        appExtra.isNotEmpty;
    return Column(
      key: const ValueKey('app-menu-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.title case final title? when title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: MiddleEllipsisText(
              title,
              hidePdfExtension: true,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        _SearchField(entry: widget.search, onTap: () => _pick(widget.search)),
        const Divider(height: 24),
        _group(
          'file',
          l.editorMenuSectionFile,
          [
            for (final entry in widget.file) _row(entry),
            ListTile(
              key: const ValueKey('menu-open-recent'),
              leading: const Icon(Icons.history),
              title: Text(l.editorOpenRecent),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(
                () => _page = (
                  id: 'recent',
                  title: l.editorOpenRecent,
                  items: [
                    widget.viewAllRecentFiles,
                    if (widget.recentFiles.isEmpty)
                      AppMenuSheetEntry(
                        key: const ValueKey('menu-no-recent-files'),
                        icon: Icons.history_toggle_off,
                        title: l.editorNoRecentFiles,
                        run: () {},
                        enabled: false,
                      )
                    else
                      ...widget.recentFiles,
                    if (widget.clearRecentFiles case final clear?) clear,
                  ],
                ),
              ),
            ),
          ],
          open: true,
        ),
        if (widget.importEntries.isNotEmpty)
          _group('import', 'Importa',
              [for (final entry in widget.importEntries) _row(entry)]),
        for (final g in kMenuGroups)
          if (inGroup(g.id).isNotEmpty)
            _group(g.id, g.title, [for (final e in inGroup(g.id)) _row(e)]),
        if (hasApp)
          _group('app', l.editorMenuSectionApp, [
            if (widget.readOnly case final readOnly?)
              SwitchListTile(
                key: const ValueKey('menu-read-only'),
                secondary: const Icon(Icons.visibility_outlined),
                title: Text(l.editorMenuReadOnly),
                value: readOnly,
                onChanged: (_) =>
                    Navigator.of(context).pop(widget.onToggleReadOnly),
              ),
            for (final entry in widget.app) _row(entry),
            for (final entry in appExtra) _row(entry),
          ]),
        if (widget.settings case final settings?) ...[
          const Divider(height: 8),
          _row(settings),
        ],
      ],
    );
  }

  Widget _buildPage(_SubPage page) => Column(
        key: ValueKey('app-menu-sheet-${page.id}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 16),
            child: Row(
              children: [
                const BackButton(),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    page.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          for (final entry in page.items) _row(entry),
        ],
      );

  Widget _row(AppMenuSheetEntry entry) => ListTile(
        key: entry.key,
        enabled: entry.enabled,
        leading: Icon(entry.icon),
        title: Text(entry.title),
        subtitle: entry.subtitle == null
            ? null
            : MiddleEllipsisText(entry.subtitle!),
        onTap: () => _pick(entry),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.entry, required this.onTap});

  final AppMenuSheetEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: entry.key,
          onTap: onTap,
          child: Semantics(
            button: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(entry.icon, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
