// Uygulama genelinde kullanılan küçük bileşenler.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../logic/maintenance.dart';

// ---------------------------------------------------------------------------
// Türk plakası
// ---------------------------------------------------------------------------

class PlateBadge extends StatelessWidget {
  const PlateBadge(this.plate, {super.key, this.size = 15});
  final String plate;
  final double size;

  @override
  Widget build(BuildContext context) {
    final h = size * 2;
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.4),
        border: Border.all(color: AppColors.ink, width: size >= 20 ? 3 : 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: size * 1.2,
            color: AppColors.plateBlue,
            alignment: Alignment.bottomCenter,
            padding: EdgeInsets.only(bottom: size * 0.18),
            child: Text('TR',
                style: body(size * 0.5, weight: FontWeight.w700, color: Colors.white)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.6),
            child: Center(
              child: Text(
                plate.toUpperCase(),
                maxLines: 1,
                style: display(size, weight: FontWeight.w700, letterSpacing: size * 0.07),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kalan süre halkası
// ---------------------------------------------------------------------------

class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    required this.color,
    required this.center,
    this.size = 54,
    this.stroke = 5,
    this.trackColor = const Color(0x26FFFFFF),
    this.textColor = Colors.white,
  });

  /// 0..1 (dolu kısım)
  final double value;
  final Color color;
  final String center;
  final double size;
  final double stroke;
  final Color trackColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value.clamp(0.0, 1.0), color, trackColor, stroke),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(center,
                  style: display(size * 0.28, weight: FontWeight.w700, color: textColor)),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track, this.stroke);
  final double value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    if (value > 0) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * math.max(value, 0.03), false,
          p..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color;
}

// ---------------------------------------------------------------------------
// Renkli kare ikon
// ---------------------------------------------------------------------------

class TintIcon extends StatelessWidget {
  const TintIcon(this.icon, this.color, this.tint, {super.key, this.size = 42});
  final IconData icon;
  final Color color;
  final Color tint;
  final double size;

  factory TintIcon.category(RecordCategory c, {double size = 42}) {
    final s = categoryStyle(c);
    return TintIcon(s.icon, s.color, s.tint, size: size);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(size * 0.33),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

// ---------------------------------------------------------------------------
// Kart
// ---------------------------------------------------------------------------

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.color = AppColors.card,
    this.border,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: border,
          boxShadow: color == AppColors.card
              ? const [BoxShadow(color: Color(0x0D0E1220), blurRadius: 8, offset: Offset(0, 2))]
              : null,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Durum etiketi
// ---------------------------------------------------------------------------

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, this.state, {super.key});
  final String text;
  final DueState state;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = stateColors(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: body(12, weight: FontWeight.w700, color: fg)),
    );
  }
}

(Color, Color) stateColors(DueState s) {
  switch (s) {
    case DueState.ok:
      return (AppColors.okText, AppColors.okBg);
    case DueState.soon:
      return (AppColors.soonText, AppColors.soonBg);
    case DueState.overdue:
      return (AppColors.lateText, AppColors.lateBg);
  }
}

// ---------------------------------------------------------------------------
// Butonlar
// ---------------------------------------------------------------------------

class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.dark = false,
    this.trailingIcon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? AppColors.ink : AppColors.accent;
    final fg = dark ? Colors.white : AppColors.ink;
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: AppColors.border,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: display(16, weight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: dark ? AppColors.accent : fg),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.light = false,
    this.badge = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool light; // koyu zemin üzerinde
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: light ? const Color(0x1FFFFFFF) : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 22, color: light ? Colors.white : AppColors.ink),
                if (badge)
                  Positioned(
                    top: 10,
                    right: 11,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5484D),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Seçilebilir çip (filtreler, sekmeler).
class PillChoice extends StatelessWidget {
  const PillChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.ink,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : AppColors.card,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? color : AppColors.border, width: 2),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(label,
              style: body(13,
                  weight: FontWeight.w700, color: selected ? Colors.white : AppColors.ink)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form alanları
// ---------------------------------------------------------------------------

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.hint});
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: text),
          if (hint != null)
            TextSpan(text: ' · $hint', style: body(12, weight: FontWeight.w500, color: AppColors.inkSoft)),
        ]),
        style: body(13, weight: FontWeight.w600, color: AppColors.inkSoft),
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.labelHint,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });
  final String label;
  final String? labelHint;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? suffixIcon;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;
  final String? suffix;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, hint: labelHint),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          minLines: 1,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          readOnly: readOnly,
          onTap: onTap,
          style: body(16, weight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            suffixIcon: suffixIcon == null ? null : Icon(suffixIcon, color: AppColors.inkSoft),
            counterText: '',
          ),
        ),
      ],
    );
  }
}

/// Tarih seçme alanı.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.labelHint,
    this.firstDate,
    this.lastDate,
    this.allowClear = false,
  });
  final String label;
  final String? labelHint;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, hint: labelHint),
        Material(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final d = await pickDate(context,
                  initial: value, first: firstDate, last: lastDate);
              if (d != null) onChanged(d);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value == null ? 'Seç' : dateNumeric(value!),
                      style: body(16,
                          weight: FontWeight.w600,
                          color: value == null ? AppColors.inkFaint : AppColors.ink),
                    ),
                  ),
                  if (allowClear && value != null)
                    GestureDetector(
                      onTap: () => onChanged(null),
                      child: const Icon(Icons.close, size: 18, color: AppColors.inkSoft),
                    )
                  else
                    const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.inkSoft),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<DateTime?> pickDate(BuildContext context,
    {DateTime? initial, DateTime? first, DateTime? last}) {
  final now = DateTime.now();
  final f = first ?? DateTime(now.year - 30);
  final l = last ?? DateTime(now.year + 10);
  var init = initial ?? now;
  if (init.isBefore(f)) init = f;
  if (init.isAfter(l)) init = l;
  return showDatePicker(
    context: context,
    initialDate: init,
    firstDate: f,
    lastDate: l,
    locale: const Locale('tr'),
  );
}

/// Sadece rakam girişi.
final digitsOnly = FilteringTextInputFormatter.digitsOnly;

/// Para girişi: rakam, virgül, nokta.
final moneyFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

/// Km girişini binlik ayraçla gösterir (84.250).
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final t = thousands(n);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

// ---------------------------------------------------------------------------
// Başlıklar ve boş durum
// ---------------------------------------------------------------------------

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: display(17, weight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.text, this.action});
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TintIcon(icon, AppColors.inkSoft, AppColors.catOtherTint, size: 56),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: display(17, weight: FontWeight.w700)),
          if (text != null) ...[
            const SizedBox(height: 6),
            Text(text!, textAlign: TextAlign.center, style: body(14, color: AppColors.inkSoft)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Ekran başlığı (geri butonu + başlık + alt başlık).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.closeIcon = false,
  });
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool closeIcon;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          if (canPop || onBack != null) ...[
            SquareIconButton(
              icon: closeIcon ? Icons.close : Icons.arrow_back,
              tooltip: closeIcon ? 'Kapat' : 'Geri',
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: display(24, weight: FontWeight.w800)),
                if (subtitle != null)
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(13, color: AppColors.inkSoft)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Basit onay penceresi.
Future<bool> confirm(BuildContext context,
    {required String title, required String message, String ok = 'Sil', bool danger = true}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: display(19)),
      content: Text(message, style: body(14, color: AppColors.inkSoft)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: danger ? AppColors.lateText : AppColors.ink),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
