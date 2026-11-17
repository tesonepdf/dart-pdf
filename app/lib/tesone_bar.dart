import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Una scelta del piccolo menu di un pulsante col triangolino.
class TesoneChoice {
  const TesoneChoice({
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

/// Un pulsante della barra strumenti in basso, in stile tesone: icona e nome.
/// Se ha [choices], in basso a destra ha un triangolino che apre il menu con
/// gli altri strumenti del gruppo (anche con una pressione lunga).
class TesoneBarItem {
  const TesoneBarItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.run,
    this.choices = const [],
    this.selected = false,
    this.enabled = true,
  });

  final String id;
  final IconData icon;
  final String label;
  final VoidCallback run;
  final List<TesoneChoice> choices;
  final bool selected;
  final bool enabled;
}

/// La barra strumenti del documento, in stile tesone: sei pulsanti con icona
/// e nome, sotto la pagina.
class TesoneToolbar extends StatelessWidget {
  const TesoneToolbar({super.key, required this.items});

  final List<TesoneBarItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey('tesone-toolbar'),
      color: theme.colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              for (final item in items)
                Expanded(child: _TesoneBarButton(item: item)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TesoneBarButton extends StatelessWidget {
  const _TesoneBarButton({required this.item});

  final TesoneBarItem item;

  Future<void> _openMenu(BuildContext context) async {
    final box = context.findRenderObject();
    if (box is! RenderBox || item.choices.isEmpty) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.sizeOf(context);
    final above = topLeft.dy - 8;
    final picked = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        above - 48.0 * item.choices.length,
        screen.width - topLeft.dx - box.size.width,
        screen.height - above,
      ),
      items: [
        for (final (i, c) in item.choices.indexed)
          PopupMenuItem<int>(
            key: ValueKey('tesone-choice-${c.id}'),
            value: i,
            child: Row(
              children: [
                Icon(c.icon, size: 22),
                const SizedBox(width: 12),
                Flexible(child: Text(c.label)),
              ],
            ),
          ),
      ],
    );
    if (picked != null) item.choices[picked].run();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);
    return InkWell(
      key: ValueKey('tesone-bar-${item.id}'),
      onTap: item.enabled ? item.run : null,
      onLongPress:
          item.choices.isEmpty ? null : () => unawaited(_openMenu(context)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 36,
              decoration: BoxDecoration(
                color: item.selected
                    ? theme.colorScheme.secondaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(item.icon, size: 26, color: color),
                  if (item.choices.isNotEmpty)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        key: ValueKey('tesone-bar-${item.id}-menu'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => unawaited(_openMenu(context)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 3, 3),
                          child: CustomPaint(
                            size: const Size(7, 7),
                            painter: _TrianglePainter(color),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

/// Uno strumento della finestra "Altri strumenti".
class MoreToolTile {
  const MoreToolTile({
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

/// Un blocco di strumenti, con un titolo se non e' il primo.
class MoreToolsSection {
  const MoreToolsSection({this.title, required this.tiles});

  final String? title;
  final List<MoreToolTile> tiles;
}

/// La finestra "Altri strumenti", in stile tesone: una griglia a 4 colonne di
/// riquadri colorati con icona e nome. Toccarne uno la chiude e lo fa partire.
Future<void> showMoreToolsSheet(
  BuildContext context, {
  required String title,
  required List<MoreToolsSection> sections,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => _MoreToolsSheet(title: title, sections: sections),
    );

class _MoreToolsSheet extends StatelessWidget {
  const _MoreToolsSheet({required this.title, required this.sections});

  final String title;
  final List<MoreToolsSection> sections;

  static const _palette = <Color>[
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.cyan,
    Colors.green,
    Colors.blue,
    Colors.red,
    Colors.orange,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var n = 0;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: SingleChildScrollView(
          key: const ValueKey('more-tools-sheet'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final section in sections) ...[
                if (section.title != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(section.title!,
                        style: theme.textTheme.titleSmall),
                  ),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.74,
                  children: [
                    for (final t in section.tiles)
                      Builder(builder: (context) {
                        final base = _palette[n++ % _palette.length];
                        return InkWell(
                          key: ValueKey('more-tool-${t.id}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).pop();
                            t.run();
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: base.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(t.icon, size: 30, color: base),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                t.label,
                                maxLines: 3,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium,
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
