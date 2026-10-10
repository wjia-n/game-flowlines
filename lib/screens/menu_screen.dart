import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/flowlines_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/craft.dart';
import '../theme/flowlines_themes.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.flowlines';

/// Main menu — Flow Lines workshop edition.
/// Logo, PLAY (resume), puzzles, theme picker, player renaming, settings,
/// PRO, share, review.
class MenuScreen extends StatefulWidget {
  final FlowAudio audio;
  final FlowSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();
  late final TextEditingController _nameCtrl;

  FlowSettings get _s => widget.settings;
  FlowThemeDef get _t =>
      FlowThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _s.playerName);
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Craft.body(15, theme: _t)),
        backgroundColor: _t.bgDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  
  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Real in-app review flow: the Play in-app review sheet when available,
  /// otherwise fall back to opening the store listing. No fake dialogs.
  Future<void> _requestReview() async {
    widget.audio.click();
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {
      // Review UI unavailable on this device/build: stay silent, no fake UI.
    }
  }

  void _share() {
    widget.audio.click();
    SharePlus.instance.share(
      ShareParams(
        text:
            'I\'m flowing pipes in Flow Lines — connect every pair and flood the board! $_storeUrl',
        subject: 'Flow Lines',
      ),
    );
  }

  void _playTarget(PlayTarget target, FlowPuzzle puzzle) {
    widget.audio.gameStart();
    _s.setLastTarget(target.toJson());
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => GameScreen(
        engine: FlowEngine(puzzle: puzzle),
        audio: widget.audio,
        settings: _s,
        target: target,
      ),
    ))
        .then((_) {
      if (mounted) widget.audio.startMenuMusic();
    });
  }

  /// One-tap PLAY: resume the last puzzle, or open the picker.
  void _play() {
    final last = PlayTarget.fromJson(_s.lastTarget);
    if (last == null) {
      _openLevels();
      return;
    }
    switch (last.kind) {
      case 'classic':
        final i = last.index.clamp(0, classicLevels.length - 1);
        if (!_s.classicLevelUnlocked(i)) {
          _openLevels();
          return;
        }
        _playTarget(
          PlayTarget(kind: 'classic', index: i, label: 'Classic ${i + 1}'),
          FlowPuzzle(
            size: 7,
            pairs: [for (final pr in classicLevels[i]) [pr[0], pr[1]]],
            label: 'Classic ${i + 1}',
          ),
        );
      case 'tier':
        final tier = last.tier ?? FlowTier.easy;
        if (tier.isPro && !_s.isPro) {
          _openLevels();
          return;
        }
        final idx = last.index;
        _playTarget(
          PlayTarget(
              kind: 'tier',
              tier: tier,
              index: idx,
              label: '${tier.name} ${idx + 1}'),
          FlowGenerator.generate(
            size: tier.size,
            colors: tier.colors,
            seed: FlowGenerator.tierSeed(tier, idx + 1),
            label: '${tier.name} ${idx + 1}',
          ),
        );
      case 'daily':
        final now = DateTime.now();
        _playTarget(
          PlayTarget(
              kind: 'daily',
              label:
                  'Daily ${FlowGenerator.dailyKey(now)}'),
          FlowGenerator.generate(
            size: 7,
            colors: 6,
            seed: FlowGenerator.dailySeed(now),
            label: 'Daily Challenge',
          ),
        );
    }
  }

  void _openLevels() {
    widget.audio.click();
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) =>
          LevelSelectScreen(audio: widget.audio, settings: _s),
    ))
        .then((_) {
      if (mounted) widget.audio.startMenuMusic();
    });
  }

  void _openSettings() {
    widget.audio.click();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsScreen(audio: widget.audio, settings: _s),
    ));
  }

  void _openPro() {
    widget.audio.click();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(audio: widget.audio, settings: _s),
    ));
  }

  void _openCustomTheme() {
    widget.audio.click();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          CustomThemeScreen(audio: widget.audio, settings: _s),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return WorkshopBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Logo.
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: t.accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 10),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/flowlines_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 14),
                  Text('FLOW LINES',
                      style: Craft.display(40, theme: t),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('CONNECT · FILL · FLOOD',
                      style: Craft.label(13, theme: t),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  CraftButton(
                    label: '▶  PLAY',
                    theme: t,
                    onTap: _play,
                  ),
                  const SizedBox(height: 10),
                  CraftButton(
                    label: '🧩 Puzzles',
                    theme: t,
                    onTap: _openLevels,
                  ),
                  const SizedBox(height: 18),
                  // Player name card.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: t.groove.withValues(alpha: 0.55),
                      border: Border.all(
                          color: t.accent.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pipe fitter',
                                  style: Craft.label(13, theme: t)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _nameCtrl,
                                style: Craft.body(17, theme: t),
                                decoration: InputDecoration(
                                  hintText: 'Your name',
                                  hintStyle: Craft.body(15,
                                      theme: t,
                                      color: t.text.withValues(alpha: 0.4)),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (v) {
                                  widget.audio.click();
                                  _s.setPlayerName(v);
                                  _nameCtrl.text = _s.playerName;
                                },
                              ),
                            ],
                          ),
                        ),
                        _MiniBtn(
                          label: 'Save',
                          theme: t,
                          onTap: () {
                            widget.audio.click();
                            _s.setPlayerName(_nameCtrl.text);
                            _nameCtrl.text = _s.playerName;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Stats strip.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Stat(
                          theme: t,
                          value: '${_s.levelsCompleted}',
                          label: 'Flooded'),
                      _Stat(
                          theme: t,
                          value: '${_s.pipesConnected}',
                          label: 'Pipes'),
                      _Stat(
                          theme: t,
                          value: '${_s.dailyStreak}🔥',
                          label: 'Streak'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('Workshop themes', style: Craft.display(20, theme: t)),
                      const Spacer(),
                      if (_s.isPro)
                        Text('✦ PRO', style: Craft.label(13, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Theme picker grid.
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: FlowThemes.all.length + 1,
                    itemBuilder: (_, i) {
                      if (i == FlowThemes.all.length) {
                        return _themeCell(
                          name: 'Custom',
                          selected: _s.themeId == 'custom',
                          locked: !_s.isPro,
                          swatches: [
                            for (final k in [
                              'accent',
                              'boardLight',
                              'bgMid',
                              'pc0'
                            ])
                              Color(_s.customColors[k]!),
                          ],
                          onTap: () {
                            if (!_s.isPro) {
                              _openPro();
                            } else {
                              _openCustomTheme();
                            }
                          },
                        );
                      }
                      final th = FlowThemes.all[i];
                      final locked =
                          !_s.isPro && FlowThemes.isProTheme(th.id);
                      return _themeCell(
                        name: th.name,
                        selected: _s.themeId == th.id,
                        locked: locked,
                        swatches: [
                          th.boardLight,
                          th.accent,
                          th.pipeColors[0],
                          th.pipeColors[4],
                        ],
                        onTap: () {
                          if (locked) {
                            _openPro();
                          } else {
                            widget.audio.click();
                            _s.setTheme(th.id);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  // Pipe style picker.
                  Row(
                    children: [
                      Text('Pipe style', style: Craft.display(20, theme: t)),
                      const Spacer(),
                      Text(PipeStyles.names[_s.pipeStyle],
                          style: Craft.label(13, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: PipeStyles.names.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final locked =
                            !_s.isPro && PipeStyles.isPro(i);
                        final sel = _s.pipeStyle == i;
                        return GestureDetector(
                          onTap: () {
                            if (locked) {
                              _openPro();
                            } else {
                              widget.audio.click();
                              _s.setPipeStyle(i);
                            }
                          },
                          child: Container(
                            width: 92,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: sel
                                  ? t.accent.withValues(alpha: 0.3)
                                  : t.groove.withValues(alpha: 0.5),
                              border: Border.all(
                                color: sel
                                    ? t.accentLight
                                    : t.accent.withValues(alpha: 0.4),
                                width: sel ? 2.5 : 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(locked ? '🔒' : _styleGlyph(i),
                                    style: const TextStyle(fontSize: 26)),
                                const SizedBox(height: 4),
                                Text(PipeStyles.names[i],
                                    style: Craft.label(10, theme: t),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Secondary actions.
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _MiniBtn(
                          label: _s.isPro ? '✦ PRO' : 'Get PRO',
                          theme: t,
                          onTap: _openPro),
                      _MiniBtn(
                          label: '⚙ Settings', theme: t, onTap: _openSettings),
                      _MiniBtn(label: '↗ Share', theme: t, onTap: _share),
                      _MiniBtn(
                          label: '★ Rate', theme: t, onTap: _requestReview),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text('Made with ♥ by WAJIHA',
                      style: Craft.body(12,
                          theme: t,
                          color: t.text.withValues(alpha: 0.5))),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _styleGlyph(int i) => const [
        '🫧', '🖌', '🔶', '🪵', '🪢', '⚪', '🎀', '🏺', '🎋', '⛓',
      ][i];

  Widget _themeCell({
    required String name,
    required bool selected,
    required bool locked,
    required List<Color> swatches,
    required VoidCallback onTap,
  }) {
    final t = _t;
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? t.accent.withValues(alpha: 0.3)
              : t.groove.withValues(alpha: 0.5),
          border: Border.all(
            color:
                selected ? t.accentLight : t.accent.withValues(alpha: 0.4),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked)
              Text('🔒', style: Craft.display(20, theme: t))
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final c in swatches)
                    Container(
                      width: 13,
                      height: 13,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c,
                        border: Border.all(
                            color: Colors.black.withValues(alpha: 0.4)),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 5),
            Text(name,
                style: Craft.label(9, theme: t),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final FlowThemeDef theme;
  final String value;
  final String label;
  const _Stat({required this.theme, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.groove.withValues(alpha: 0.55),
        border:
            Border.all(color: theme.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Text(value, style: Craft.display(20, theme: theme)),
          Text(label, style: Craft.label(11, theme: theme)),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final FlowThemeDef theme;
  final VoidCallback onTap;
  const _MiniBtn(
      {required this.label, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
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
        child: Text(label, style: Craft.label(14, theme: theme)),
      ),
    );
  }
}
