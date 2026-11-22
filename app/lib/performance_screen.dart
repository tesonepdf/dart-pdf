import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_perf.dart';

/// Apre la schermata Prestazioni (Impostazioni > Log e problemi).
Future<void> showPerformance(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => const PerformanceScreen(),
      ),
    );

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _ms(double v) => '${v.toStringAsFixed(1)} ms';

  Widget _card(PerfSeries series) {
    final st = series.stats;
    final bad = st.count > 0 && (st.p95 > series.limitMs || st.max > series.limitMs * 4);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(series.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (st.count == 0)
              const Text('Nessuna misura nell\'ultimo minuto')
            else ...[
              Text('${st.count} misure, ${st.slow} lente '
                  '(sopra ${_ms(series.limitMs)})'),
              Text('Media ${_ms(st.average)}  ·  95% sotto ${_ms(st.p95)}'),
              Text('Massimo ${_ms(st.max)}',
                  style: TextStyle(
                      fontWeight: bad ? FontWeight.bold : FontWeight.normal)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perf = AppPerf.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prestazioni'),
        actions: [
          TextButton(
            key: const ValueKey('perf-clear'),
            onPressed: () => setState(perf.clear),
            child: const Text('Azzera'),
          ),
          TextButton(
            key: const ValueKey('perf-copy'),
            onPressed: () => unawaited(
                Clipboard.setData(ClipboardData(text: perf.report()))),
            child: const Text('Copia'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text(
            'Le misure sono sempre attive e contano l\'ultimo minuto. '
            'Usa l\'app per qualche secondo (muovi il mouse sul PDF, scorri, '
            'apri il menu), poi apri questa schermata. "Azzera" riparte da '
            'capo, "Copia" mette tutto negli appunti.',
          ),
          const SizedBox(height: 8),
          for (final s in perf.all) _card(s),
        ],
      ),
    );
  }
}
