// Tanıtım turu (coach mark / spotlight): ekran kararır, anlatılan yer yuvarlak
// bir pencereyle açıkta kalır, yanında kısa bir açıklama balonu çıkar.
// Her tur ve ipucu bir kez gösterilir; görülenler AppSettings.seenTips'te tutulur.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/app_store.dart';

/// Tur adımlarının hedefleri (ekranda tek bir yerde kullanılan anahtarlar).
class TourKeys {
  TourKeys._();
  static final garageRings = GlobalKey(debugLabel: 'tour.garageRings');
  static final addButton = GlobalKey(debugLabel: 'tour.addButton');
  static final navReminders = GlobalKey(debugLabel: 'tour.navReminders');
  static final navStats = GlobalKey(debugLabel: 'tour.navStats');
}

class CoachStep {
  const CoachStep({required this.target, required this.title, required this.text});
  final GlobalKey target;
  final String title;
  final String text;
}

bool _active = false;

/// Hedefin ekrandaki yeri (görünmüyorsa null).
Rect? _rectOf(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) return null;
  final ro = ctx.findRenderObject();
  if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
  final r = ro.localToGlobal(Offset.zero) & ro.size;
  if (r.width <= 0 || r.height <= 0) return null;
  return r;
}

/// Adımları sırayla gösterir. Hedefi görünmeyen adımlar atlanır.
/// Kullanıcı turu bitirince ya da geçince tamamlanır.
Future<void> showCoachTour(BuildContext context, List<CoachStep> steps) async {
  final visible = steps.where((s) => _rectOf(s.target) != null).toList();
  if (visible.isEmpty || _active) return;
  _active = true;
  try {
    await Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, _, _) => _CoachOverlay(steps: visible),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  } finally {
    _active = false;
  }
}

/// Tek adımlık ipucu: daha önce görülmediyse ve hedef ekrandaysa gösterir.
Future<void> showTipOnce(
  BuildContext context, {
  required String key,
  required GlobalKey target,
  required String title,
  required String text,
}) async {
  final store = StoreScope.read(context);
  if (store.seen(key) || _active || _rectOf(target) == null) return;
  store.markSeen(key);
  await showCoachTour(context, [CoachStep(target: target, title: title, text: text)]);
}

/// Ekran açıldıktan biraz sonra (geçiş animasyonu bitince) ipucunu dener.
/// Ekran o sırada en üstte değilse (üstünde başka sayfa/pencere varsa) göstermez.
void scheduleTip(
  State state, {
  required String key,
  required GlobalKey target,
  required String title,
  required String text,
  Duration delay = const Duration(milliseconds: 650),
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!state.mounted || StoreScope.read(state.context).seen(key)) return;
    await Future<void>.delayed(delay);
    if (!state.mounted) return;
    final route = ModalRoute.of(state.context);
    if (route != null && !route.isCurrent) return;
    // Arka plandaki (görünmeyen) alt menü sekmesindeyse gösterme.
    if (!TickerMode.of(state.context)) return;
    await showTipOnce(state.context, key: key, target: target, title: title, text: text);
  });
}

/// Sarmaladığı alanı, ekran ilk açıldığında bir kez ipucuyla gösterir.
/// Örn. TipAnchor(tipKey: 'tip_detail_km', title: ..., text: ..., child: KmButonu)
class TipAnchor extends StatefulWidget {
  const TipAnchor({
    super.key,
    required this.tipKey,
    required this.title,
    required this.text,
    required this.child,
    this.enabled = true,
  });
  final String tipKey;
  final String title;
  final String text;
  final Widget child;
  final bool enabled;

  @override
  State<TipAnchor> createState() => _TipAnchorState();
}

class _TipAnchorState extends State<TipAnchor> {
  final _target = GlobalKey();

  /// Sekme görünür olunca (TickerMode açılınca) ipucu denenir; alt menüde
  /// arkada duran sekmeler ekranda değilken ipucu göstermez.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.enabled && TickerMode.of(context)) {
      scheduleTip(this, key: widget.tipKey, target: _target, title: widget.title, text: widget.text);
    }
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _target, child: widget.child);
}

class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({required this.steps});
  final List<CoachStep> steps;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay> {
  int _i = 0;

  void _next() {
    if (_i >= widget.steps.length - 1) {
      Navigator.of(context).pop();
    } else {
      setState(() => _i++);
    }
  }

  void _skip() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_i];
    final rect = _rectOf(step.target);
    if (rect == null) {
      // Hedef kayboldu (ekran döndü vb.): bu adımı atla.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _next();
      });
      return const SizedBox.shrink();
    }
    final last = _i == widget.steps.length - 1;
    final hole = rect.inflate(8);

    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final below = hole.center.dy < size.height / 2;
        final bubbleW = math.min(340.0, size.width - 32);
        final left = (hole.center.dx - bubbleW / 2).clamp(16.0, size.width - 16 - bubbleW);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _next,
                child: CustomPaint(painter: _HolePainter(hole)),
              ),
            ),
            Positioned(
              left: left,
              width: bubbleW,
              top: below ? hole.bottom + 14 : null,
              bottom: below ? null : size.height - hole.top + 14,
              child: _Bubble(
                title: step.title,
                text: step.text,
                index: _i,
                count: widget.steps.length,
                last: last,
                onNext: _next,
                onSkip: _skip,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _HolePainter extends CustomPainter {
  _HolePainter(this.hole);
  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(hole, const Radius.circular(20));
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(r),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xD90E1220));
    canvas.drawRRect(
      r,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.hole != hole;
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.title,
    required this.text,
    required this.index,
    required this.count,
    required this.last,
    required this.onNext,
    required this.onSkip,
  });
  final String title;
  final String text;
  final int index;
  final int count;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x400E1220), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: display(16, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(text, style: body(14, color: AppColors.inkSoft, height: 1.4)),
          const SizedBox(height: 6),
          Row(
            children: [
              if (count > 1)
                Text('${index + 1}/$count', style: body(12, weight: FontWeight.w700, color: AppColors.inkSoft)),
              const Spacer(),
              if (!last)
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: AppColors.inkSoft),
                  child: Text('Geç', style: body(14, weight: FontWeight.w700, color: AppColors.inkSoft)),
                ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.ink,
                  minimumSize: const Size(88, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: body(14, weight: FontWeight.w800),
                ),
                child: Text(last ? 'Anladım' : 'İleri'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
