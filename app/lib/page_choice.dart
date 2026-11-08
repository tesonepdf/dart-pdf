import 'package:flutter/material.dart';

/// Le pagine scritte dall'utente ("1,3,5-7") come indici da 0, in ordine e
/// senza doppioni. Null se il testo e' vuoto, non si capisce o una pagina non
/// esiste in un documento di [pageCount] pagine.
List<int>? parsePageList(String text, int pageCount) {
  final pages = <int>{};
  for (final raw in text.split(RegExp(r'[,;\s]+'))) {
    final token = raw.trim();
    if (token.isEmpty) continue;
    final parts = token.split(RegExp(r'[-–—]'));
    if (parts.length == 1) {
      final n = int.tryParse(parts[0]);
      if (n == null || n < 1 || n > pageCount) return null;
      pages.add(n - 1);
    } else if (parts.length == 2) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      if (a == null || b == null || a < 1 || b > pageCount || a > b) {
        return null;
      }
      for (var n = a; n <= b; n++) {
        pages.add(n - 1);
      }
    } else {
      return null;
    }
  }
  if (pages.isEmpty) return null;
  return pages.toList()..sort();
}

/// Che cosa mandare: `pages` e' null per tutto il documento, altrimenti gli
/// indici (da 0) delle pagine scelte.
typedef PageChoice = ({List<int>? pages});

/// Chiede se mandare tutto il documento, la pagina che si sta guardando
/// ([currentPage], da 0) o alcune pagine. Null se si annulla.
Future<PageChoice?> askPageChoice(
  BuildContext context, {
  required int pageCount,
  required int currentPage,
  String title = 'Cosa vuoi mandare?',
  String confirmLabel = 'Continua',
}) {
  return showDialog<PageChoice>(
    context: context,
    builder: (context) => _PageChoiceDialog(
      pageCount: pageCount,
      currentPage: currentPage,
      title: title,
      confirmLabel: confirmLabel,
    ),
  );
}

class _PageChoiceDialog extends StatefulWidget {
  const _PageChoiceDialog({
    required this.pageCount,
    required this.currentPage,
    required this.title,
    required this.confirmLabel,
  });

  final int pageCount;
  final int currentPage;
  final String title;
  final String confirmLabel;

  @override
  State<_PageChoiceDialog> createState() => _PageChoiceDialogState();
}

class _PageChoiceDialogState extends State<_PageChoiceDialog> {
  int _mode = 0;
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _option(int mode, String label) => ListTile(
        key: ValueKey('page-choice-$mode'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(_mode == mode
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked),
        title: Text(label),
        onTap: () => setState(() {
          _mode = mode;
          _error = null;
        }),
      );

  void _confirm() {
    if (_mode == 0) {
      Navigator.pop<PageChoice>(context, (pages: null));
    } else if (_mode == 1) {
      Navigator.pop<PageChoice>(context, (pages: [widget.currentPage]));
    } else {
      final pages = parsePageList(_controller.text, widget.pageCount);
      if (pages == null) {
        setState(() => _error =
            'Pagine non valide: il documento ha ${widget.pageCount} pagine');
        return;
      }
      Navigator.pop<PageChoice>(context, (pages: pages));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _option(0, 'Tutto il documento (${widget.pageCount} pagine)'),
            _option(1, 'Solo questa pagina (${widget.currentPage + 1})'),
            _option(2, 'Alcune pagine'),
            if (_mode == 2)
              TextField(
                key: const ValueKey('page-choice-pages'),
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Pagine, per esempio 1,3,5-7',
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _confirm(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const ValueKey('page-choice-ok'),
          onPressed: _confirm,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
