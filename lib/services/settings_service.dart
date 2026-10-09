import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/flowlines_engine.dart';
import '../theme/flowlines_themes.dart';

/// Persisted settings + stats for Flow Lines. Survives app restarts.
///
/// Stores: audio toggles, player name, theme/appearance choices (incl.
/// custom theme colors), tier/classic progress, daily streak, hint budget,
/// Pro unlock state, and lifetime stats.
class FlowSettings extends ChangeNotifier {
  static const _kMusic = 'flowlines_music_on';
  static const _kSfx = 'flowlines_sfx_on';
  static const _kVolume = 'flowlines_volume';
  static const _kNames = 'flowlines_player_names'; // legacy unordered StringSet key
  /// Order-safe player-name storage: a single JSON string. Android's
  /// SharedPreferences stores StringLists as an unordered StringSet, so the
  /// old key scrambled name order on every app restart. Never use a
  /// StringList for ordered data on Android.
  static const _kNamesJson = 'flowlines_player_names_json';
  static const _kTheme = 'flowlines_theme_id';
  static const _kPipeStyle = 'flowlines_pipe_style';
  static const _kIsPro = 'flowlines_is_pro';
  static const _kClassic = 'flowlines_classic_unlocked';
  static const _kTiersJson = 'flowlines_tier_progress_json';
  static const _kDailyJson = 'flowlines_daily_done_json';
  static const _kStreak = 'flowlines_daily_streak';
  static const _kLastDaily = 'flowlines_last_daily';
  static const _kHintsDay = 'flowlines_hints_day';
  static const _kHintsUsed = 'flowlines_hints_used';
  static const _kLastTarget = 'flowlines_last_target_json';
  static const _kLevelsDone = 'flowlines_levels_completed';
  static const _kPipesDone = 'flowlines_pipes_connected';
  static const _kCustomPrefix = 'flowlines_custom_';

  static const defaultNames = ['Player'];

