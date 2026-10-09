import 'package:flutter/material.dart';
import 'flowlines_themes.dart';

/// FlowCraft — the design system for Flow Lines.
/// Workshop materiality: routed wooden boards, brass/copper/steel trim,
/// enamel pipe colors. No neon, no cyberpunk, no generic Material look.
///
/// All widgets accept an optional [FlowThemeDef]; they default to the
/// Walnut Workshop theme so existing call sites keep working.
class Craft {
  static TextStyle display(double size,
          {Color? color, FlowThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? theme?.accentLight ?? const Color(0xFFE8CE7A),
        letterSpacing: 1.1,
        shadows: const [
          Shadow(
              color: Color(0x99000000),
              offset: Offset(0, 2),
              blurRadius: 4),
        ],
      );

  static TextStyle body(double size, {Color? color, FlowThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme?.text ?? const Color(0xFFF5EFE0),
        height: 1.35,
      );

  static TextStyle label(double size, {Color? color, FlowThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFE8CE7A),
        letterSpacing: 0.8,
      );

  static ThemeData theme([FlowThemeDef? t]) {
    t ??= FlowThemes.byId('walnut');
    final lightBoard = t.id == 'maple' ||
        t.id == 'porcelain' ||
        t.id == 'birch' ||
        t.id == 'sandstone' ||
        t.id == 'honeycomb';
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.bgDeep,
      colorScheme: ColorScheme(
        brightness: lightBoard ? Brightness.light : Brightness.dark,
        primary: t.accent,
        onPrimary: t.bgDeep,
        secondary: t.accentLight,
        onSecondary: t.bgDeep,
        surface: t.bgMid,
        onSurface: t.text,
        error: t.pipeColors[0],
        onError: t.text,
      ),
      textTheme: TextTheme(
        displayLarge: display(34, theme: t),
        displayMedium: display(26, theme: t),
        titleLarge: display(22, theme: t),
        bodyLarge: body(16, theme: t),
        bodyMedium: body(14, theme: t),
        labelLarge: label(14, theme: t),
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.bgMid),
    );
  }
}

/// Routed-wood background with a warm vignette, theme-aware.
class WorkshopBackdrop extends StatelessWidget {
  final Widget child;
  final FlowThemeDef? theme;
  const WorkshopBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FlowThemes.byId('walnut');
    return Container(
      decoration: BoxDecoration(color: t.bgDeep),
      child: CustomPaint(
        painter: _WoodGrainPainter(t),
        child: child,
      ),
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  final FlowThemeDef t;
  _WoodGrainPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final vignette = RadialGradient(
      center: const Alignment(0, -0.25),
      radius: 1.15,
      colors: [
        t.bgMid.withValues(alpha: 0.55),
        t.bgDeep.withValues(alpha: 0.0),
        Colors.black.withValues(alpha: 0.5),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = vignette.createShader(Offset.zero & size),
    );
    final grain = Paint()
      ..color = t.groove.withValues(alpha: 0.35)
      ..strokeWidth = 2.5;
    for (int i = 0; i < 14; i++) {
      final x = size.width * (i + 0.5) / 14;
      final wobble = (i % 3 - 1) * 8.0;
      canvas.drawLine(
        Offset(x + wobble, 0),
        Offset(x - wobble, size.height),
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A chunky workshop button with metal trim — looks physically pressable.
class CraftButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double width;
  final double fontSize;
  final FlowThemeDef? theme;

  const CraftButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 240,
    this.fontSize = 19,
    this.theme,
  });

  @override
  State<CraftButton> createState() => _CraftButtonState();
}

class _CraftButtonState extends State<CraftButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? FlowThemes.byId('walnut');
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 15),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? [t.bgMid, t.bgDeep]
                : [t.bgDeep.withValues(alpha: 0.7), t.bgDeep.withValues(alpha: 0.5)],
          ),
          border: Border.all(color: t.accent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: t.accentLight.withValues(alpha: _pressed ? 0.05 : 0.22),
              offset: const Offset(0, -2),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              offset: Offset(0, _pressed ? 2 : 6),
              blurRadius: _pressed ? 4 : 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: Craft.display(widget.fontSize,
              theme: t,
              color: enabled ? t.text : t.text.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}

/// An engraved metal plaque for titles.
class CraftPlaque extends StatelessWidget {
  final String title;
  final String? subtitle;
  final FlowThemeDef? theme;
  const CraftPlaque({super.key, required this.title, this.subtitle, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FlowThemes.byId('walnut');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.bgDeep, t.groove],
        ),
        border: Border.all(color: t.accent, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0, 6),
              blurRadius: 12),
          BoxShadow(
              color: t.accentLight.withValues(alpha: 0.7),
              offset: const Offset(0, -1),
              blurRadius: 1),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Craft.display(30, theme: t), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: Craft.body(14,
                    theme: t, color: t.text.withValues(alpha: 0.75)),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// A metal lever toggle for settings.
class CraftToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final FlowThemeDef? theme;
  const CraftToggle(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FlowThemes.byId('walnut');
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 64,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: value ? t.accentDark : t.groove,
          border: Border.all(color: t.accent, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 3),
                blurRadius: 5),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.accentLight, t.accent, t.accentDark],
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A wooden-bead volume slider on a metal rail.
class CraftSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final FlowThemeDef? theme;
  const CraftSlider(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FlowThemes.byId('walnut');
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: t.accent,
        inactiveTrackColor: t.groove,
        thumbShape: _BeadThumb(t),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

class _BeadThumb extends SliderComponentShape {
  final FlowThemeDef t;
  const _BeadThumb(this.t);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(26, 26);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    canvas.drawCircle(center + const Offset(0, 2), 12,
        Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawCircle(
        center,
        11,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            radius: 1.0,
            colors: [t.accentLight, t.accent, t.accentDark],
          ).createShader(Rect.fromCircle(center: center, radius: 11)));
  }
}

/// Small helper: a labeled settings row.
class CraftRow extends StatelessWidget {
  final String label;
  final Widget control;
  final FlowThemeDef? theme;
  const CraftRow(
      {super.key, required this.label, required this.control, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FlowThemes.byId('walnut');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: t.groove.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Craft.body(16, theme: t))),
          control,
        ],
      ),
    );
  }
}
