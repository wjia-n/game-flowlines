import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Flow Lines: connect matching dots on a 7x7 grid without crossing.
/// Fill the whole board to win. 15 levels, 4-7 colors.

const List<List<List<int>>> flowLevels = [
  [[10, 28], [35, 38], [31, 26], [25, 12]],
  [[16, 21], [28, 24], [25, 6], [5, 40]],
  [[12, 25], [32, 24], [23, 22], [15, 8]],
  [[40, 33], [34, 10], [9, 28], [29, 24], [25, 22]],
  [[30, 11], [12, 0], [7, 28], [35, 40], [39, 18]],
  [[12, 13], [20, 33], [32, 31], [30, 36], [29, 22]],
  [[32, 5], [6, 45], [44, 0], [1, 18], [25, 36]],
  [[22, 7], [0, 5], [6, 19], [12, 25], [32, 48], [47, 36]],
  [[10, 5], [6, 19], [18, 40], [41, 42], [35, 0], [1, 36]],
  [[42, 29], [30, 41], [40, 27], [26, 12], [11, 24], [23, 0]],
  [[12, 11], [4, 39], [32, 48], [47, 36], [37, 14], [7, 8]],
  [[12, 20], [27, 31], [24, 2], [1, 35], [42, 48], [41, 37], [36, 8]],
  [[30, 8], [9, 7], [14, 36], [37, 17], [18, 6], [13, 39], [46, 40]],
  [[12, 26], [27, 47], [46, 42], [35, 7], [0, 10], [9, 37], [30, 32]],
  [[32, 40], [33, 25], [18, 24], [23, 45], [44, 28], [21, 1], [2, 12]],
];

// Vibrant pipe colors - each flow's identity, like player colors.
const List<Color> _pipeColors = [
  Color(0xFFFF5A5A),
  Color(0xFFFF9F2E),
  Color(0xFFFFD93D),
  Color(0xFF3ED598),
  Color(0xFF3EA6FF),
  Color(0xFFB15CFF),
  Color(0xFFFF6FB5),
];

const int _n = 7;
const int _cells = 49;

class FlowLinesScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const FlowLinesScreen({super.key, required this.players, required this.callbacks});

  @override
  State<FlowLinesScreen> createState() => _FlowLinesScreenState();
}

