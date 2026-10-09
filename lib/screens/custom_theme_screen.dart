import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/craft.dart';
import '../theme/flowlines_themes.dart';

/// PRO: custom theme creator — pick board, trim and pipe colors.
/// Live preview, persisted per color.
class CustomThemeScreen extends StatefulWidget {
  final FlowAudio audio;
  final FlowSettings settings;

  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  FlowThemeDef get _t => FlowThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  // Curated workshop-friendly palette choices.
  static const List<Color> palette = [
    Color(0xFF241309), Color(0xFF3B2416), Color(0xFF5C3A21),
    Color(0xFF2B1009), Color(0xFF4A1F14), Color(0xFF6E2F1C),
    Color(0xFF101624), Color(0xFF1C2438), Color(0xFF2C3A55),
    Color(0xFF1A2312), Color(0xFF2E3B22), Color(0xFF4A5A34),
    Color(0xFFC9A227), Color(0xFFE8CE7A), Color(0xFF8A6D1A),
    Color(0xFFB87333), Color(0xFFE09E5A), Color(0xFF7E4F22),
    Color(0xFFC0C6D4), Color(0xFFE8ECF5), Color(0xFF7E8698),
    Color(0xFFF5EFE0), Color(0xFFFAF6EE), Color(0xFF2E2118),
    Color(0xFFC0392B), Color(0xFF1D4E9E), Color(0xFF1B7A4D),
    Color(0xFFD99A2B), Color(0xFF7D3C98), Color(0xFF229954),
    Color(0xFF2471A3), Color(0xFFE67E22), Color(0xFF2E86C1),
    Color(0xFFEFE3C8), Color(0xFF5D4C36), Color(0xFF8A6A42),
  ];

  static const rows = [
    ('Background deep', 'bgDeep'),
    ('Background mid', 'bgMid'),
    ('Board dark', 'boardDark'),
    ('Board light', 'boardLight'),
    ('Groove', 'groove'),
    ('Accent metal', 'accent'),
    ('Accent light', 'accentLight'),
    ('Accent dark', 'accentDark'),
    ('Text', 'text'),
    ('Pipe 1', 'pc0'),
    ('Pipe 2', 'pc1'),
    ('Pipe 3', 'pc2'),
    ('Pipe 4', 'pc3'),
    ('Pipe 5', 'pc4'),
    ('Pipe 6', 'pc5'),
    ('Pipe 7', 'pc6'),
    ('Pipe 8', 'pc7'),
    ('Pipe 9', 'pc8'),
    ('Pipe 10', 'pc9'),
  ];

  Future<void> _pick(String key, String label) async {
    final s = widget.settings;
    final current = Color(s.customColors[key]!);
    final chosen = await showDialog<Color>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [
              _t.bgMid,
              _t.bgDeep,
            ]),
            border: Border.all(color: _t.accent, width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pick $label', style: Craft.display(20, theme: _t)),
              const SizedBox(height: 14),
              SizedBox(
                width: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: palette.length,
                  itemBuilder: (_, i) {
                    final c = palette[i];
                    final selected = c.toARGB32() == current.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        Navigator.of(context).pop(c);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                            color: selected
                                ? _t.accentLight
                                : Colors.black.withValues(alpha: 0.4),
                            width: selected ? 3 : 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              CraftButton(
                label: 'Cancel',
                width: 160,
                fontSize: 16,
                theme: _t,
                onTap: () {
                  widget.audio.click();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      widget.audio.click();
      await s.setCustomColor(key, chosen.toARGB32());
      await s.setTheme('custom');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
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
          title: Text('My Workshop', style: Craft.display(22, theme: t)),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () {
                widget.audio.click();
                s.resetCustomColors();
              },
              child:
                  Text('Reset', style: Craft.label(13, theme: t)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              children: [
                Text(
                  'Design your own board. Tap a row, pick a color — the whole game updates live.',
                  style: Craft.body(14,
                      theme: t, color: t.text.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 10),
                for (final r in rows)
                  GestureDetector(
                    onTap: () => _pick(r.$2, r.$1),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: t.groove.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: t.accent.withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(r.$1,
                                  style: Craft.body(16, theme: t))),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(s.customColors[r.$2]!),
                              border: Border.all(
                                  color: t.accentLight, width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.5),
                                    offset: const Offset(0, 3),
                                    blurRadius: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                CraftButton(
                  label: 'Use this theme',
                  theme: t,
                  onTap: () async {
                    widget.audio.click();
                    await s.setTheme('custom');
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
