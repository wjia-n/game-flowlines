import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Classic handcrafted pack: 15 levels on a 7x7 board, 4-7 flows each.
// ---------------------------------------------------------------------------
const List<List<List<int>>> classicLevels = [
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

// ---------------------------------------------------------------------------
// Difficulty tiers: board size + flow count per tier.
// ---------------------------------------------------------------------------
enum FlowTier { easy, medium, hard }

extension FlowTierConfig on FlowTier {
  int get size => switch (this) { FlowTier.easy => 5, FlowTier.medium => 7, FlowTier.hard => 9 };
  int get colors => switch (this) { FlowTier.easy => 4, FlowTier.medium => 6, FlowTier.hard => 8 };
  String get name => switch (this) { FlowTier.easy => 'Easy', FlowTier.medium => 'Medium', FlowTier.hard => 'Hard' };
  String get detail => switch (this) {
        FlowTier.easy => '5×5 board · 4 flows',
        FlowTier.medium => '7×7 board · 6 flows',
        FlowTier.hard => '9×9 board · 8 flows',
      };
  /// Hard tier is a PRO feature.
  bool get isPro => this == FlowTier.hard;
}

// ---------------------------------------------------------------------------
// Deterministic puzzle generator: carves the whole board into random
// self-avoiding walks, then merges walks until the target flow count is
// reached. The tiling itself is a valid solution, so every generated puzzle
// is guaranteed solvable. Deterministic per seed → daily + endless tiers.
// ---------------------------------------------------------------------------
class FlowPuzzle {
  final int size;
  final List<List<int>> pairs; // [a, b] endpoint cells per flow
  final List<List<int>>? solution; // ordered cells per flow (null = unknown)
  final String label;

  const FlowPuzzle({
    required this.size,
    required this.pairs,
    required this.label,
    this.solution,
  });
}

class FlowGenerator {
  static FlowPuzzle generate({
    required int size,
    required int colors,
    required int seed,
    required String label,
  }) {
    final rand = Random(seed);
    final n = size * size;
    final filled = List<bool>.filled(n, false);
    final walks = <List<int>>[];

    int filledCount = 0;
    int guard = 0;
    while (filledCount < n && guard < n * 6) {
      guard++;
      final empties = <int>[
        for (int i = 0; i < n; i++)
          if (!filled[i]) i
      ];
      if (empties.isEmpty) break;
      final walk = <int>[empties[rand.nextInt(empties.length)]];
      filled[walk.first] = true;
      filledCount++;
      while (true) {
        final cur = walk.last;
        final r = cur ~/ size, c = cur % size;
        final nbs = <int>[];
        if (r > 0 && !filled[cur - size]) nbs.add(cur - size);
        if (r < size - 1 && !filled[cur + size]) nbs.add(cur + size);
        if (c > 0 && !filled[cur - 1]) nbs.add(cur - 1);
        if (c < size - 1 && !filled[cur + 1]) nbs.add(cur + 1);
        if (nbs.isEmpty) break;
        final nxt = nbs[rand.nextInt(nbs.length)];
        walk.add(nxt);
        filled[nxt] = true;
        filledCount++;
      }
      walks.add(walk);
    }

    // Merge walks until we reach the target flow count.
    bool merged = true;
    while (walks.length > colors && merged) {
      merged = false;
      outer:
      for (int i = 0; i < walks.length && !merged; i++) {
        for (int j = i + 1; j < walks.length && !merged; j++) {
          final m = _tryMerge(walks[i], walks[j], size);
          if (m != null) {
            walks[i] = m;
            walks.removeAt(j);
            merged = true;
            break outer;
          }
        }
      }
    }

    return FlowPuzzle(
      size: size,
      pairs: [for (final w in walks) [w.first, w.last]],
      solution: walks,
      label: label,
    );
  }

  static bool _adjacent(int a, int b, int size) {
    final ar = a ~/ size, ac = a % size;
    final br = b ~/ size, bc = b % size;
    return (ar - br).abs() + (ac - bc).abs() == 1;
  }

  /// Concatenate two walks when an endpoint of one touches an endpoint of
  /// the other. Returns null when they cannot be joined.
  static List<int>? _tryMerge(List<int> a, List<int> b, int size) {
    final a0 = a.first, a1 = a.last, b0 = b.first, b1 = b.last;
    if (_adjacent(a1, b0, size)) return [...a, ...b];
    if (_adjacent(a1, b1, size)) return [...a, ...b.reversed];
    if (_adjacent(a0, b0, size)) return [...a.reversed, ...b];
    if (_adjacent(a0, b1, size)) return [...b, ...a];
    return null;
  }

  /// Seed for a tier endless level (1-based index).
  static int tierSeed(FlowTier tier, int index) =>
      tier.index * 100003 + index * 104729 + 7;

  /// Seed for the daily challenge (stable per calendar day).
  static int dailySeed(DateTime day) =>
      day.year * 10000 + day.month * 100 + day.day;

  static String dailyKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Engine: owns ALL puzzle state + phases. The UI only renders.
// ---------------------------------------------------------------------------
enum FlowPhase { idle, hintRevealing, celebrating, complete }

enum FlowEvent {
  grab,
  extend,
  backtrack,
  blocked,
  pipeComplete,
  invalid,
  undo,
  reset,
  hint,
  levelComplete,
}

class FlowEngine extends ChangeNotifier {
  final FlowPuzzle puzzle;
  int get size => puzzle.size;
  int get cellCount => size * size;

  late List<List<int>> paths; // ordered cells per flow
  late List<int> owner; // cell -> flow index or -1
  final List<List<List<int>>> _undoStack = [];

  FlowPhase phase = FlowPhase.idle;
  int dragPair = -1; // flow currently being drawn, -1 = none
  int strokes = 0; // completed drag gestures that changed the board
  bool _dragChanged = false;
  String banner = '';

  // Hint reveal animation state (engine-owned, never instant).
  List<int> hintCells = [];
  int hintIndex = 0;
  int hintPair = -1;
  Timer? _hintTimer;

  Timer? _timer; // single phase-transition timer (celebration)
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;
  bool paused = false;

  /// UI hook for sounds / haptics. Set by the screen.
  void Function(FlowEvent event)? onEvent;

  FlowEngine({required this.puzzle}) {
    _resetBoard();
    banner = 'Connect every pair — fill the whole board!';
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) => _recover());
  }

  void _resetBoard() {
    paths = List.generate(puzzle.pairs.length, (_) => <int>[]);
    owner = List.filled(cellCount, -1);
    for (int p = 0; p < puzzle.pairs.length; p++) {
      owner[puzzle.pairs[p][0]] = p;
      owner[puzzle.pairs[p][1]] = p;
    }
    _undoStack.clear();
    dragPair = -1;
    strokes = 0;
    _dragChanged = false;
    hintCells = [];
    hintIndex = 0;
    hintPair = -1;
  }

  int get filledCount => owner.where((v) => v != -1).length;
  bool get isComplete => phase == FlowPhase.complete;

  bool pairComplete(int p) {
    final path = paths[p];
    if (path.length < 2) return false;
    final a = puzzle.pairs[p][0], b = puzzle.pairs[p][1];
    return (path.first == a && path.last == b) ||
        (path.first == b && path.last == a);
  }

  bool get allPairsComplete {
    for (int p = 0; p < puzzle.pairs.length; p++) {
      if (!pairComplete(p)) return false;
    }
    return true;
  }

  bool get boardFull => owner.every((v) => v != -1);

  /// Stars: perfect play connects each flow in a single stroke.
  int get stars {
    final par = puzzle.pairs.length;
    if (strokes <= par) return 3;
    if (strokes <= par * 2) return 2;
    return 1;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _hintTimer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Pause: freeze timers. Resume re-arms the current phase via watchdog.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
      _hintTimer?.cancel();
      _hintTimer = null;
    } else {
      _recover();
    }
    notifyListeners();
  }

  /// Watchdog: recover any phase found without a live timer.
  /// Stuck states are impossible by construction.
  void _recover() {
    if (_disposed || paused) return;
    if (phase == FlowPhase.hintRevealing) {
      if (_hintTimer == null && hintIndex < hintCells.length) {
        _startHintTimer();
      } else if (hintIndex >= hintCells.length) {
        phase = FlowPhase.idle;
        notifyListeners();
      }
    } else if (phase == FlowPhase.celebrating && _timer == null) {
      _finishLevel();
    }
  }

  void _pushUndo() {
    _undoStack.add([for (final p in paths) List<int>.of(p)]);
    if (_undoStack.length > 200) _undoStack.removeAt(0);
  }

  void _rebuildOwner() {
    owner = List.filled(cellCount, -1);
    for (int p = 0; p < puzzle.pairs.length; p++) {
      owner[puzzle.pairs[p][0]] = p;
      owner[puzzle.pairs[p][1]] = p;
      for (final c in paths[p]) {
        owner[c] = p;
      }
    }
  }

  // ------------------------------------------------------------ interaction
  /// Pointer down on [cell]. Returns the grabbed flow or -1.
  int beginDrag(int cell) {
    if (phase == FlowPhase.celebrating || phase == FlowPhase.complete) {
      return -1;
    }
    if (cell < 0 || cell >= cellCount) return -1;
    // Cancel an in-flight hint reveal: the player took over.
    if (phase == FlowPhase.hintRevealing) {
      _hintTimer?.cancel();
      _hintTimer = null;
      hintCells = [];
      hintIndex = 0;
      phase = FlowPhase.idle;
    }
    for (int p = 0; p < puzzle.pairs.length; p++) {
      if (cell == puzzle.pairs[p][0] || cell == puzzle.pairs[p][1]) {
        _pushUndo();
        paths[p] = [cell];
        _rebuildOwner();
        dragPair = p;
        _dragChanged = true;
        onEvent?.call(FlowEvent.grab);
        notifyListeners();
        return p;
      }
      final idx = paths[p].indexOf(cell);
      if (idx >= 0) {
        _pushUndo();
        paths[p] = paths[p].sublist(0, idx + 1);
        _rebuildOwner();
        dragPair = p;
        _dragChanged = true;
        onEvent?.call(FlowEvent.grab);
        notifyListeners();
        return p;
      }
    }
    return -1;
  }

  /// Pointer moved to [cell]: extend the active flow step by step so fast
  /// drags never skip cells.
  void dragTo(int cell) {
    if (dragPair == -1) return;
    if (phase == FlowPhase.celebrating || phase == FlowPhase.complete) return;
    final p = dragPair;
    var tail = paths[p].last;
    int guard = 0;
    while (tail != cell && guard < 16) {
      guard++;
      final tr = tail ~/ size, tc = tail % size;
      final cr = cell ~/ size, cc = cell % size;
      int next;
      if (tr != cr) {
        next = tail + (cr > tr ? size : -size);
      } else if (tc != cc) {
        next = tail + (cc > tc ? 1 : -1);
      } else {
        break;
      }
      if (!_step(p, next)) break;
      if (dragPair == -1) return; // pipe completed mid-drag
      tail = paths[p].last;
    }
    notifyListeners();
  }

  void endDrag() {
    if (dragPair != -1) {
      if (_dragChanged) strokes++;
      _dragChanged = false;
      dragPair = -1;
      notifyListeners();
    }
  }

  bool _adjacentCells(int a, int b) {
    final ar = a ~/ size, ac = a % size;
    final br = b ~/ size, bc = b % size;
    return (ar - br).abs() + (ac - bc).abs() == 1;
  }

  bool _isOtherEnd(int p, int cell) {
    final a = puzzle.pairs[p][0], b = puzzle.pairs[p][1];
    final first = paths[p].first;
    return (cell == a || cell == b) && cell != first;
  }

  /// Advance flow p's tail into [next]. Returns false if blocked.
  bool _step(int p, int next) {
    if (next < 0 || next >= cellCount) return false;
    final path = paths[p];
    final tail = path.last;
    if (next == tail) return true;
    if (!_adjacentCells(tail, next)) return false;
    final idx = path.indexOf(next);
    if (idx >= 0) {
      // Backtrack along our own pipe.
      paths[p] = path.sublist(0, idx + 1);
      _rebuildOwner();
      _dragChanged = true;
      onEvent?.call(FlowEvent.backtrack);
      return true;
    }
    final o = owner[next];
    if (o == -1 || (o == p && _isOtherEnd(p, next))) {
      path.add(next);
      owner[next] = p;
      _dragChanged = true;
      onEvent?.call(FlowEvent.extend);
      if (_isOtherEnd(p, next)) {
        // Pipe connected!
        dragPair = -1;
        _dragChanged = true;
        onEvent?.call(FlowEvent.pipeComplete);
        notifyListeners();
        _checkWin();
      }
      return true;
    }
    onEvent?.call(FlowEvent.blocked);
    return false;
  }

  void undo() {
    if (_undoStack.isEmpty ||
        phase == FlowPhase.celebrating ||
        phase == FlowPhase.complete) {
      onEvent?.call(FlowEvent.invalid);
      return;
    }
    if (phase == FlowPhase.hintRevealing) {
      _hintTimer?.cancel();
      _hintTimer = null;
      hintCells = [];
      hintIndex = 0;
      phase = FlowPhase.idle;
    }
    paths = _undoStack.removeLast();
    dragPair = -1;
    _rebuildOwner();
    banner = 'Undone — keep flowing!';
    onEvent?.call(FlowEvent.undo);
    notifyListeners();
  }

  void resetPuzzle() {
    _timer?.cancel();
    _hintTimer?.cancel();
    hintCells = [];
    hintIndex = 0;
    phase = FlowPhase.idle;
    _resetBoard();
    banner = 'Fresh board — connect every pair!';
    onEvent?.call(FlowEvent.reset);
    notifyListeners();
  }

  // ------------------------------------------------------------------ hint
  /// Start an animated hint reveal for the least-progressed incomplete flow.
  /// The reveal is progressive (one cell at a time) — never instant.
  /// Returns false when every flow is already connected.
  bool useHint() {
    if (phase == FlowPhase.celebrating || phase == FlowPhase.complete) {
      return false;
    }
    int target = -1;
    int best = 1 << 30;
    for (int p = 0; p < puzzle.pairs.length; p++) {
      if (pairComplete(p)) continue;
      final progress = paths[p].length;
      if (progress < best) {
        best = progress;
        target = p;
      }
    }
    if (target == -1) return false;
    hintPair = target;
    final sol = puzzle.solution;
    if (sol != null) {
      // True solution known: reveal it progressively.
      hintCells = List<int>.of(sol[target]);
    } else {
      // No stored solution (classic pack): nudge along a BFS route from the
      // current tail (or an endpoint) toward the matching dot through
      // empty cells.
      hintCells = _bfsNudge(target);
      if (hintCells.isEmpty) return false;
    }
    hintIndex = 0;
    phase = FlowPhase.hintRevealing;
    banner = 'Watch closely — here\'s a way through…';
    onEvent?.call(FlowEvent.hint);
    _startHintTimer();
    notifyListeners();
    return true;
  }

  void _startHintTimer() {
    if (_disposed || paused) return;
    _hintTimer?.cancel();
    _hintTimer = Timer.periodic(const Duration(milliseconds: 130), (t) {
      if (_disposed || paused) {
        t.cancel();
        _hintTimer = null;
        return;
      }
      hintIndex++;
      if (hintIndex >= hintCells.length) {
        t.cancel();
        _hintTimer = null;
        hintCells = [];
        hintIndex = 0;
        phase = FlowPhase.idle;
      }
      notifyListeners();
    });
  }

  /// BFS from the flow's best start toward its other endpoint through empty
  /// cells (plus the flow's own cells). Returns up to 8 route cells.
  List<int> _bfsNudge(int p) {
    final a = puzzle.pairs[p][0], b = puzzle.pairs[p][1];
    int start = a;
    if (paths[p].isNotEmpty) {
      // Start from whichever end has progress.
      start = paths[p].first == a ? paths[p].last : paths[p].first;
    }
    final goal = start == a ? b : a;
    final prev = <int, int>{};
    final seen = {start};
    final queue = <int>[start];
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (cur == goal) break;
      final r = cur ~/ size, c = cur % size;
      final nbs = <int>[];
      if (r > 0) nbs.add(cur - size);
      if (r < size - 1) nbs.add(cur + size);
      if (c > 0) nbs.add(cur - 1);
      if (c < size - 1) nbs.add(cur + 1);
      for (final nb in nbs) {
        if (seen.contains(nb)) continue;
        final o = owner[nb];
        if (o != -1 && o != p && nb != goal) continue;
        seen.add(nb);
        prev[nb] = cur;
        queue.add(nb);
      }
    }
    if (!prev.containsKey(goal) && start != goal) return [];
    final route = <int>[];
    var cur = goal;
    while (cur != start) {
      route.add(cur);
      cur = prev[cur]!;
    }
    return route.reversed.take(8).toList();
  }

  // ------------------------------------------------------------------- win
  void _checkWin() {
    if (allPairsComplete && boardFull) {
      phase = FlowPhase.celebrating;
      banner = 'Flooded! Beautiful pipework!';
      onEvent?.call(FlowEvent.levelComplete);
      notifyListeners();
      _arm(const Duration(milliseconds: 1500), _finishLevel);
    } else if (allPairsComplete && !boardFull) {
      banner = 'All pipes connected — now fill every gap!';
      notifyListeners();
    }
  }

  void _finishLevel() {
    if (phase != FlowPhase.celebrating) return;
    phase = FlowPhase.complete;
    notifyListeners();
  }
}
