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
  });

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
  required AppMenuSheetEntry search,
  required List<AppMenuSheetEntry> file,
  required List<AppMenuSheetEntry> document,
  required List<AppMenuSheetEntry> recentFiles,
  required AppMenuSheetEntry viewAllRecentFiles,
  required AppMenuSheetEntry? clearRecentFiles,
  required bool? readOnly,
  required VoidCallback onToggleReadOnly,
  required List<AppMenuSheetEntry> app,
  List<AppMenuSheetEntry> toOrganize = const [],
}) =>
    showModalBottomSheet<VoidCallback>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => AppMenuSheet(
        search: search,
        file: file,
        document: document,
        recentFiles: recentFiles,
        viewAllRecentFiles: viewAllRecentFiles,
        clearRecentFiles: clearRecentFiles,
        readOnly: readOnly,
        onToggleReadOnly: onToggleReadOnly,
        app: app,
        toOrganize: toOrganize,
      ),
    );

class AppMenuSheet extends StatefulWidget {
  const AppMenuSheet({
    super.key,
    required this.search,
    required this.file,
    required this.document,
    required this.recentFiles,
    required this.viewAllRecentFiles,
    required this.clearRecentFiles,
    required this.readOnly,
    required this.onToggleReadOnly,
    required this.app,
    this.toOrganize = const [],
  });

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

  /// New things from the upstream project that have no place in the groups
  /// above yet: shown in their own "To organize" section.
  final List<AppMenuSheetEntry> toOrganize;

  @override
  State<AppMenuSheet> createState() => _AppMenuSheetState();
}

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

  Widget _buildMain(BuildContext context) {
    final l = appL10n(context);
    final appItemCount = widget.app.length + (widget.readOnly == null ? 0 : 1);
    return Column(
      key: const ValueKey('app-menu-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchField(entry: widget.search, onTap: () => _pick(widget.search)),
        const Divider(height: 24),
        if (widget.file.length + 1 >= 2)
          _SectionLabel(l.editorMenuSectionFile),
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
                if (widget.clearRecentFiles case final clear?)
                  clear,
              ],
            ),
          ),
        ),
        if (widget.document.isNotEmpty) ...[
          const Divider(height: 24),
          if (widget.document.length >= 2)
            _SectionLabel(l.editorMenuSectionDocument),
          for (final entry in widget.document) _row(entry),
        ],
        if (widget.toOrganize.isNotEmpty) ...[
          const Divider(height: 24),
          _SectionLabel(
            Localizations.localeOf(context).languageCode == 'it'
                ? 'Da organizzare'
                : 'To organize',
          ),
          for (final entry in widget.toOrganize) _row(entry),
        ],
        if (appItemCount > 0) ...[
          const Divider(height: 24),
          if (appItemCount >= 2) _SectionLabel(l.editorMenuSectionApp),
        ],
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

/// The same quiet 11px uppercase header the popup and tool sheet use.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}
