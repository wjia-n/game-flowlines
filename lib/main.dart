import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const FlowLinesApp());

class FlowLinesApp extends StatelessWidget {
  const FlowLinesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Flow Lines',
      tagline: 'Connect matching colors without crossing the flows. Fill it ALL!',
      emoji: '🌊',
      slug: 'flowlines',
      howToPlay:
          '• Drag from one colored dot to its twin — paths can\'t cross or overlap.\n• Fill the ENTIRE 7×7 board with pipes to clear the level.\n• 15 hand-crafted levels, from chill 4-color flows to brain-melting 7-color chaos.\n• Stuck? Hit reset and try a wilder route. No timers, no stress — just flow. 🌊',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => FlowLinesScreen(players: players, callbacks: cb),
    );
  }
}
