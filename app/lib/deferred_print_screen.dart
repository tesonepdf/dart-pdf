import 'dart:async';
import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart' show showPdfDialog;
import 'package:material_ui/material_ui.dart';

import 'deferred_print.dart';
import 'l10n/app_l10n.dart';

/// Stampa un gruppo. True se e' andato al sistema di stampa (allora il gruppo
/// si cancella); false se l'utente ha annullato o la stampa non e' riuscita
/// (il gruppo resta in coda).
typedef DeferredPrintRun = Future<bool> Function(
    DeferredPrintItem item, Uint8List bytes);

/// Salva i fogli di un gruppo in un PDF.
typedef DeferredPrintSavePdf = Future<void> Function(
    DeferredPrintItem item, Uint8List bytes);

/// La stampa differita: i gruppi di fogli in attesa, da stampare quando si e'
/// a portata di stampante. Un gruppo si cancella appena e' stato stampato.
Future<void> showDeferredPrint(
  BuildContext context, {
  required DeferredPrintStore store,
  required DeferredPrintRun print,
  required DeferredPrintSavePdf savePdf,
}) {
  return showPdfDialog<void>(
    context: context,
    builder: (context) => _DeferredPrintDialog(
      store: store,
      print: print,
      savePdf: savePdf,
    ),
  );
}

String _two(int n) => n.toString().padLeft(2, '0');

String _when(DateTime t) =>
    '${_two(t.day)}/${_two(t.month)} ${_two(t.hour)}:${_two(t.minute)}';

class _DeferredPrintDialog extends StatefulWidget {
  const _DeferredPrintDialog({
    required this.store,
    required this.print,
    required this.savePdf,
  });

  final DeferredPrintStore store;
  final DeferredPrintRun print;
  final DeferredPrintSavePdf savePdf;

  @override
  State<_DeferredPrintDialog> createState() => _DeferredPrintDialogState();
}

class _DeferredPrintDialogState extends State<_DeferredPrintDialog> {
  List<DeferredPrintItem>? _items;
  final Set<String> _selected = {};
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_reload(selectAll: true));
  }

  Future<void> _reload({bool selectAll = false}) async {
    final items = await widget.store.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      if (selectAll) {
        _selected
          ..clear()
          ..addAll(items.map((i) => i.id));
      } else {
        _selected.removeWhere((id) => !items.any((i) => i.id == id));
      }
    });
  }

  Future<void> _printSelected() async {
    final items = _items;
    if (items == null || _busy) return;
    final todo = [
      for (final item in items)
        if (_selected.contains(item.id)) item,
    ];
    if (todo.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    var printed = 0;
    for (final item in todo) {
      final bytes = await widget.store.read(item.id);
      if (bytes == null) {
        await widget.store.remove(item.id);
        continue;
      }
      final ok = await widget.print(item, bytes);
      if (!ok) break;
      // stampato: il gruppo esce dalla coda
      await widget.store.remove(item.id);
      printed++;
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = printed == 0
          ? null
          : printed == 1
              ? 'Gruppo stampato e tolto dalla coda.'
              : '$printed gruppi stampati e tolti dalla coda.';
    });
    await _reload();
  }

  Future<void> _rename(DeferredPrintItem item) async {
    final controller = TextEditingController(text: item.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nome del gruppo'),
        content: TextField(
          key: const ValueKey('deferred-print-rename'),
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appL10n(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    controller.dispose();
    final clean = name?.trim() ?? '';
    if (clean.isEmpty || clean == item.name) return;
    await widget.store.rename(item.id, clean);
    await _reload();
  }

  Future<void> _delete(DeferredPrintItem item) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Togliere dalla coda?'),
        content: Text('"${item.name}" non verrà stampato.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(appL10n(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Togli'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await widget.store.remove(item.id);
    await _reload();
  }

  Future<void> _savePdf(DeferredPrintItem item) async {
    final bytes = await widget.store.read(item.id);
    if (bytes == null) return;
    await widget.savePdf(item, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final theme = Theme.of(context);
    Widget body;
    if (items == null) {
      body = const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (items.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Nessun gruppo in attesa.\n\n'
            'Dalla finestra di stampa scegli "Differita" per metterci '
            'dei fogli: li stampi poi, quando sei vicino alla stampante.'),
      );
    } else {
      body = ListView(
        shrinkWrap: true,
        children: [
          for (final item in items)
            CheckboxListTile(
              key: ValueKey('deferred-print-${item.id}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _selected.contains(item.id),
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                        if (v == true) {
                          _selected.add(item.id);
                        } else {
                          _selected.remove(item.id);
                        }
                      }),
              title: Text(item.name, maxLines: 2),
              subtitle: Text(
                '${item.summary}\n'
                '${item.pages} pagine · ${item.sheets} fogli · '
                '${_when(item.createdAt)}',
              ),
              isThreeLine: true,
              secondary: PopupMenuButton<String>(
                enabled: !_busy,
                onSelected: (v) {
                  switch (v) {
                    case 'rename':
                      unawaited(_rename(item));
                    case 'pdf':
                      unawaited(_savePdf(item));
                    case 'delete':
                      unawaited(_delete(item));
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rinomina')),
                  PopupMenuItem(value: 'pdf', child: Text('Salva come PDF')),
                  PopupMenuItem(value: 'delete', child: Text('Togli dalla coda')),
                ],
              ),
            ),
        ],
      );
    }

    final count = _selected.length;
    return AlertDialog(
      key: const ValueKey('deferred-print-dialog'),
      title: const Text('Stampa differita'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: body),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_message!, style: theme.textTheme.bodySmall),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Chiudi'),
        ),
        FilledButton(
          key: const ValueKey('deferred-print-run'),
          onPressed: _busy || count == 0 ? null : _printSelected,
          child: Text(count == 0 ? 'Stampa' : 'Stampa ($count)'),
        ),
      ],
    );
  }
}
