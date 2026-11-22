import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'standard_sizes.dart';

// Misure personalizzate con nome: si creano dal menu ("Misure personalizzate"),
// si usano ovunque l'app chiede una misura per le foto e si eliminano quando non
// servono piu'. Restano sul dispositivo.

/// L'archivio delle misure personalizzate. Un'unica istanza serve tutte le
/// finestre ([instance]). Le misure vivono in [kCustomSizes], cosi'
/// [standardSizeById] le trova come quelle predefinite.
class CustomSizesStore extends ChangeNotifier {
  CustomSizesStore();

  static final CustomSizesStore instance = CustomSizesStore();

  static const _key = 'dart_pdf_editor_app.custom_sizes';

  Future<void>? _loading;

  /// Le misure salvate, nell'ordine in cui sono state create.
  List<StandardSize> get sizes => List.unmodifiable(kCustomSizes);

  /// Legge le misure salvate. Si puo' chiamare piu' volte: aspettano tutte la
  /// stessa lettura.
  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final stored = <StandardSize>[];
      for (final item in decoded) {
        final size = _decode(item);
        if (size != null && !kCustomSizes.any((s) => s.id == size.id)) {
          stored.add(size);
        }
      }
      // una misura creata mentre si leggeva resta in fondo all'elenco
      kCustomSizes.insertAll(0, stored);
      notifyListeners();
    } catch (error) {
      debugPrint('Custom sizes unreadable: $error');
    }
  }

  /// Crea una misura con [name] (se vuoto, il nome sono le misure stesse). Se
  /// esiste gia' una misura con lo stesso nome, la sostituisce. Le misure sono
  /// in millimetri. Restituisce la misura salvata.
  Future<StandardSize> add(String name, double widthMm, double heightMm) async {
    final clean = name.trim();
    final label = clean.isEmpty
        ? '${_fmt(widthMm)} x ${_fmt(heightMm)} mm'
        : (clean.length > kMaxCustomSizeName
            ? clean.substring(0, kMaxCustomSizeName)
            : clean);
    final index = kCustomSizes
        .indexWhere((s) => s.name.toLowerCase() == label.toLowerCase());
    final id = index >= 0
        ? kCustomSizes[index].id
        : 'mia_${DateTime.now().microsecondsSinceEpoch}';
    final size = StandardSize(
        id, label, StandardSizeGroup.other, widthMm, heightMm,
        note: 'misura personalizzata');
    if (index >= 0) {
      kCustomSizes[index] = size;
    } else {
      kCustomSizes.add(size);
    }
    notifyListeners();
    await _save();
    return size;
  }

  /// Elimina la misura con questo [id].
  Future<void> remove(String id) async {
    final before = kCustomSizes.length;
    kCustomSizes.removeWhere((s) => s.id == id);
    if (kCustomSizes.length == before) return;
    notifyListeners();
    await _save();
  }

  /// Solo per i test: svuota registro e lettura.
  @visibleForTesting
  void resetForTest() {
    kCustomSizes.clear();
    _loading = null;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode([
          for (final s in kCustomSizes)
            {'id': s.id, 'name': s.name, 'w': s.widthMm, 'h': s.heightMm},
        ]),
      );
    } catch (error) {
      debugPrint('Custom sizes not saved: $error');
    }
  }

  static StandardSize? _decode(dynamic item) {
    if (item is! Map) return null;
    final id = item['id'];
    final name = item['name'];
    final w = item['w'];
    final h = item['h'];
    if (id is! String || id.isEmpty || name is! String || w is! num || h is! num) {
      return null;
    }
    if (!isValidCustomSizeMm(w.toDouble(), h.toDouble())) return null;
    return StandardSize(
        id, name, StandardSizeGroup.other, w.toDouble(), h.toDouble(),
        note: 'misura personalizzata');
  }
}

/// Lunghezza massima del nome di una misura.
const int kMaxCustomSizeName = 60;

