import 'package:material_ui/material_ui.dart';

/// Le voci della barra in basso.
enum BottomBarItem { home, create, file, tools, settings }

/// La barra in basso, in stile tesone: cinque voci con icona e nome. Ogni
/// voce dice solo quale e' stata toccata; cosa apre lo decide l'editor.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.onSelected});

  final ValueChanged<BottomBarItem> onSelected;

  static const _items = <(BottomBarItem, String, IconData)>[
    (BottomBarItem.home, 'Home', Icons.home_outlined),
    (BottomBarItem.create, 'Crea', Icons.add_circle_outline),
    (BottomBarItem.file, 'File', Icons.folder_open_outlined),
    (BottomBarItem.tools, 'Strumenti', Icons.apps_outlined),
    (BottomBarItem.settings, 'Impostazioni', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey('bottom-bar'),
      color: theme.colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (final (item, label, icon) in _items)
                Expanded(
                  child: InkWell(
                    key: ValueKey('bottom-bar-${item.name}'),
                    onTap: () => onSelected(item),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon,
                            size: 24, color: theme.colorScheme.onSurface),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
