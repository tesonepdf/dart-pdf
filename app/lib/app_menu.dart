// Il menu dell'app: uno solo, uguale su telefono, PC, web e Mac (richiesta
// dell'utente, 15/11: "quando vado da telefono a PC vado al manicomio").
//
// E' una finestra ancorata in alto a sinistra, con la ricerca in cima e le
// voci raccolte in macroaree che si aprono e si chiudono (a fisarmonica). Le
// voci sono le stesse del campo "Cerca": le costruisce
// `EditorScreen._commandEntries`, quindi una voce nuova compare qui, nella
// ricerca e nei gruppi senza una seconda registrazione.
import 'package:dart_pdf_editor/dart_pdf_editor.dart'
    show PdfKeyboardAvailability;
import 'package:material_ui/material_ui.dart';

import 'app_info.dart';
import 'command_palette.dart' show AppCommand;
import 'middle_ellipsis_text.dart';

/// Un blocco di voci dentro una macroarea, con un titoletto facoltativo.
@immutable
class AppMenuSection {
  const AppMenuSection(this.commands, {this.title, this.toggles = false});

  final String? title;
  final List<AppCommand> commands;

  /// Le voci si accendono e si spengono: a destra c'e' un interruttore.
  final bool toggles;
}

/// Una macroarea del menu (File, Pagine, Visualizza...).
@immutable
class AppMenuGroup {
  const AppMenuGroup({
    required this.id,
    required this.title,
    required this.icon,
    required this.sections,
    this.open = false,
  });

  /// Identita' stabile: e' anche la chiave `app-menu-group-<id>`.
  final String id;
  final String title;
  final IconData icon;
  final List<AppMenuSection> sections;

  /// Si apre da sola quando si apre il menu.
  final bool open;
}

/// Apre il menu e restituisce la voce scelta, da eseguire a menu chiuso (null
/// se si chiude senza scegliere).
Future<VoidCallback?> showAppMenu(
  BuildContext context, {
  required List<AppMenuGroup> groups,
  required String searchLabel,
  required VoidCallback onSearch,
  String? searchShortcut,
  String? title,
  VoidCallback? onRename,
}) =>
    showDialog<VoidCallback>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (context) => _AppMenuPanel(
        groups: groups,
        searchLabel: searchLabel,
        onSearch: onSearch,
        searchShortcut: searchShortcut,
        title: title,
        onRename: onRename,
      ),
    );

class _AppMenuPanel extends StatelessWidget {
  const _AppMenuPanel({
    required this.groups,
    required this.searchLabel,
    required this.onSearch,
    this.searchShortcut,
    this.title,
    this.onRename,
  });

  final List<AppMenuGroup> groups;
  final String searchLabel;
  final VoidCallback onSearch;
  final String? searchShortcut;
  final String? title;
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = PdfKeyboardAvailability.of(context);
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              key: const ValueKey('app-menu'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title case final title? when title.isNotEmpty)
                    InkWell(
                      key: const ValueKey('mobile-document-title'),
                      onTap: onRename == null
                          ? null
                          : () => Navigator.of(context).pop(onRename),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: MiddleEllipsisText(
                                title,
                                hidePdfExtension: true,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            if (onRename != null)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(Icons.edit_outlined, size: 20),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ListTile(
                    key: const ValueKey('menu-command-palette'),
                    leading: const Icon(Icons.search),
                    title: Text(searchLabel),
                    trailing: keyboard && searchShortcut != null
                        ? Text(
                            searchShortcut!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(onSearch),
                  ),
                  const Divider(height: 1),
                  Padding(
                    key: const ValueKey('app-menu-version'),
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
                    child: Text(
                      '${AppInfo.displayName} ${AppInfo.displayVersion}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final group in groups)
                    _group(context, group, keyboard: keyboard),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _group(BuildContext context, AppMenuGroup group,
      {required bool keyboard}) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('app-menu-group-${group.id}'),
        initiallyExpanded: group.open,
        leading: Icon(group.icon),
        title: Text(
          group.title,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        childrenPadding: EdgeInsets.zero,
        children: [
          for (final section in group.sections) ...[
            if (section.title != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(32, 10, 16, 2),
                child: Text(
                  section.title!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final command in section.commands)
              _row(context, command,
                  toggle: section.toggles, keyboard: keyboard),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppCommand command,
      {required bool toggle, required bool keyboard}) {
    final theme = Theme.of(context);
    Widget? trailing;
    if (toggle) {
      trailing = Switch(
        value: command.selected,
        onChanged:
            command.enabled ? (_) => Navigator.of(context).pop(command.run) : null,
      );
    } else if (keyboard && command.shortcut != null) {
      trailing = Text(
        command.shortcut!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else if (command.selected) {
      trailing = const Icon(Icons.check, size: 20);
    }
    final recent = command.id.startsWith('recent-');
    final subtitle = command.subtitle != null
        ? MiddleEllipsisText(command.subtitle!)
        : !command.enabled && command.disabledReason != null
            ? Text(command.disabledReason!)
            : null;
    return ListTile(
      key: ValueKey(command.id),
      contentPadding: const EdgeInsetsDirectional.only(start: 32, end: 16),
      leading: Icon(command.icon, size: 22),
      title: recent
          ? MiddleEllipsisText(command.label, hidePdfExtension: true)
          : Text(command.label, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle,
      trailing: trailing,
      enabled: command.enabled,
      onTap: command.enabled ? () => Navigator.of(context).pop(command.run) : null,
    );
  }
}