/// Se larghezza e altezza (in mm) sono ammesse: da 1 mm a 5 m.
bool isValidCustomSizeMm(double widthMm, double heightMm) =>
    widthMm.isFinite &&
    heightMm.isFinite &&
    widthMm >= 1 &&
    heightMm >= 1 &&
    widthMm <= 5000 &&
    heightMm <= 5000;

String _fmt(double v) {
  final s = v.toStringAsFixed(1);
  return (s.endsWith('.0') ? s.substring(0, s.length - 2) : s)
      .replaceAll('.', ',');
}

/// "Nome (90 × 50 mm)": come una misura si legge negli elenchi.
String customSizeLabel(StandardSize size) =>
    '${size.name} (${_fmt(size.widthMm)} × ${_fmt(size.heightMm)} mm)';

/// La finestra "Misure personalizzate": elenco con elimina e modulo per
/// crearne una nuova (nome, larghezza, altezza, cm o mm).
Future<void> showCustomSizesDialog(BuildContext context,
    {CustomSizesStore? store}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CustomSizesDialog(store ?? CustomSizesStore.instance),
  );
}

class _CustomSizesDialog extends StatefulWidget {
  const _CustomSizesDialog(this.store);

  final CustomSizesStore store;

  @override
  State<_CustomSizesDialog> createState() => _CustomSizesDialogState();
}

class _CustomSizesDialogState extends State<_CustomSizesDialog> {
  final _name = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  bool _cm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_changed);
    unawaited(widget.store.load());
  }

  @override
  void dispose() {
    widget.store.removeListener(_changed);
    _name.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    double? parse(String text) =>
        double.tryParse(text.trim().replaceAll(',', '.'));
    final w = parse(_width.text);
    final h = parse(_height.text);
    if (w == null || h == null || w <= 0 || h <= 0) {
      setState(() => _error = 'Scrivi larghezza e altezza.');
      return;
    }
    final factor = _cm ? 10.0 : 1.0;
    if (!isValidCustomSizeMm(w * factor, h * factor)) {
      setState(() => _error = 'Misura fuori dai limiti (da 1 mm a 5 m).');
      return;
    }
    await widget.store.add(_name.text, w * factor, h * factor);
    if (!mounted) return;
    setState(() {
      _error = null;
      _name.clear();
      _width.clear();
      _height.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sizes = widget.store.sizes;
    return AlertDialog(
      key: const ValueKey('custom-sizes-dialog'),
      title: const Text('Misure personalizzate'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sizes.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Nessuna misura salvata. Creane una qui sotto: '
                      'comparira\' tra le misure quando scegli la grandezza '
                      'di una foto.'),
                )
              else
                for (final size in sizes)
                  ListTile(
                    key: ValueKey('custom-size-${size.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(size.name),
                    subtitle:
                        Text('${_fmt(size.widthMm)} × ${_fmt(size.heightMm)} mm'),
                    trailing: IconButton(
                      key: ValueKey('custom-size-delete-${size.id}'),
                      tooltip: 'Elimina',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => unawaited(widget.store.remove(size.id)),
                    ),
                  ),
              const Divider(),
              Text('Nuova misura',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('custom-size-name'),
                controller: _name,
                maxLength: kMaxCustomSizeName,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  counterText: '',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('custom-size-width'),
                      controller: _width,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(labelText: 'Larghezza'),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('×'),
                  ),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('custom-size-height'),
                      controller: _height,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(labelText: 'Altezza'),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                key: const ValueKey('custom-size-unit'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, label: Text('cm')),
                  ButtonSegment(value: false, label: Text('mm')),
                ],
                selected: {_cm},
                onSelectionChanged: (s) => setState(() => _cm = s.first),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Chiudi'),
        ),
        FilledButton(
          key: const ValueKey('custom-size-save'),
          onPressed: _save,
          child: const Text('Salva misura'),
        ),
      ],
    );
  }
}
