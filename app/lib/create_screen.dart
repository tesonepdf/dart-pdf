import 'package:material_ui/material_ui.dart';

import 'created_store.dart';

/// Un'azione della schermata Crea: icona, nome e cosa fa.
class CreateAction {
  const CreateAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.run,
  });

  final String id;
  final IconData icon;
  final String label;
  final VoidCallback run;
}

/// Un blocco di azioni, con un titolo se non e' il primo.
class CreateSection {
  const CreateSection({this.title, required this.actions});

  final String? title;
  final List<CreateAction> actions;
}

/// La schermata Crea, in stile tesone: "Azioni rapide" in una griglia a 4
/// colonne con icona e nome. Le azioni sono quelle del gruppo Crea del menu,
/// le stesse, senza copie.
///
/// Si apre come schermata a parte (dalla voce Crea della barra in basso).
/// Toccare un'azione la chiude e la fa partire.
class CreateScreen extends StatelessWidget {
  const CreateScreen(
      {super.key, required this.sections, this.store, this.onOpenCreated});

  final List<CreateSection> sections;

  /// Le creazioni recenti da mostrare in fondo (se manca, la sezione non c'e').
  final CreatedStore? store;

  /// Chiamata quando si tocca una creazione recente (dopo aver chiuso la schermata).
  final ValueChanged<CreatedFile>? onOpenCreated;

  static const _months = [
    'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
    'lug', 'ago', 'set', 'ott', 'nov', 'dic', //
  ];

  static IconData _iconOf(String kind) => switch (kind) {
        'Scansione' || 'Da scanner' => Icons.document_scanner_outlined,
        'Foto in PDF' => Icons.collections_outlined,
        'Foto su un foglio' => Icons.photo_library_outlined,
        'Fumetto' => Icons.auto_stories_outlined,
        'Libro' => Icons.menu_book_outlined,
        _ => Icons.note_add_outlined,
      };

  static String _subtitle(CreatedFile c) {
    final d = DateTime.fromMillisecondsSinceEpoch(c.createdAt);
    return '${c.kind} \u2022 ${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  static const _columns = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const ValueKey('create-screen'),
      appBar: AppBar(title: const Text('Crea')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final (i, section) in sections.indexed) ...[
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 20, bottom: 12),
              child: Text(
                section.title ?? 'Azioni rapide',
                style: theme.textTheme.titleMedium,
              ),
            ),
            GridView.count(
              crossAxisCount: _columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
              children: [
                for (final a in section.actions)
                  InkWell(
                    key: ValueKey('create-action-${a.id}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).pop();
                      a.run();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(a.icon,
                              color: theme.colorScheme.onSecondaryContainer),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          a.label,
                          maxLines: 3,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (store != null) ..._recentSection(context, theme),
        ],
      ),
    );
  }

  List<Widget> _recentSection(BuildContext context, ThemeData theme) => [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text('Creazioni recenti', style: theme.textTheme.titleMedium),
        ),
        ListenableBuilder(
          listenable: store!,
          builder: (context, _) {
            final items = store!.items;
            if (items.isEmpty) {
              return Text(
                'Ancora niente: i documenti che crei compaiono qui.',
                key: const ValueKey('create-recent-empty'),
                style: theme.textTheme.bodyMedium,
              );
            }
            return Column(
              children: [
                for (final (i, c) in items.indexed)
                  ListTile(
                    key: ValueKey('create-recent-$i'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_iconOf(c.kind),
                        color: theme.colorScheme.primary),
                    // Il titolo va a capo quanto serve: si legge per intero.
                    title: Text(c.title),
                    subtitle: Text(_subtitle(c)),
                    onTap: () {
                      Navigator.of(context).pop();
                      onOpenCreated?.call(c);
                    },
                  ),
              ],
            );
          },
        ),
      ];
}
