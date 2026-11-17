import 'package:material_ui/material_ui.dart';

import 'recent_thumbnails.dart';
import 'recents.dart';
import 'starred_store.dart';
import 'welcome_screen.dart';

/// Una scorciatoia della Home: icona, nome e cosa fa.
class HomeShortcut {
  const HomeShortcut({
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

enum _HomeTab { recent, starred, device }

/// La Home, in stile tesone: il saluto, "Cosa vorresti fare?" con le
/// scorciatoie e sotto le schede Recenti / Con stella / Sul dispositivo.
///
/// Si apre come schermata a parte (dalla voce Home della barra in basso).
/// Toccare una scorciatoia o un file la chiude e fa partire l'azione.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.recents,
    required this.shortcuts,
    required this.onOpenRecent,
    this.thumbnails,
    this.embedded = false,
    StarredStore? starred,
  }) : starred = starred;

  /// True quando la Home e' la schermata iniziale dell'app (senza documento):
  /// niente barra del titolo con la freccia e niente chiusura quando si sceglie.
  final bool embedded;

  final RecentsStore recents;
  final List<HomeShortcut> shortcuts;
  final void Function(RecentFile entry) onOpenRecent;
  final RecentThumbnailCache? thumbnails;
  final StarredStore? starred;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeTab _tab = _HomeTab.recent;

  StarredStore get _starred => widget.starred ?? StarredStore.instance;

  @override
  void initState() {
    super.initState();
    widget.recents.load();
    _starred.load();
  }

  static const _months = [
    'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
    'lug', 'ago', 'set', 'ott', 'nov', 'dic', //
  ];

  /// "PDF • 17 nov 2026": il tipo dall'estensione del nome, poi la data
  /// dell'ultima apertura.
  static String _subtitle(RecentFile e) {
    final dot = e.title.lastIndexOf('.');
    final type = dot > 0 && dot < e.title.length - 1
        ? e.title.substring(dot + 1).toUpperCase()
        : 'PDF';
    final d = DateTime.fromMillisecondsSinceEpoch(e.openedAt);
    return '$type • ${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  List<RecentFile> _visible() {
    final all = widget.recents.items;
    return switch (_tab) {
      _HomeTab.recent => all,
      _HomeTab.starred => [
          for (final e in all)
            if (_starred.isStarred(e.id)) e,
        ],
      _HomeTab.device => [
          for (final e in all)
            if (e.isReopenable) e,
        ],
    };
  }

  void _openAndClose(VoidCallback run) {
    if (!widget.embedded) Navigator.of(context).pop();
    run();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const ValueKey('home-screen'),
      appBar: widget.embedded ? null : AppBar(title: const Text('Home')),
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.recents, _starred]),
        builder: (context, _) {
          final items = _visible();
          return ListView(
            padding: EdgeInsets.fromLTRB(16, widget.embedded ? 24 : 8, 16, 24),
            children: [
              Text('Bentornato/a', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 20),
              Text('Cosa vorresti fare?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final s in widget.shortcuts)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          key: ValueKey('home-shortcut-${s.id}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openAndClose(s.run),
                          child: SizedBox(
                            width: 84,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(s.icon,
                                      color: theme
                                          .colorScheme.onSecondaryContainer),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  s.label,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final (tab, label) in const [
                    (_HomeTab.recent, 'Recenti'),
                    (_HomeTab.starred, 'Con stella'),
                    (_HomeTab.device, 'Sul dispositivo'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: ValueKey('home-tab-${tab.name}'),
                        label: Text(label),
                        selected: _tab == tab,
                        onSelected: (_) => setState(() => _tab = tab),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    switch (_tab) {
                      _HomeTab.starred =>
                        'Nessun file con la stella. Tocca la stella accanto a un file per metterlo qui.',
                      _HomeTab.device => 'Nessun file sul dispositivo.',
                      _HomeTab.recent => 'Nessun file recente.',
                    },
                    key: const ValueKey('home-empty'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                for (final e in items)
                  ListTile(
                    key: ValueKey('home-file-${e.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: RecentThumbnailView(
                      entry: e,
                      thumbnails: widget.thumbnails,
                      width: 44,
                      height: 58,
                    ),
                    // Il titolo va a capo quanto serve: si legge per intero.
                    title: Text(e.title),
                    subtitle: Text(_subtitle(e)),
                    trailing: IconButton(
                      key: ValueKey('home-star-${e.id}'),
                      tooltip: _starred.isStarred(e.id)
                          ? 'Togli la stella'
                          : 'Metti la stella',
                      icon: Icon(_starred.isStarred(e.id)
                          ? Icons.star
                          : Icons.star_border),
                      onPressed: () => _starred.toggle(e.id),
                    ),
                    onTap: () => _openAndClose(() => widget.onOpenRecent(e)),
                  ),
            ],
          );
        },
      ),
    );
  }
}
