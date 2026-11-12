import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_log.dart';

/// Apre il Log a schermo intero (Impostazioni > Log e problemi).
Future<void> showAppLog(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => const AppLogScreen(),
      ),
    );

String _two(int n) => n.toString().padLeft(2, '0');

String _dayText(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

String _rangeName(AppLogDateRange r) => switch (r) {
      AppLogDateRange.tutte => 'Tutte le date',
      AppLogDateRange.oggi => 'Oggi',
      AppLogDateRange.ieri => 'Ieri',
      AppLogDateRange.ultimi7 => 'Ultimi 7 giorni',
      AppLogDateRange.giorno => 'Scegli un giorno…',
    };

/// Schermata "Log e problemi": due scelte in alto (Log ed Errori) e, sotto,
/// una sola riga con i filtri per data e per tipo, che si aprono a menu.
class AppLogScreen extends StatefulWidget {
  const AppLogScreen({super.key});

  @override
  State<AppLogScreen> createState() => _AppLogScreenState();
}

class _AppLogScreenState extends State<AppLogScreen> {
  bool _errorsTab = false;
  AppLogDateRange _range = AppLogDateRange.tutte;
  DateTime? _day;
  AppLogType? _type;

  bool get _filtering => _range != AppLogDateRange.tutte || _type != null;

  String get _rangeLabel => switch (_range) {
        AppLogDateRange.giorno => _day == null ? 'Un giorno' : _dayText(_day!),
        _ => _rangeName(_range),
      };

  Future<void> _pickRange(AppLogDateRange r) async {
    if (r != AppLogDateRange.giorno) {
      setState(() {
        _range = r;
        _day = null;
      });
      return;
    }
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? now,
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = AppLogDateRange.giorno;
      _day = picked;
    });
  }

  void _reset() => setState(() {
        _range = AppLogDateRange.tutte;
        _day = null;
        _type = null;
      });

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: AppLog.instance.asText()));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Log copiato')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final log = AppLog.instance;
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final now = DateTime.now();
        final all = log.entries.reversed.toList();
        final errors = [
          for (final e in all)
            if (e.level == AppLogLevel.errore) e
        ];
        final normal = [
          for (final e in all)
            if (e.level != AppLogLevel.errore) e
        ];
        final inTab = _errorsTab ? errors : normal;
        final inDate = [
          for (final e in inTab)
            if (appLogInDateRange(e.time, _range, now, day: _day)) e
        ];
        final typeCounts = <AppLogType, int>{};
        for (final e in inDate) {
          final t = appLogTypeOf(e.context);
          typeCounts[t] = (typeCounts[t] ?? 0) + 1;
        }
        final shown = [
          for (final e in inDate)
            if (_type == null || appLogTypeOf(e.context) == _type) e
        ];
        final emptyText = _filtering
            ? 'Nessuna voce con questi filtri.'
            : _errorsTab
                ? 'Nessun problema registrato.'
                : 'Il Log è vuoto.';
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          key: const ValueKey('app-log-screen'),
          appBar: AppBar(
            title: const Text('Log e problemi'),
            actions: [
              PopupMenuButton<String>(
                key: const ValueKey('app-log-menu'),
                tooltip: 'Altro',
                onSelected: (v) {
                  if (v == 'copy') _copyAll();
                  if (v == 'clear') log.clear();
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'copy',
                    enabled: all.isNotEmpty,
                    child: const Text('Copia tutto'),
                  ),
                  PopupMenuItem<String>(
                    value: 'clear',
                    enabled: all.isNotEmpty,
                    child: const Text('Cancella'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: SegmentedButton<bool>(
                  key: const ValueKey('app-log-tabs'),
                  showSelectedIcon: false,
                  expandedInsets: EdgeInsets.zero,
                  segments: [
                    ButtonSegment<bool>(
                        value: false, label: Text('Log (${normal.length})')),
                    ButtonSegment<bool>(
                        value: true, label: Text('Errori (${errors.length})')),
                  ],
                  selected: {_errorsTab},
                  onSelectionChanged: (s) =>
                      setState(() => _errorsTab = s.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PopupMenuButton<AppLogDateRange>(
                      key: const ValueKey('app-log-date-filter'),
                      tooltip: 'Filtra per data',
                      onSelected: _pickRange,
                      itemBuilder: (context) => [
                        for (final r in AppLogDateRange.values)
                          PopupMenuItem<AppLogDateRange>(
                              value: r, child: Text(_rangeName(r))),
                      ],
                      child: _FilterPill(
                        icon: Icons.event,
                        label: _rangeLabel,
                        active: _range != AppLogDateRange.tutte,
                        color: scheme.secondaryContainer,
                      ),
                    ),
                    PopupMenuButton<int>(
                      key: const ValueKey('app-log-type-filter'),
                      tooltip: 'Filtra per tipo',
                      onSelected: (i) => setState(
                          () => _type = i < 0 ? null : AppLogType.values[i]),
                      itemBuilder: (context) => [
                        const PopupMenuItem<int>(
                            value: -1, child: Text('Tutti i tipi')),
                        for (final t in AppLogType.values)
                          PopupMenuItem<int>(
                            value: t.index,
                            enabled: (typeCounts[t] ?? 0) > 0 || _type == t,
                            child: Text('${t.label} (${typeCounts[t] ?? 0})'),
                          ),
                      ],
                      child: _FilterPill(
                        icon: Icons.category_outlined,
                        label: _type?.label ?? 'Tutti i tipi',
                        active: _type != null,
                        color: scheme.secondaryContainer,
                      ),
                    ),
                    if (_filtering)
                      TextButton(
                        key: const ValueKey('app-log-reset'),
                        onPressed: _reset,
                        child: const Text('Azzera'),
                      ),
                  ],
                ),
              ),
              if (log.persistFailed)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Text(
                    '⚠️ Il Log non si riesce a salvare sul telefono: resta '
                    'solo finché l\'app è aperta.',
                  ),
                ),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(emptyText, textAlign: TextAlign.center),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.paddingOf(context).bottom + 8),
                        itemCount: shown.length,
                        separatorBuilder: (context, i) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) =>
                            _EntryTile(entry: shown[i], now: now),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pulsante-etichetta di un filtro: mostra la scelta attuale e apre il menu.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
      backgroundColor: active ? color : null,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.now});

  final AppLogEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final icon = switch (entry.level) {
      AppLogLevel.ok => '✅',
      AppLogLevel.info => 'ℹ️',
      AppLogLevel.errore => '⚠️',
    };
    final isError = entry.level == AppLogLevel.errore;
    final x = isError ? explainError(entry.message, entry.context) : null;
    final type = appLogTypeOf(entry.context);
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Text(icon, style: const TextStyle(fontSize: 20)),
      title: Text(
        describeLogEntry(entry),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('${appLogWhen(entry.time, now)} · ${type.label}'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (x != null) ...[
          const Text('Cosa succede',
              style: TextStyle(fontWeight: FontWeight.w700)),
          Text(x.cosaSuccede),
          const SizedBox(height: 6),
          const Text('Per i dati',
              style: TextStyle(fontWeight: FontWeight.w700)),
          Text(x.perIDati),
          const SizedBox(height: 6),
          const Text('Cosa fare',
              style: TextStyle(fontWeight: FontWeight.w700)),
          Text(x.cosaFare),
          const SizedBox(height: 6),
        ],
        const Text('Dettaglio tecnico',
            style: TextStyle(fontWeight: FontWeight.w700)),
        SelectableText(entry.message),
      ],
    );
  }
}
