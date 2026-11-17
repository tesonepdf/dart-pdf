import 'package:material_ui/material_ui.dart';

/// Le schede della schermata Strumenti (dopo "Tutti").
enum ToolTab {
  read('Leggi'),
  create('Crea'),
  edit('Modifica'),
  convert('Converti'),
  other('Altro');

  const ToolTab(this.label);

  final String label;
}

/// Uno strumento della schermata Strumenti: icona, titolo e descrizione breve.
class ToolItem {
  const ToolItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.tab,
    required this.run,
  });

  final String id;
  final IconData icon;
  final String title;
  final String description;
  final ToolTab tab;
  final VoidCallback run;
}

/// La schermata Strumenti, in stile tesone: le schede in alto (Tutti, Leggi,
/// Crea, Modifica, Converti, Altro) e una griglia a 2 colonne con icona,
/// titolo e descrizione. Gli strumenti sono le voci del menu, le stesse, senza
/// copie.
///
/// Si apre come schermata a parte (dalla voce Strumenti della barra in
/// basso). Toccare uno strumento la chiude e lo fa partire.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key, required this.items});

  final List<ToolItem> items;

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  /// Null e' "Tutti".
  ToolTab? _tab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = [
      for (final i in widget.items)
        if (_tab == null || i.tab == _tab) i,
    ];
    return Scaffold(
      key: const ValueKey('tools-screen'),
      appBar: AppBar(title: const Text('Strumenti')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final (tab, label) in <(ToolTab?, String)>[
                  (null, 'Tutti'),
                  for (final t in ToolTab.values) (t, t.label),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey('tools-tab-${tab?.name ?? 'all'}'),
                      label: Text(label),
                      selected: _tab == tab,
                      onSelected: (_) => setState(() => _tab = tab),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(
                      'Nessuno strumento qui.',
                      key: const ValueKey('tools-empty'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      for (final i in shown)
                        Card(
                          key: ValueKey('tool-${i.id}'),
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              i.run();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(i.icon,
                                      size: 28,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(height: 8),
                                  Text(
                                    i.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Expanded(
                                    child: Text(
                                      i.description,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 3,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
