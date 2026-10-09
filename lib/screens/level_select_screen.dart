import 'package:flutter/material.dart';
import '../engine/flowlines_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/craft.dart';
import '../theme/flowlines_themes.dart';
import 'game_screen.dart';
import 'pro_screen.dart';

/// Level select: Classic pack (15 handcrafted), tier endless boards,
/// and the daily challenge.
class LevelSelectScreen extends StatefulWidget {
  final FlowAudio audio;
  final FlowSettings settings;
  const LevelSelectScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  FlowSettings get _s => widget.settings;
  FlowThemeDef get _t =>
      FlowThemes.byId(_s.themeId, custom: _s.customTheme);

  void _play(FlowPuzzle puzzle, PlayTarget target, {VoidCallback? onNext}) {
    widget.audio.gameStart();
    _s.setLastTarget(target.toJson());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          engine: FlowEngine(puzzle: puzzle),
          audio: widget.audio,
          settings: _s,
          target: target,
          onNext: onNext,
        ),
      ),
    );
  }

  void _playClassic(int i) {
    final target = PlayTarget(
        kind: 'classic', index: i, label: 'Classic ${i + 1}');
    VoidCallback? next;
    if (i + 1 < classicLevels.length &&
        _s.classicLevelUnlocked(i + 1)) {
      next = () {
        Navigator.of(context).pop();
        _playClassic(i + 1);
      };
    }
    _play(
      FlowPuzzle(
        size: 7,
        pairs: [for (final pr in classicLevels[i]) [pr[0], pr[1]]],
        label: 'Classic ${i + 1}',
      ),
      target,
      onNext: next,
    );
  }

  void _playTier(FlowTier tier, int index) {
    final target = PlayTarget(
      kind: 'tier',
      tier: tier,
      index: index,
      label: '${tier.name} ${index + 1}',
    );
    _play(
      FlowGenerator.generate(
        size: tier.size,
        colors: tier.colors,
        seed: FlowGenerator.tierSeed(tier, index + 1),
        label: '${tier.name} ${index + 1}',
      ),
      target,
      onNext: () {
        Navigator.of(context).pop();
        _playTier(tier, index + 1);
      },
    );
  }

  void _playDaily() {
    final now = DateTime.now();
    final key = FlowGenerator.dailyKey(now);
    final target = PlayTarget(kind: 'daily', label: 'Daily $key');
    _play(
      FlowGenerator.generate(
        size: 7,
        colors: 6,
        seed: FlowGenerator.dailySeed(now),
        label: 'Daily Challenge',
      ),
      target,
    );
  }

  void _goPro() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(audio: widget.audio, settings: _s),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final now = DateTime.now();
    final dailyKey = FlowGenerator.dailyKey(now);
    final dailyDone = _s.dailyDone.contains(dailyKey);
    return WorkshopBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Choose a puzzle', style: Craft.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Daily challenge card.
                  _SectionCard(
                    theme: t,
                    title: '📅 Daily Challenge',
                    subtitle: dailyDone
                        ? 'Done! Streak: ${_s.dailyStreak} 🔥'
                        : 'A fresh 7×7 board every day',
                    trailing: dailyDone
                        ? Text('✓', style: Craft.display(30, theme: t))
                        : CraftButton(
                            label: 'Play',
                            width: 110,
                            fontSize: 16,
                            theme: t,
                            onTap: dailyDone ? null : _playDaily,
                          ),
                    onTap: dailyDone ? null : _playDaily,
                  ),
                  const SizedBox(height: 14),
                  Text('Classic Pack', style: Craft.display(20, theme: t)),
                  Text('15 handcrafted boards',
                      style: Craft.body(13,
                          theme: t,
                          color: t.text.withValues(alpha: 0.7))),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: classicLevels.length,
                    itemBuilder: (_, i) {
                      final unlocked = _s.classicLevelUnlocked(i);
                      final done = i + 1 < _s.classicUnlocked;
                      final lockedPro = !_s.isPro && i >= 5;
                      return GestureDetector(
                        onTap: unlocked
                            ? () {
                                widget.audio.click();
                                _playClassic(i);
                              }
                            : () {
                                widget.audio.invalid();
                                if (lockedPro) _goPro();
                              },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: unlocked
                                  ? [t.bgMid, t.bgDeep]
                                  : [
                                      t.groove.withValues(alpha: 0.5),
                                      t.groove.withValues(alpha: 0.3)
                                    ],
                            ),
                            border: Border.all(
                              color: done
                                  ? t.accentLight
                                  : t.accent.withValues(alpha: 0.5),
                              width: done ? 2.5 : 1.5,
                            ),
                          ),
                          child: Text(
                            !unlocked ? '🔒' : (done ? '✓' : '${i + 1}'),
                            style: Craft.display(18,
                                theme: t,
                                color: unlocked
                                    ? t.text
                                    : t.text.withValues(alpha: 0.35)),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Endless Tiers', style: Craft.display(20, theme: t)),
                  Text('Fresh boards forever, seeded & solvable',
                      style: Craft.body(13,
                          theme: t,
                          color: t.text.withValues(alpha: 0.7))),
                  const SizedBox(height: 8),
                  for (final tier in FlowTier.values) ...[
                    _SectionCard(
                      theme: t,
                      title:
                          '${tier.isPro && !_s.isPro ? '🔒 ' : ''}${tier.name}',
                      subtitle:
                          '${tier.detail} · cleared ${_s.tierProgress[tier.name.toLowerCase()] ?? 0}',
                      trailing: CraftButton(
                        label: 'Play',
                        width: 110,
                        fontSize: 16,
                        theme: t,
                        onTap: (tier.isPro && !_s.isPro)
                            ? _goPro
                            : () => _playTier(tier,
                                _s.tierProgress[tier.name.toLowerCase()] ?? 0),
                      ),
                      onTap: (tier.isPro && !_s.isPro)
                          ? _goPro
                          : () => _playTier(tier,
                              _s.tierProgress[tier.name.toLowerCase()] ?? 0),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final FlowThemeDef theme;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  const _SectionCard({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.bgMid.withValues(alpha: 0.9),
              theme.bgDeep.withValues(alpha: 0.9)
            ],
          ),
          border:
              Border.all(color: theme.accent.withValues(alpha: 0.6), width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Craft.display(18, theme: theme)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: Craft.body(13,
                          theme: theme,
                          color: theme.text.withValues(alpha: 0.7))),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
