import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'bottom_bar_setting.dart';
import 'file_info.dart';
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

/// La Home, in stile tesone: "Cosa vorresti fare?" con la riga dei pulsanti
/// veloci, sotto le schede Recenti / Con stella / Sul dispositivo coi tre
/// puntini (Seleziona tutto, Vista griglia, Cancella recenti) e l'elenco dei
/// file con miniatura, tipo, data e ora dell'ultima modifica e peso.
///
/// Si apre come schermata a parte (dalla voce Home della barra in basso) o
/// come schermata iniziale ([embedded]). Toccare una scorciatoia o un file fa
/// partire l'azione e, se non e' incorporata, chiude la Home.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.recents,
    required this.shortcuts,
    required this.onOpenRecent,
    this.thumbnails,
    this.embedded = false,
    this.fileInfo,
    StarredStore? starred,
  }) : starred = starred;

  final RecentsStore recents;
  final List<HomeShortcut> shortcuts;
  final void Function(RecentFile entry) onOpenRecent;
  final RecentThumbnailCache? thumbnails;
  final StarredStore? starred;

  /// True quando la Home e' la schermata iniziale dell'app (senza documento):
  /// niente barra del titolo con la freccia e niente chiusura quando si sceglie.
  final bool embedded;

  /// Come leggere peso e data di un file. Se manca, si mostra solo la data
  /// dell'ultima apertura e niente peso.
  final FileInfoReader? fileInfo;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeTab _tab = _HomeTab.recent;
  bool _selecting = false;
  final Set<String> _selected = {};
  final Map<String, FileInfo> _info = {};
  final Set<String> _requested = {};

  /// Le miniature piccole, come nell'elenco dell'app di riferimento.
  static const _thumbWidth = 30.0;
  static const _thumbHeight = 42.0;

  static const _palette = <Color>[
    Colors.indigo,
    Colors.pink,
    Colors.blue,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.green,
    Colors.orange,
  ];

  StarredStore get _starred => widget.starred ?? StarredStore.instance;

  @override
  void initState() {
    super.initState();
    widget.recents.load();
    _starred.load();
    HomeGridSetting.instance.load();
  }

  /// "PDF" dall'estensione del nome, poi data e ora dell'ultima modifica e
  /// peso (se il file si puo' leggere).
  String _subtitle(RecentFile e) {
    final dot = e.title.lastIndexOf('.');
    final type = dot > 0 && dot < e.title.length - 1
        ? e.title.substring(dot + 1).toUpperCase()
        : 'PDF';
    final info = _info[e.id];
    final when =
        info?.modified ?? DateTime.fromMillisecondsSinceEpoch(e.openedAt);
    return [
      type,
      formatFileDate(when, DateTime.now()),
      if (info != null) formatFileSize(info.size),
    ].join(' \u2022 ');
  }

  /// Chiede il peso e la data dei file in vista, una volta sola per file.
  void _ensureInfo(List<RecentFile> items) {
    final reader = widget.fileInfo;
    if (reader == null) return;
    for (final e in items) {
      final path = e.readPath;
      if (path == null || !_requested.add(e.id)) continue;
      unawaited(reader(path).then((info) {
        if (mounted && info != null) setState(() => _info[e.id] = info);
      }, onError: (Object _) {}));
    }
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

  void _toggleSelected(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  void _endSelecting() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  void _removeSelected() {
    final ids = [..._selected];
    _endSelecting();
    for (final id in ids) {
      unawaited(widget.recents.remove(id));
    }
  }

  Future<void> _openMenu() {
    final grid = HomeGridSetting.instance.value;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('home-menu-select-all'),
              leading: const Icon(Icons.checklist_outlined),
              title: const Text('Seleziona tutto'),
              onTap: () {
                Navigator.of(sheet).pop();
                setState(() {
                  _selecting = true;
                  _selected
                    ..clear()
                    ..addAll([for (final e in _visible()) e.id]);
                });
              },
            ),
            ListTile(
              key: const ValueKey('home-menu-view'),
              leading: Icon(
                  grid ? Icons.view_list_outlined : Icons.grid_view_outlined),
              title: Text(grid ? 'Vista elenco' : 'Vista griglia'),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(HomeGridSetting.instance.save(!grid));
              },
            ),
            ListTile(
              key: const ValueKey('home-menu-clear'),
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Cancella recenti'),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(widget.recents.clear());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _shortcuts(ThemeData theme) => SizedBox(
        height: 104,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final (i, s) in widget.shortcuts.indexed)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  key: ValueKey('home-shortcut-${s.id}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openAndClose(s.run),
                  child: SizedBox(
                    width: 84,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _palette[i % _palette.length]
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(s.icon,
                              size: 28, color: _palette[i % _palette.length]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _tabsRow(ThemeData theme) {
    if (_selecting) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _selected.length == 1
                  ? '1 selezionato'
                  : '${_selected.length} selezionati',
              key: const ValueKey('home-select-count'),
              style: theme.textTheme.titleMedium,
            ),
          ),
          TextButton(
            key: const ValueKey('home-select-remove'),
            onPressed: _selected.isEmpty ? null : _removeSelected,
            child: const Text('Togli dall\'elenco'),
          ),
          TextButton(
            key: const ValueKey('home-select-done'),
            onPressed: _endSelecting,
            child: const Text('Fine'),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (tab, label) in const [
                  (_HomeTab.recent, 'Recenti'),
                  (_HomeTab.starred, 'Con stella'),
                  (_HomeTab.device, 'Sul dispositivo'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: InkWell(
                      key: ValueKey('home-tab-${tab.name}'),
                      onTap: () => setState(() => _tab = tab),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              width: 2,
                              color: _tab == tab
                                  ? theme.colorScheme.onSurface
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                        child: Text(
                          label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: _tab == tab
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: _tab == tab
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('home-menu'),
          tooltip: 'Altro',
          icon: const Icon(Icons.more_vert),
          onPressed: _openMenu,
        ),
      ],
    );
  }

  /// Il menu dei tre puntini di un file: stella e "togli dall'elenco".
  Widget _fileMenu(RecentFile e) => PopupMenuButton<String>(
        key: ValueKey('home-more-${e.id}'),
        tooltip: 'Altro',
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          if (value == 'star') {
            _starred.toggle(e.id);
          } else if (value == 'remove') {
            unawaited(widget.recents.remove(e.id));
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            key: ValueKey('home-star-${e.id}'),
            value: 'star',
            child: Text(
                _starred.isStarred(e.id) ? 'Togli la stella' : 'Metti la stella'),
          ),
          PopupMenuItem<String>(
            key: ValueKey('home-remove-${e.id}'),
            value: 'remove',
            child: const Text('Togli dall\'elenco'),
          ),
        ],
      );

  void _onTapFile(RecentFile e) {
    if (_selecting) {
      _toggleSelected(e.id);
    } else {
      _openAndClose(() => widget.onOpenRecent(e));
    }
  }

  Widget _row(RecentFile e, ThemeData theme) => InkWell(
        key: ValueKey('home-file-${e.id}'),
        onTap: () => _onTapFile(e),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecentThumbnailView(
                entry: e,
                thumbnails: widget.thumbnails,
                width: _thumbWidth,
                height: _thumbHeight,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Il titolo va a capo quanto serve: si legge per intero.
                    Text(e.title, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (_starred.isStarred(e.id))
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.star,
                                size: 15, color: Colors.amber),
                          ),
                        if (e.isReopenable)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.smartphone_outlined,
                                size: 15,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        Flexible(
                          child: Text(
                            _subtitle(e),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_selecting)
                Checkbox(
                  key: ValueKey('home-check-${e.id}'),
                  value: _selected.contains(e.id),
                  onChanged: (_) => _toggleSelected(e.id),
                )
              else
                _fileMenu(e),
            ],
          ),
        ),
      );

  Widget _tile(RecentFile e, ThemeData theme) => InkWell(
        key: ValueKey('home-file-${e.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onTapFile(e),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: RecentThumbnailView(
                    entry: e,
                    thumbnails: widget.thumbnails,
                    width: 96,
                    height: 128,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(e),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (_selecting)
                    Checkbox(
                      key: ValueKey('home-check-${e.id}'),
                      value: _selected.contains(e.id),
                      onChanged: (_) => _toggleSelected(e.id),
                    )
                  else
                    _fileMenu(e),
                ],
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const ValueKey('home-screen'),
      appBar: widget.embedded ? null : AppBar(title: const Text('Home')),
      body: ListenableBuilder(
        listenable: Listenable.merge(
            [widget.recents, _starred, HomeGridSetting.instance]),
        builder: (context, _) {
          final items = _visible();
          _ensureInfo(items);
          final grid = HomeGridSetting.instance.value;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, widget.embedded ? 24 : 8, 16, 24),
            children: [
              Text('Cosa vorresti fare?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _shortcuts(theme),
              const SizedBox(height: 8),
              _tabsRow(theme),
              const Divider(height: 1),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    switch (_tab) {
                      _HomeTab.starred =>
                        'Nessun file con la stella. Apri il menu di un file e scegli "Metti la stella".',
                      _HomeTab.device => 'Nessun file sul dispositivo.',
                      _HomeTab.recent => 'Nessun file recente.',
                    },
                    key: const ValueKey('home-empty'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else if (grid)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: GridView.count(
                    key: const ValueKey('home-grid'),
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.66,
                    children: [for (final e in items) _tile(e, theme)],
                  ),
                )
              else
                for (final (i, e) in items.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _row(e, theme),
                ],
            ],
          );
        },
      ),
    );
  }
}
