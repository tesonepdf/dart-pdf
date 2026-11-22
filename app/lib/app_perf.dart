import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/scheduler.dart';

/// Una serie di misure in millisecondi: tiene solo l'ultimo minuto.
class PerfSeries {
  PerfSeries(this.name, this.limitMs);

  final String name;

  /// Sopra questo valore la misura conta come "lenta".
  final double limitMs;

  final List<({int at, double ms})> _samples = [];

  static const _window = Duration(seconds: 60);
  static const _maxSamples = 6000;

  void add(double ms) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _samples.add((at: now, ms: ms));
    if (_samples.length > _maxSamples) {
      _samples.removeRange(0, _samples.length - _maxSamples);
    }
    final cut = now - _window.inMilliseconds;
    var drop = 0;
    while (drop < _samples.length && _samples[drop].at < cut) {
      drop++;
    }
    if (drop > 0) _samples.removeRange(0, drop);
  }

  void clear() => _samples.clear();

  PerfStats get stats {
    final cut = DateTime.now().millisecondsSinceEpoch - _window.inMilliseconds;
    final values = [
      for (final s in _samples)
        if (s.at >= cut) s.ms,
    ];
    if (values.isEmpty) return const PerfStats(0, 0, 0, 0, 0);
    final sorted = [...values]..sort();
    var sum = 0.0;
    var slow = 0;
    for (final v in values) {
      sum += v;
      if (v > limitMs) slow++;
    }
    final p95 = sorted[((sorted.length - 1) * 0.95).round()];
    return PerfStats(values.length, sum / values.length, p95, sorted.last, slow);
  }
}

class PerfStats {
  const PerfStats(this.count, this.average, this.p95, this.max, this.slow);

  final int count;
  final double average;
  final double p95;
  final double max;
  final int slow;
}

/// Misure delle prestazioni dell'app, sempre attive e leggere: i frame, il
/// ritardo del thread che disegna, il controllo del mouse e l'apertura del
/// menu. Si guardano in Impostazioni > Prestazioni.
class AppPerf {
  AppPerf._();

  static final AppPerf instance = AppPerf._();

  final frameBuild = PerfSeries('Preparazione del frame (build)', 16.7);
  final frameRaster = PerfSeries('Disegno del frame (raster)', 16.7);
  final frameTotal = PerfSeries('Frame completo', 16.7);
  final uiLag = PerfSeries('Ritardo del thread principale', 20);
  final mouse = PerfSeries('Controllo del mouse sulla pagina', 8);
  final menu = PerfSeries('Apertura del menu', 50);

  List<PerfSeries> get all =>
      [frameTotal, frameBuild, frameRaster, uiLag, mouse, menu];

  bool _installed = false;
  Timer? _lagTimer;
  final Stopwatch _lagClock = Stopwatch();

  static const _lagTick = Duration(milliseconds: 16);

  void install() {
    if (_installed) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
      for (final t in timings) {
        frameBuild.add(t.buildDuration.inMicroseconds / 1000.0);
        frameRaster.add(t.rasterDuration.inMicroseconds / 1000.0);
        frameTotal.add(t.totalSpan.inMicroseconds / 1000.0);
      }
    });
    // Se il thread principale e' occupato, il timer scatta in ritardo: il
    // ritardo e' esattamente quanto l'app e' rimasta ferma.
    _lagClock.start();
    _lagTimer = Timer.periodic(_lagTick, (_) {
      final late =
          _lagClock.elapsedMicroseconds / 1000.0 - _lagTick.inMilliseconds;
      _lagClock
        ..reset()
        ..start();
      if (late > 1) uiLag.add(late);
    });
  }

  void clear() {
    for (final s in all) {
      s.clear();
    }
  }

  String report() {
    String f(double v) => v.toStringAsFixed(1);
    final lines = <String>['Prestazioni, ultimo minuto'];
    for (final s in all) {
      final st = s.stats;
      lines.add(st.count == 0
          ? '${s.name}: nessuna misura'
          : '${s.name}: ${st.count} misure, media ${f(st.average)} ms, '
              '95% sotto ${f(st.p95)} ms, massimo ${f(st.max)} ms, '
              '${st.slow} sopra ${f(s.limitMs)} ms');
    }
    return lines.join('\n');
  }
}