  /// Encode player names as one JSON string (order-preserving).
  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i % defaultNames.length] : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.isNotEmpty) {
        return [for (int i = 0; i < d.length; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'walnut';
  int pipeStyle = 0;
  bool isPro = false;

  /// Classic pack: how many levels are unlocked (sequential).
  int classicUnlocked = 1;

  /// Tier endless progress: completed level count per tier.
  Map<String, int> tierProgress = {'easy': 0, 'medium': 0, 'hard': 0};

  /// Completed daily challenge keys (yyyy-MM-dd).
  Set<String> dailyDone = {};

  int dailyStreak = 0;
  String lastDailyKey = '';
  String hintsDay = '';
  int hintsUsedToday = 0;

  int levelsCompleted = 0;
  int pipesConnected = 0;

  /// Last played puzzle (for one-tap resume on the menu).
  Map<String, dynamic>? lastTarget;

  /// Custom theme colors (ARGB ints). Defaults mirror Walnut Workshop.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'bgDeep': 0xFF241309,
    'bgMid': 0xFF3B2416,
    'boardDark': 0xFF4A2F1B,
    'boardLight': 0xFF5C3A21,
    'groove': 0xFF2A1608,
    'accent': 0xFFC9A227,
    'accentLight': 0xFFE8CE7A,
    'accentDark': 0xFF8A6D1A,
    'text': 0xFFF5EFE0,
    'pc0': 0xFFC0392B,
    'pc1': 0xFFE67E22,
    'pc2': 0xFFD9A821,
    'pc3': 0xFF1E8449,
    'pc4': 0xFF2471A3,
    'pc5': 0xFF7D3C98,
    'pc6': 0xFFCA6F1E,
    'pc7': 0xFFB03A5B,
    'pc8': 0xFF2E86C1,
    'pc9': 0xFF7D6608,
  };

  static const List<String> _pcNames = [
    'Pipe 1', 'Pipe 2', 'Pipe 3', 'Pipe 4', 'Pipe 5',
    'Pipe 6', 'Pipe 7', 'Pipe 8', 'Pipe 9', 'Pipe 10',
  ];

  /// Builds the user-designed custom theme from stored colors.
  FlowThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return FlowThemeDef(
      id: 'custom',
      name: 'My Workshop',
      bgDeep: c('bgDeep'),
      bgMid: c('bgMid'),
      boardDark: c('boardDark'),
      boardLight: c('boardLight'),
      groove: c('groove'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      accentDark: c('accentDark'),
      text: c('text'),
      textDim: c('text'),
      pipeColors: [for (int i = 0; i < 10; i++) c('pc$i')],
      pipeColorNames: _pcNames,
    );
  }

  String get playerName => playerNames.isNotEmpty ? playerNames[0] : 'Player';

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    // Player names: prefer the order-safe JSON key. Fall back to the legacy
    // StringList key once (one-time migration); it may already be scrambled
    // on Android, which is exactly the bug this replaces.
    final namesRaw = p.getString(_kNamesJson);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getStringList(_kNames);
      playerNames = (legacy != null && legacy.isNotEmpty)
          ? [for (int i = 0; i < legacy.length; i++) _cleanName(i, legacy[i])]
          : List.of(defaultNames);
    }
    themeId = p.getString(_kTheme) ?? 'walnut';
    pipeStyle = (p.getInt(_kPipeStyle) ?? 0).clamp(0, PipeStyles.names.length - 1);
    isPro = p.getBool(_kIsPro) ?? false;
    classicUnlocked = (p.getInt(_kClassic) ?? 1).clamp(1, classicLevels.length);
    try {
      final t = jsonDecode(p.getString(_kTiersJson) ?? '{}');
      if (t is Map) {
        for (final k in ['easy', 'medium', 'hard']) {
          final v = t[k];
          tierProgress[k] = v is int ? v.clamp(0, 100000) : 0;
        }
      }
    } catch (_) {}
    try {
      final d = jsonDecode(p.getString(_kDailyJson) ?? '[]');
      if (d is List) dailyDone = {for (final e in d) e.toString()};
    } catch (_) {}
    dailyStreak = p.getInt(_kStreak) ?? 0;
    lastDailyKey = p.getString(_kLastDaily) ?? '';
    hintsDay = p.getString(_kHintsDay) ?? '';
    hintsUsedToday = p.getInt(_kHintsUsed) ?? 0;
    levelsCompleted = p.getInt(_kLevelsDone) ?? 0;
    pipesConnected = p.getInt(_kPipesDone) ?? 0;
    try {
      final lt = jsonDecode(p.getString(_kLastTarget) ?? 'null');
      if (lt is Map<String, dynamic>) lastTarget = lt;
    } catch (_) {}
    for (final k in _defaultCustomColors.keys) {
      customColors[k] = p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kNames); // drop the legacy unordered key for good
    await p.setString(_kTheme, themeId);
    await p.setInt(_kPipeStyle, pipeStyle);
    await p.setBool(_kIsPro, isPro);
    await p.setInt(_kClassic, classicUnlocked);
    await p.setString(_kTiersJson, jsonEncode(tierProgress));
    await p.setString(_kDailyJson, jsonEncode(dailyDone.toList()));
    await p.setInt(_kStreak, dailyStreak);
    await p.setString(_kLastDaily, lastDailyKey);
    await p.setString(_kHintsDay, hintsDay);
    await p.setInt(_kHintsUsed, hintsUsedToday);
    await p.setInt(_kLevelsDone, levelsCompleted);
    await p.setInt(_kPipesDone, pipesConnected);
    if (lastTarget != null) {
      await p.setString(_kLastTarget, jsonEncode(lastTarget));
    }
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || FlowThemes.isProTheme(themeId)) {
      themeId = 'walnut';
      changed = true;
    }
    if (PipeStyles.isPro(pipeStyle)) {
      pipeStyle = 0;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerNames = [clean.isEmpty ? defaultNames[0] : clean];
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    // Pro-only themes (incl. the custom theme creator) require Pro;
    // silently ignore otherwise (UI shows lock).
    if (!isPro && (id == 'custom' || FlowThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setPipeStyle(int v) async {
    v = v.clamp(0, PipeStyles.names.length - 1);
    if (!isPro && PipeStyles.isPro(v)) return;
    pipeStyle = v;
    notifyListeners();
    await _save();
  }

  /// Free players get 5 hints per day; Pro is unlimited.
  bool get hintsUnlimited => isPro;

  int get hintsRemaining {
    final today = FlowGenerator.dailyKey(DateTime.now());
    if (hintsDay != today) return 5;
    if (isPro) return 999;
    return (5 - hintsUsedToday).clamp(0, 5);
  }

  /// Consume one hint from the daily budget. Returns false when none left.
  Future<bool> spendHint() async {
    final today = FlowGenerator.dailyKey(DateTime.now());
    if (hintsDay != today) {
      hintsDay = today;
      hintsUsedToday = 0;
    }
    if (!isPro && hintsUsedToday >= 5) return false;
    hintsUsedToday++;
    notifyListeners();
    await _save();
    return true;
  }

  /// Record a finished level.
  Future<void> recordLevelComplete({
    required int pipes,
    String? classicIndex, // 'classic:<i>' when a classic level
    FlowTier? tier,
    int? tierIndex,
    bool daily = false,
  }) async {
    levelsCompleted++;
    pipesConnected += pipes;
    if (classicIndex != null) {
      final i = int.tryParse(classicIndex.split(':').last) ?? -1;
      if (i >= 0 && i + 2 > classicUnlocked) {
        classicUnlocked = (i + 2).clamp(1, classicLevels.length);
      }
    }
    if (tier != null && tierIndex != null) {
      final key = tier.name.toLowerCase();
      final cur = tierProgress[key] ?? 0;
      if (tierIndex + 1 > cur) tierProgress[key] = tierIndex + 1;
    }
    if (daily) {
      final key = FlowGenerator.dailyKey(DateTime.now());
      if (!dailyDone.contains(key)) {
        dailyDone.add(key);
        // Streak: consecutive calendar days.
        final yesterday = FlowGenerator.dailyKey(
            DateTime.now().subtract(const Duration(days: 1)));
        dailyStreak = (lastDailyKey == yesterday) ? dailyStreak + 1 : 1;
        lastDailyKey = key;
      }
    }
    notifyListeners();
    await _save();
  }

  bool tierUnlocked(FlowTier tier, int index) {
    if (tier.isPro && !isPro) return false;
    return index <= (tierProgress[tier.name.toLowerCase()] ?? 0);
  }

  bool classicLevelUnlocked(int index) {
    if (!isPro && index >= 5) return false; // free: first 5 classic levels
    return index < classicUnlocked;
  }

  Future<void> setLastTarget(Map<String, dynamic> target) async {
    lastTarget = target;
    notifyListeners();
    await _save();
  }

  Future<void> resetProgress() async {
    classicUnlocked = 1;
    tierProgress = {'easy': 0, 'medium': 0, 'hard': 0};
    dailyDone = {};
    dailyStreak = 0;
    lastDailyKey = '';
    levelsCompleted = 0;
    pipesConnected = 0;
    notifyListeners();
    await _save();
  }
}
