import 'package:dart_pdf_editor/dart_pdf_editor.dart' show showPdfDialog;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_log.dart';

/// Apre il Log (Impostazioni > Log e problemi).
Future<void> showAppLog(BuildContext context) =>
    showPdfDialog<void>(
      context: context,
      builder: (context) => const _AppLogDialog(),
    );

String _two(int n) => n.toString().padLeft(2, '0');

String _when(DateTime t) =>
    '${_two(t.day)}/${_two(t.month)} ${_two(t.hour)}:${_two(t.minute)}:'
    '${_two(t.second)}';

class _AppLogDialog extends StatefulWidget {
  const _AppLogDialog();

  @override
  State<_AppLogDialog> createState() => _AppLogDialogState();
}

class _AppLogDialogState extends State<_AppLogDialog> {
  bool _onlyErrors = false;

  @override
  Widget build(BuildContext context) {
    final log = AppLog.instance;
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final all = log.entries.reversed.toList();
        final shown = _onlyErrors
            ? [for (final e in all) if (e.level == AppLogLevel.errore) e]
            : all;
        final errors = all.where((e) => e.level == AppLogLevel.errore).length;
        return AlertDialog(
          key: const ValueKey('app-log-dialog'),
          title: const Text('Log e problemi'),
          content: SizedBox(
            width: double.maxFinite,
            height: 440,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.persistFailed)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '⚠️ Il Log non si riesce a salvare sul telefono: resta '
                      'solo finche l\'app e\' aperta.',
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('Tutto (${all.length})'),
                      selected: !_onlyErrors,
                      onSelected: (_) => setState(() => _onlyErrors = false),
                    ),
                    ChoiceChip(
                      label: Text('Solo errori ($errors)'),
                      selected: _onlyErrors,
                      onSelected: (_) => setState(() => _onlyErrors = true),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: shown.isEmpty
                      ? const Center(child: Text('Nessuna voce.'))
                      : ListView.builder(
                          itemCount: shown.length,
                          itemBuilder: (context, i) =>
                              _EntryTile(entry: shown[i]),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: all.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(
                          ClipboardData(text: log.asText()));
                      if (!context.mounted) return;
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(content: Text('Log copiato')),
                      );
                    },
              child: const Text('Copia tutto'),
            ),
            TextButton(
              onPressed: all.isEmpty ? null : log.clear,
              child: const Text('Cancella'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Chiudi'),
            ),
          ],
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final AppLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final icon = switch (entry.level) {
      AppLogLevel.ok => '✅',
      AppLogLevel.info => 'ℹ️',
      AppLogLevel.errore => '⚠️',
    };
    final firstLine = entry.message.split('\n').first;
    final isError = entry.level == AppLogLevel.errore;
    final x = isError ? explainError(entry.message, entry.context) : null;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: Text(icon, style: const TextStyle(fontSize: 20)),
      title: Text(entry.context),
      subtitle: Text(
        '${_when(entry.time)} - $firstLine',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      childrenPadding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
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
          const Text('Dettaglio tecnico',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ],
        SelectableText(entry.message),
      ],
    );
  }
}