class _FlowLinesScreenState extends State<FlowLinesScreen> with SingleTickerProviderStateMixin {
  int _level = 0;
  late List<List<int>> _pairs;
  late List<List<int>> _paths; // ordered cells per pair
  late List<int> _owner; // cell -> pair index or -1
  int _drag = -1;
  bool _over = false;
  late AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _loadLevel(0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _loadLevel(int lv) {
    _level = lv;
    _pairs = flowLevels[lv].map((p) => [p[0], p[1]]).toList();
    _paths = List.generate(_pairs.length, (_) => <int>[]);
    _owner = List.filled(_cells, -1);
    for (int p = 0; p < _pairs.length; p++) {
      _owner[_pairs[p][0]] = p;
      _owner[_pairs[p][1]] = p;
    }
    _drag = -1;
    _over = false;
    setState(() {});
  }

  int get _filled => _owner.where((v) => v != -1).length;

  void _clearPath(int p) {
    for (final c in _paths[p]) {
      _owner[c] = -1;
    }
    _paths[p] = <int>[];
    _owner[_pairs[p][0]] = p;
    _owner[_pairs[p][1]] = p;
  }

  void _down(int cell) {
    if (_over) return;
    final o = _owner[cell];
    if (o == -1) return; // must start on a dot or existing pipe
    // find which pair: endpoint or path cell
    for (int p = 0; p < _pairs.length; p++) {
      if (cell == _pairs[p][0] || cell == _pairs[p][1]) {
        _clearPath(p);
        _paths[p] = [cell];
        _drag = p;
        Sfx.tap();
        setState(() {});
        return;
      }
      final idx = _paths[p].indexOf(cell);
      if (idx >= 0) {
        // trim back to here and continue
        for (int k = idx + 1; k < _paths[p].length; k++) {
          _owner[_paths[p][k]] = -1;
        }
        _paths[p] = _paths[p].sublist(0, idx + 1);
        _owner[_pairs[p][0]] = p;
        _owner[_pairs[p][1]] = p;
        _drag = p;
        Sfx.tap();
        setState(() {});
        return;
      }
    }
  }

  void _moveTo(int cell) {
    if (_drag == -1 || _over) return;
    final p = _drag;
    var tail = _paths[p].last;
    // walk step by step so fast drags don't skip cells
    int guard = 0;
    while (tail != cell && guard < 12) {
      guard++;
      final tr = tail ~/ _n, tc = tail % _n;
      final cr = cell ~/ _n, cc = cell % _n;
      int nr = tr, nc = tc;
      if (tr != cr) {
        nr = tr + (cr > tr ? 1 : -1);
      } else if (tc != cc) {
        nc = tc + (cc > tc ? 1 : -1);
      } else {
        break;
      }
      final next = nr * _n + nc;
      if (!_step(p, next)) break;
      tail = _paths[p].last;
    }
    setState(() {});
  }

  /// Advance pair p's tail into [next]. Returns false if blocked.
  bool _step(int p, int next) {
    final path = _paths[p];
    final tail = path.last;
    if (next == tail) return true;
    final idx = path.indexOf(next);
    if (idx >= 0) {
      // backtrack along own pipe
      for (int k = idx + 1; k < path.length; k++) {
        _owner[path[k]] = -1;
      }
      _paths[p] = path.sublist(0, idx + 1);
      _owner[_pairs[p][0]] = p;
      _owner[_pairs[p][1]] = p;
      return true;
    }
    final o = _owner[next];
    final otherEnd = next == _pairs[p][0] || next == _pairs[p][1];
    if (o == -1 || (otherEnd && o == p && next != path.first)) {
      // empty cell, or reaching the matching dot -> extend
      path.add(next);
      _owner[next] = p;
      Sfx.move();
      if (otherEnd && next != path.first) {
        // pipe complete!
        Sfx.win();
        _pop.forward(from: 0);
        _drag = -1;
        _checkWin();
      }
      return true;
    }
    return false; // blocked by another pipe
  }

  void _up() {
    _drag = -1;
    if (mounted) setState(() {});
  }

  void _checkWin() {
    if (_over) return;
    if (_owner.every((v) => v != -1)) {
      _over = true;
      Sfx.win();
      final last = _level == flowLevels.length - 1;
      widget.callbacks.finish(
        headline: last ? 'FLOW MASTER! 🌊' : 'Level ${_level + 1} flooded! 🌊',
        subline: last
            ? 'All 15 levels drowned in color. You absolute legend!'
            : 'Board 100% filled with zero crossings. Sweet pipes!',
      );
    }
  }

  bool _complete(int p) {
    final path = _paths[p];
    return path.length > 1 &&
        ((path.first == _pairs[p][0] && path.last == _pairs[p][1]) ||
            (path.first == _pairs[p][1] && path.last == _pairs[p][0]));
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final pct = _filled * 100 ~/ _cells;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Level ${_level + 1} of ${flowLevels.length}',
                        style: TextStyle(color: t.text, fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: _filled / _cells,
                        minHeight: 10,
                        backgroundColor: t.surface,
                        valueColor: AlwaysStoppedAnimation(t.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: pct == 100 ? LinearGradient(colors: [t.primary, t.secondary]) : null,
                  color: pct == 100 ? null : t.surface,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('🌊 $pct%',
                    style: TextStyle(
                        color: pct == 100 ? Colors.white : t.text, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: flowLevels.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final sel = i == _level;
              final done = i < _level;
              return GestureDetector(
                onTap: () {
                  Sfx.click();
                  _loadLevel(i);
                },
                child: Container(
                  width: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? t.primary : t.surface,
                    borderRadius: t.radius,
                    border: Border.all(color: sel ? t.primary : t.muted.withValues(alpha: 0.25)),
                  ),
                  child: Text(done ? '✅' : '${i + 1}',
                      style: TextStyle(
                          color: sel ? Colors.white : t.text, fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (_, cons) {
                final size = min(cons.maxWidth, cons.maxHeight) - 24;
                return SizedBox(
                  width: size,
                  height: size,
                  child: GestureDetector(
                    onPanStart: (d) => _down(_cellAt(d.localPosition, size)),
                    onPanUpdate: (d) => _moveTo(_cellAt(d.localPosition, size)),
                    onPanEnd: (_) => _up(),
                    child: CustomPaint(
                      painter: _FlowPainter(
                        pairs: _pairs,
                        paths: _paths,
                        complete: List.generate(_pairs.length, _complete),
                        colors: _pipeColors,
                        surface: t.surface,
                        dot: t.muted.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: WajihaButton(
                  label: 'Reset pipes',
                  emoji: '🔄',
                  primary: false,
                  onTap: () {
                    Sfx.click();
                    _loadLevel(_level);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: WajihaButton(
                  label: _level < flowLevels.length - 1 ? 'Next level' : 'Replay',
                  emoji: '⏭️',
                  onTap: () {
                    Sfx.click();
                    _loadLevel((_level + 1) % flowLevels.length);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _cellAt(Offset p, double size) {
    final cell = size / _n;
    final c = (p.dx / cell).floor().clamp(0, _n - 1);
    final r = (p.dy / cell).floor().clamp(0, _n - 1);
    return r * _n + c;
  }
}

class _FlowPainter extends CustomPainter {
  final List<List<int>> pairs;
  final List<List<int>> paths;
  final List<bool> complete;
  final List<Color> colors;
  final Color surface;
  final Color dot;
  _FlowPainter({
    required this.pairs,
    required this.paths,
    required this.complete,
    required this.colors,
    required this.surface,
    required this.dot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _n;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(20)),
      Paint()..color = surface,
    );
    // faint grid dots
    final dp = Paint()..color = dot;
    for (int r = 0; r < _n; r++) {
      for (int c = 0; c < _n; c++) {
        canvas.drawCircle(Offset(c * cell + cell / 2, r * cell + cell / 2), 2.2, dp);
      }
    }
    // pipes
    for (int p = 0; p < pairs.length; p++) {
      final path = paths[p];
      if (path.length < 2) continue;
      final color = colors[p % colors.length];
      final paint = Paint()
        ..color = complete[p] ? color : color.withValues(alpha: 0.55)
        ..strokeWidth = cell * 0.34
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final pts = path.map((s) => Offset((s % _n) * cell + cell / 2, (s ~/ _n) * cell + cell / 2)).toList();
      final mp = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        mp.lineTo(pts[i].dx, pts[i].dy);
      }
      // glow underlay for completed pipes
      if (complete[p]) {
        canvas.drawPath(
            mp,
            Paint()
              ..color = color.withValues(alpha: 0.25)
              ..strokeWidth = cell * 0.52
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke);
      }
      canvas.drawPath(mp, paint);
    }
    // endpoint dots
    for (int p = 0; p < pairs.length; p++) {
      final color = colors[p % colors.length];
      for (final s in pairs[p]) {
        final c = Offset((s % _n) * cell + cell / 2, (s ~/ _n) * cell + cell / 2);
        final rad = cell * (complete[p] ? 0.30 : 0.26);
        canvas.drawCircle(c, rad + 3, Paint()..color = Colors.white);
        canvas.drawCircle(c, rad, Paint()..color = color);
        canvas.drawCircle(c - Offset(rad * 0.3, rad * 0.3), rad * 0.28,
            Paint()..color = Colors.white.withValues(alpha: 0.55));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlowPainter old) => true;
}
