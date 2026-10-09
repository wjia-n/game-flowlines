import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/flowlines_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/craft.dart';
import '../theme/flowlines_themes.dart';

/// What the player is playing: classic level, tier endless, or daily.
class PlayTarget {
  final String kind; // 'classic' | 'tier' | 'daily'
  final FlowTier? tier;
  final int index; // 0-based classic/tier level
  final String label;
  const PlayTarget({
    required this.kind,
    required this.label,
    this.tier,
    this.index = 0,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'tier': tier?.index,
        'index': index,
        'label': label,
      };

  static PlayTarget? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final kind = j['kind'] as String?;
    if (kind != 'classic' && kind != 'tier' && kind != 'daily') return null;
    FlowTier? tier;
    final ti = j['tier'];
    if (ti is int && ti >= 0 && ti < FlowTier.values.length) {
      tier = FlowTier.values[ti];
    }
    return PlayTarget(
      kind: kind!,
      label: (j['label'] as String?) ?? 'Puzzle',
      tier: tier,
      index: (j['index'] as int?) ?? 0,
    );
  }
}

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.flowlines';

/// Game screen: the routed board, animated enamel pipes, hints, victory.
class GameScreen extends StatefulWidget {
  final FlowEngine engine;
  final FlowAudio audio;
  final FlowSettings settings;
  final PlayTarget target;
  final VoidCallback? onNext;

