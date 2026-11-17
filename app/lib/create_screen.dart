import 'package:material_ui/material_ui.dart';

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
  const CreateScreen({super.key, required this.sections});

  final List<CreateSection> sections;

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
        ],
      ),
    );
  }
}
