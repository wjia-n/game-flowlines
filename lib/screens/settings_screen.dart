import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/craft.dart';
import '../theme/flowlines_themes.dart';
import '../transfer/transfer_ui.dart';

/// Settings: audio, player name, progress reset.
class SettingsScreen extends StatefulWidget {
  final FlowAudio audio;
  final FlowSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  FlowSettings get _s => widget.settings;
  FlowThemeDef get _t =>
      FlowThemes.byId(_s.themeId, custom: _s.customTheme);

  void _applyAudio() {
    widget.audio.configure(
      musicOn: _s.musicOn,
      sfxOn: _s.sfxOn,
      volume: _s.volume,
    );
    if (_s.musicOn) {
      widget.audio.startMenuMusic();
    }
  }

  Future<void> _confirmReset() async {
    final t = _t;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [t.bgMid, t.bgDeep]),
            border: Border.all(color: t.accent, width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reset progress?',
                  style: Craft.display(22, theme: t),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'This clears unlocked levels, streaks and stats. Your name, themes and PRO stay.',
                style: Craft.body(14, theme: t),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CraftButton(
                    label: 'Keep',
                    width: 130,
                    fontSize: 16,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop(false);
                    },
                  ),
                  CraftButton(
                    label: 'Reset',
                    width: 130,
                    fontSize: 16,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (yes == true) {
      await _s.resetProgress();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Progress cleared — fresh boards await!',
                style: Craft.body(14, theme: _t)),
            backgroundColor: _t.bgDeep,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
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
          title: Text('Settings', style: Craft.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              TransferSaveTile(gameSlug: 'flowlines'),
                  Text('Sound', style: Craft.display(20, theme: t)),
                  const SizedBox(height: 6),
                  CraftRow(
                    theme: t,
                    label: 'Music',
                    control: CraftToggle(
                      theme: t,
                      value: _s.musicOn,
                      onChanged: (v) {
                        widget.audio.click();
                        _s.setMusic(v);
                        _applyAudio();
                      },
                    ),
                  ),
                  CraftRow(
                    theme: t,
                    label: 'Sound effects',
                    control: CraftToggle(
                      theme: t,
                      value: _s.sfxOn,
                      onChanged: (v) {
                        _s.setSfx(v);
                        _applyAudio();
                        widget.audio.click();
                      },
                    ),
                  ),
                  CraftRow(
                    theme: t,
                    label: 'Volume',
                    control: SizedBox(
                      width: 170,
                      child: CraftSlider(
                        theme: t,
                        value: _s.volume,
                        onChanged: (v) {
                          _s.setVolume(v);
                          _applyAudio();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Player', style: Craft.display(20, theme: t)),
                  const SizedBox(height: 6),
                  CraftRow(
                    theme: t,
                    label: 'Name',
                    control: SizedBox(
                      width: 170,
                      child: TextField(
                        controller: TextEditingController(
                            text: _s.playerName),
                        style: Craft.body(16, theme: t),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: _s.playerName,
                          hintStyle: Craft.body(15,
                              theme: t,
                              color: t.text.withValues(alpha: 0.4)),
                        ),
                        onSubmitted: (v) {
                          widget.audio.click();
                          _s.setPlayerName(v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Data', style: Craft.display(20, theme: t)),
                  const SizedBox(height: 6),
                  CraftRow(
                    theme: t,
                    label: 'Reset progress',
                    control: GestureDetector(
                      onTap: _confirmReset,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: t.pipeColors[0], width: 2),
                        ),
                        child: Text('Reset',
                            style: Craft.label(14,
                                theme: t, color: t.pipeColors[0])),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Flow Lines v2.0 · Made with ♥ by WAJIHA',
                      style: Craft.body(12,
                          theme: t,
                          color: t.text.withValues(alpha: 0.5)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