  const GameScreen({
    super.key,
    required this.engine,
    required this.audio,
    required this.settings,
    required this.target,
    this.onNext,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  DateTime _lastExtendSfx = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<int, DateTime> _completedAt = {};
  List<_Confetti> _confetti = [];
  bool _recorded = false;
  bool _reviewAsked = false;

  FlowSettings get _s => widget.settings;
  FlowThemeDef get _t =>
      FlowThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    widget.audio.startGameMusic();
    widget.engine.onEvent = _onEngineEvent;
    widget.engine.addListener(_onEngineChanged);
  }

  void _onEngineChanged() {
    if (!mounted) return;
    final e = widget.engine;
    if (e.phase == FlowPhase.complete && !_recorded) {
      _recorded = true;
      _onLevelComplete();
    }
    setState(() {});
  }

  Future<void> _onLevelComplete() async {
    widget.audio.levelWin();
    // Confetti burst for the celebration.
    final rand = Random();
    _confetti = List.generate(
      90,
      (_) => _Confetti(
        x: rand.nextDouble(),
        y: -0.1 - rand.nextDouble() * 0.3,
        vx: (rand.nextDouble() - 0.5) * 0.4,
        vy: 0.35 + rand.nextDouble() * 0.5,
        color: _t.pipeColors[rand.nextInt(_t.pipeColors.length)],
        size: 4 + rand.nextDouble() * 6,
        rot: rand.nextDouble() * pi * 2,
      ),
    );
    final t = widget.target;
    await _s.recordLevelComplete(
      pipes: widget.engine.puzzle.pairs.length,
      classicIndex: t.kind == 'classic' ? 'classic:${t.index}' : null,
      tier: t.kind == 'tier' ? t.tier : null,
      tierIndex: t.kind == 'tier' ? t.index : null,
      daily: t.kind == 'daily',
    );
    // Sensible review moment: after the 3rd finished level, once.
    if (!_reviewAsked && _s.levelsCompleted >= 3) {
      _reviewAsked = true;
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        _requestReview();
      });
    }
  }

  Future<void> _requestReview() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (_) {}
  }

  void _onEngineEvent(FlowEvent e) {
    final now = DateTime.now();
    switch (e) {
      case FlowEvent.grab:
        widget.audio.click();
      case FlowEvent.extend:
        // Throttle: a fast drag can add several cells per frame.
        if (now.difference(_lastExtendSfx).inMilliseconds > 70) {
          _lastExtendSfx = now;
          widget.audio.place();
        }
      case FlowEvent.backtrack:
        break;
      case FlowEvent.blocked:
        widget.audio.blocked();
      case FlowEvent.pipeComplete:
        widget.audio.pipeComplete();
        // Find which flow just completed for the pulse ring.
        for (int p = 0; p < widget.engine.puzzle.pairs.length; p++) {
          if (widget.engine.pairComplete(p) &&
              !_completedAt.containsKey(p)) {
            _completedAt[p] = now;
          }
        }
      case FlowEvent.invalid:
        widget.audio.invalid();
      case FlowEvent.undo:
        widget.audio.undo();
      case FlowEvent.reset:
        widget.audio.click();
        _completedAt.clear();
      case FlowEvent.hint:
        widget.audio.hint();
      case FlowEvent.levelComplete:
        break; // handled via phase listener
    }
  }

  @override
  void dispose() {
    widget.engine.onEvent = null;
    widget.engine.removeListener(_onEngineChanged);
    widget.engine.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _useHint() async {
    final ok = await _s.spendHint();
    if (!ok) {
      if (!mounted) return;
      widget.audio.invalid();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hints left today — PRO gets unlimited hints!',
              style: Craft.body(14, theme: _t)),
          backgroundColor: _t.bgDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!widget.engine.useHint() && mounted) {
      widget.audio.invalid();
    }
  }

  void _share() {
    widget.audio.click();
    SharePlus.instance.share(
      ShareParams(
        text:
            'I\'m flowing pipes in Flow Lines! Can you flood the board? $_storeUrl',
        subject: 'Flow Lines',
      ),
    );
  }

  Future<void> _pauseMenu() async {
    widget.audio.click();
    widget.engine.setPaused(true);
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [_t.bgMid, _t.bgDeep]),
            border: Border.all(color: _t.accent, width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: Craft.display(26, theme: _t)),
              const SizedBox(height: 16),
              CraftButton(
                label: 'Resume',
                width: 220,
                theme: _t,
                onTap: () {
                  widget.audio.click();
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 10),
              CraftButton(
                label: 'Restart level',
                width: 220,
                theme: _t,
                onTap: () {
                  widget.audio.click();
                  widget.engine.resetPuzzle();
                  _completedAt.clear();
                  _recorded = false;
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 10),
              CraftButton(
                label: 'How to play',
                width: 220,
                theme: _t,
                onTap: () {
                  widget.audio.click();
                  Navigator.of(context).pop();
                  _howToPlay();
                },
              ),
              const SizedBox(height: 10),
              CraftButton(
                label: 'Quit to menu',
                width: 220,
                theme: _t,
                onTap: () {
                  widget.audio.click();
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
    widget.engine.setPaused(false);
  }

  void _howToPlay() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [_t.bgMid, _t.bgDeep]),
            border: Border.all(color: _t.accent, width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How to play', style: Craft.display(24, theme: _t)),
              const SizedBox(height: 12),
              for (final line in [
                '• Drag from a dot to lay pipe.',
                '• Connect each matching pair of dots.',
                '• Pipes can\'t cross or overlap.',
                '• Drag back over your pipe to undo it.',
                '• Tap a pipe to redraw it.',
                '• Fill EVERY square to win!',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(line, style: Craft.body(15, theme: _t)),
                ),
              const SizedBox(height: 14),
              Center(
                child: CraftButton(
                  label: 'Got it!',
                  width: 180,
                  theme: _t,
                  onTap: () {
                    widget.audio.click();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final e = widget.engine;
    final pct = e.filledCount * 100 ~/ e.cellCount;
    return WorkshopBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top bar.
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        _IconBtn(
                          icon: Icons.arrow_back,
                          theme: t,
                          onTap: () {
                            widget.audio.click();
                            Navigator.of(context).pop();
                          },
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(widget.target.label,
                                  style: Craft.display(20, theme: t),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 2),
                              Text(e.banner,
                                  style: Craft.body(12,
                                      theme: t,
                                      color: t.text.withValues(alpha: 0.75)),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        _IconBtn(
                          icon: Icons.pause,
                          theme: t,
                          onTap: _pauseMenu,
                        ),
                      ],
                    ),
                  ),
                  // Progress strip.
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: e.filledCount / e.cellCount,
                              minHeight: 10,
                              backgroundColor: t.groove,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(t.accent),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: pct == 100 ? t.accent : t.groove,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                                color: t.accent.withValues(alpha: 0.6)),
                          ),
                          child: Text('$pct%',
                              style: Craft.label(14,
                                  theme: t,
                                  color: pct == 100 ? t.bgDeep : t.text)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: t.groove,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                                color: t.accent.withValues(alpha: 0.6)),
                          ),
                          child: Text('✎ ${e.strokes}',
                              style: Craft.label(14, theme: t)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Board.
                  Expanded(
                    child: Center(
                      child: LayoutBuilder(
                        builder: (_, cons) {
                          final size =
                              min(cons.maxWidth, cons.maxHeight) - 20;
                          return SizedBox(
                            width: size,
                            height: size,
                            child: GestureDetector(
                              onPanStart: (d) =>
                                  e.beginDrag(_cellAt(d.localPosition, size)),
                              onPanUpdate: (d) =>
                                  e.dragTo(_cellAt(d.localPosition, size)),
                              onPanEnd: (_) => e.endDrag(),
                              onPanCancel: () => e.endDrag(),
                              child: AnimatedBuilder(
                                animation: _pulse,
                                builder: (_, _) => CustomPaint(
                                  painter: _FlowBoardPainter(
                                    engine: e,
                                    theme: t,
                                    pipeStyle: _s.pipeStyle,
                                    pulse: _pulse.value,
                                    completedAt: _completedAt,
                                    confetti: _confetti,
                                    celebrating:
                                        e.phase == FlowPhase.celebrating ||
                                            e.phase == FlowPhase.complete,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Toolbar.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ToolBtn(
                          icon: Icons.undo,
                          label: 'Undo',
                          theme: t,
                          onTap: () => e.undo(),
                        ),
                        _ToolBtn(
                          icon: Icons.lightbulb_outline,
                          label: _s.hintsUnlimited
                              ? 'Hint'
                              : 'Hint ${_s.hintsRemaining}',
                          theme: t,
                          onTap: _useHint,
                        ),
                        _ToolBtn(
                          icon: Icons.refresh,
                          label: 'Reset',
                          theme: t,
                          onTap: () {
                            widget.audio.click();
                            e.resetPuzzle();
                            _completedAt.clear();
                            _recorded = false;
                          },
                        ),
                        _ToolBtn(
                          icon: Icons.share,
                          label: 'Share',
                          theme: t,
                          onTap: _share,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Victory overlay.
              if (e.phase == FlowPhase.complete)
                _VictoryOverlay(
                  theme: t,
                  audio: widget.audio,
                  stars: e.strokes <= e.puzzle.pairs.length
                      ? 3
                      : (e.strokes <= e.puzzle.pairs.length * 2 ? 2 : 1),
                  strokes: e.strokes,
                  hasNext: widget.onNext != null,
                  onNext: widget.onNext,
                  onReplay: () {
                    widget.audio.click();
                    e.resetPuzzle();
                    _completedAt.clear();
                    _confetti = [];
                    _recorded = false;
                  },
                  onMenu: () {
                    widget.audio.click();
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _cellAt(Offset p, double size) {
    final n = widget.engine.size;
    final cell = size / n;
    final c = (p.dx / cell).floor().clamp(0, n - 1);
    final r = (p.dy / cell).floor().clamp(0, n - 1);
    return r * n + c;
  }
}

class _Confetti {
  double x, y, vx, vy, size, rot;
  Color color;
  _Confetti({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rot,
  });
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final FlowThemeDef theme;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.bgMid, theme.bgDeep],
          ),
          border: Border.all(color: theme.accent, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 3),
                blurRadius: 5),
          ],
        ),
        child: Icon(icon, color: theme.accentLight, size: 24),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final FlowThemeDef theme;
  final VoidCallback onTap;
  const _ToolBtn(
      {required this.icon,
      required this.label,
      required this.theme,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [theme.bgMid, theme.bgDeep],
              ),
              border: Border.all(color: theme.accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    offset: const Offset(0, 4),
                    blurRadius: 6),
                BoxShadow(
                    color: theme.accentLight.withValues(alpha: 0.25),
                    offset: const Offset(0, -2),
                    blurRadius: 2),
              ],
            ),
            child: Icon(icon, color: theme.accentLight, size: 26),
          ),
          const SizedBox(height: 4),
          Text(label, style: Craft.label(12, theme: theme)),
        ],
      ),
    );
  }
}

class _VictoryOverlay extends StatelessWidget {
  final FlowThemeDef theme;
  final FlowAudio audio;
  final int stars;
  final int strokes;
  final bool hasNext;
  final VoidCallback? onNext;
  final VoidCallback onReplay;
  final VoidCallback onMenu;
  const _VictoryOverlay({
    required this.theme,
    required this.audio,
    required this.stars,
    required this.strokes,
    required this.hasNext,
    required this.onNext,
    required this.onReplay,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 36),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.bgMid, theme.bgDeep],
            ),
            border: Border.all(color: theme.accent, width: 3),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  offset: const Offset(0, 10),
                  blurRadius: 24),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Flooded!', style: Craft.display(34, theme: theme)),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < stars ? Icons.star : Icons.star_border,
                        color: i < stars
                            ? theme.accentLight
                            : theme.text.withValues(alpha: 0.3),
                        size: 40,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text('$strokes strokes',
                  style: Craft.body(15,
                      theme: theme,
                      color: theme.text.withValues(alpha: 0.8))),
              const SizedBox(height: 18),
              if (hasNext)
                CraftButton(
                    label: 'Next level →', width: 230, theme: theme, onTap: () {
                  audio.click();
                  onNext?.call();
                }),
              if (hasNext) const SizedBox(height: 10),
              CraftButton(
                  label: 'Replay', width: 230, theme: theme, onTap: onReplay),
              const SizedBox(height: 10),
              CraftButton(
                  label: 'Menu', width: 230, theme: theme, onTap: onMenu),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pseudo-3D board painter: routed wooden board, enamel pipes with real
// depth (drop shadow, glossy highlight), glassy endpoint dots.
// ---------------------------------------------------------------------------
class _FlowBoardPainter extends CustomPainter {
  final FlowEngine engine;
  final FlowThemeDef theme;
  final int pipeStyle;
  final double pulse; // 0..1 repeating
  final Map<int, DateTime> completedAt;
  final List<_Confetti> confetti;
  final bool celebrating;

  _FlowBoardPainter({
    required this.engine,
    required this.theme,
    required this.pipeStyle,
    required this.pulse,
    required this.completedAt,
    required this.confetti,
    required this.celebrating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = engine.size;
    final t = theme;

    // Routed board slab with bevel.
    final boardRect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(18));
    canvas.drawRRect(
        boardRect, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, -3, size.width, size.height),
          const Radius.circular(18)),
      Paint()..color = t.boardLight.withValues(alpha: 0.5),
    );
    canvas.drawRRect(boardRect, Paint()..color = t.boardDark);
    // Inner groove frame.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
          const Radius.circular(12)),
      Paint()
        ..color = t.groove
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Checker cells.
    final pad = 12.0;
    final inner = size.width - pad * 2;
    final ics = inner / n;
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final rect = Rect.fromLTWH(pad + c * ics, pad + r * ics, ics, ics);
        canvas.drawRect(
            rect, Paint()..color = (r + c) % 2 == 0 ? t.boardLight : t.boardDark);
      }
    }
    // Routed grid lines.
    final grid = Paint()
      ..color = t.groove.withValues(alpha: 0.55)
      ..strokeWidth = 1.5;
    for (int i = 0; i <= n; i++) {
      final o = pad + i * ics;
      canvas.drawLine(Offset(o, pad), Offset(o, pad + inner), grid);
      canvas.drawLine(Offset(pad, o), Offset(pad + inner, o), grid);
    }

    Offset cc(int cell) => Offset(
        pad + (cell % n) * ics + ics / 2, pad + (cell ~/ n) * ics + ics / 2);

    // Hint ghost markers (progressive reveal — never instant).
    if (engine.hintCells.isNotEmpty && engine.hintIndex > 0) {
      final shown = engine.hintCells.take(engine.hintIndex);
      for (final cell in shown) {
        final p = cc(cell);
        final a = 0.35 + 0.3 * sin(pulse * 2 * pi);
        canvas.drawCircle(
            p,
            ics * 0.3,
            Paint()
              ..color = t.accentLight.withValues(alpha: a.clamp(0.15, 0.7))
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
        canvas.drawCircle(
            p, ics * 0.12, Paint()..color = t.accentLight.withValues(alpha: 0.8));
      }
    }

    // Pipes.
    for (int p = 0; p < engine.puzzle.pairs.length; p++) {
      final path = engine.paths[p];
      if (path.length < 2) continue;
      final color = t.pipeColors[p % t.pipeColors.length];
      final complete = engine.pairComplete(p);
      _paintPipe(canvas, path.map(cc).toList(), color, ics, complete);
      // Completion pulse ring.
      final doneAt = completedAt[p];
      if (doneAt != null) {
        final age =
            DateTime.now().difference(doneAt).inMilliseconds / 900.0;
        if (age < 1) {
          final last = cc(path.last);
          canvas.drawCircle(
              last,
              ics * (0.3 + age * 0.9),
              Paint()
                ..color = color.withValues(alpha: (1 - age) * 0.7)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4 * (1 - age) + 1);
        }
      }
    }

    // Endpoint dots: glossy spheres.
    for (int p = 0; p < engine.puzzle.pairs.length; p++) {
      final color = t.pipeColors[p % t.pipeColors.length];
      final complete = engine.pairComplete(p);
      for (final s in engine.puzzle.pairs[p]) {
        _paintDot(canvas, cc(s), color, ics * (complete ? 0.30 : 0.27));
      }
    }

    // Active drag tail marker.
    if (engine.dragPair != -1 && engine.paths[engine.dragPair].isNotEmpty) {
      final tail = cc(engine.paths[engine.dragPair].last);
      final color =
          t.pipeColors[engine.dragPair % t.pipeColors.length];
      canvas.drawCircle(
          tail,
          ics * (0.16 + 0.04 * sin(pulse * 2 * pi)),
          Paint()..color = Colors.white.withValues(alpha: 0.85));
      canvas.drawCircle(
          tail,
          ics * 0.10,
          Paint()..color = color);
    }

    // Celebration confetti.
    if (celebrating && confetti.isNotEmpty) {
      for (final c in confetti) {
        c.y += c.vy * 0.008;
        c.x += c.vx * 0.008;
        c.rot += 0.05;
        if (c.y > 1.15) {
          c.y = -0.1;
          c.x = Random().nextDouble();
        }
        canvas.save();
        canvas.translate(c.x * size.width, c.y * size.height);
        canvas.rotate(c.rot);
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero, width: c.size, height: c.size * 0.6),
            Paint()..color = c.color);
        canvas.restore();
      }
    }
  }

  void _paintPipe(
      Canvas canvas, List<Offset> pts, Color color, double cs, bool complete) {
    final w = cs * (pipeStyle == 6 ? 0.44 : 0.34);
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    // Drop shadow → physical depth.
    canvas.save();
    canvas.translate(0, cs * 0.05);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.4)
          ..strokeWidth = w * 1.12
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke);
    canvas.restore();

    // Main body.
    final bodyPaint = Paint()
      ..color = complete ? color : color.withValues(alpha: 0.82)
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (pipeStyle == 2) {
      // Copper: metallic sheen via darker base + bright top.
      canvas.drawPath(
          path,
          Paint()
            ..color = _shade(color, 0.55)
            ..strokeWidth = w
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke);
    } else if (pipeStyle == 9) {
      // Steel cable: dark edges, bright core.
      canvas.drawPath(
          path,
          Paint()
            ..color = _shade(color, 0.45)
            ..strokeWidth = w
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke);
    } else {
      canvas.drawPath(path, bodyPaint);
    }

    // Style-specific dressing.
    switch (pipeStyle) {
      case 0: // Glass tube: bright core.
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.38)
              ..strokeWidth = w * 0.45
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke);
      case 2: // Copper sheen line.
        canvas.save();
        canvas.translate(-w * 0.14, -w * 0.14);
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.4)
              ..strokeWidth = w * 0.28
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke);
        canvas.restore();
      case 3: // Wooden dowel: darker edges.
        canvas.drawPath(
            path,
            Paint()
              ..color = _shade(color, 0.6)
              ..strokeWidth = w
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke
              ..maskFilter = null);
      case 4: // Braided rope: twisted dash overlay.
        _dashedPath(canvas, path, _shade(color, 0.55), w * 0.5, cs * 0.16);
      case 5: // Marble vein: soft wide body + vein line.
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.22)
              ..strokeWidth = w * 0.5
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke);
      case 7: // Ceramic glaze: strong gloss.
        canvas.save();
        canvas.translate(-w * 0.16, -w * 0.16);
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.5)
              ..strokeWidth = w * 0.3
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke);
        canvas.restore();
      case 8: // Bamboo: segmented.
        _dashedPath(canvas, path, _shade(color, 0.6), w, cs * 0.3,
            gap: cs * 0.12);
      case 9: // Steel cable core.
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.5)
              ..strokeWidth = w * 0.3
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke);
      default: // Enamel / ribbon: top gloss line.
        canvas.save();
        canvas.translate(-w * 0.13, -w * 0.13);
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.3)
              ..strokeWidth = w * 0.3
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke);
        canvas.restore();
    }
  }

  void _dashedPath(Canvas canvas, Path path, Color color, double width,
      double dash, {double gap = 0.0}) {
    final metrics = path.computeMetrics();
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final m in metrics) {
      var d = 0.0;
      while (d < m.length) {
        final seg = m.extractPath(d, min(d + dash, m.length));
        canvas.drawPath(seg, paint);
        d += dash + (gap > 0 ? gap : dash * 0.6);
      }
    }
  }

  void _paintDot(Canvas canvas, Offset c, Color color, double rad) {
    // Rim.
    canvas.drawCircle(c, rad + 2.5, Paint()..color = Colors.black54);
    // Body with radial gloss.
    canvas.drawCircle(
        c,
        rad,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 1.1,
            colors: [_tint(color, 0.45), color, _shade(color, 0.6)],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: rad)));
    // Specular dot.
    canvas.drawCircle(
        c + Offset(-rad * 0.32, -rad * 0.36),
        rad * 0.26,
        Paint()..color = Colors.white.withValues(alpha: 0.75));
  }

  Color _shade(Color c, double f) => Color.fromARGB(
      (c.a * 255.0).round().clamp(0, 255),
      (c.r * 255.0 * f).round().clamp(0, 255),
      (c.g * 255.0 * f).round().clamp(0, 255),
      (c.b * 255.0 * f).round().clamp(0, 255));

  Color _tint(Color c, double f) => Color.fromARGB(
      (c.a * 255.0).round().clamp(0, 255),
      (c.r * 255.0 + (255 - c.r * 255.0) * f).round().clamp(0, 255),
      (c.g * 255.0 + (255 - c.g * 255.0) * f).round().clamp(0, 255),
      (c.b * 255.0 + (255 - c.b * 255.0) * f).round().clamp(0, 255));

  @override
  bool shouldRepaint(covariant _FlowBoardPainter old) => true;
}
