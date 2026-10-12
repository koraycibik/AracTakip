// 0 · Karşılama: iki sayfalık tanıtım. Giriş formu yok, "Hemen başla" ile garaja.
//
// Üstte lacivert zemin üzerinde uygulamadan parçalar (araç kartı, gider kartı)
// küçük bir kompozisyon olarak süzülür; altta açık panelde başlık, metin ve butonlar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/features.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../services/notification_service.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _titles = ['Aracının her şeyi,\ntek yerde.', 'Harcamanı gör,\ngeçmişini taşı.'];
  static const _texts = [
    'Muayene, sigorta, kasko, MTV ve bakım tarihlerini senin yerine takip ederiz; '
        'zamanı gelmeden haber veririz.',
    'Yakıt ve bakım giderlerini gir; km başı maliyetini ve aylık özetini gör. '
        'Ustalarını puanla, aracını satınca geçmişini yeni sahibine devret.',
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final store = StoreScope.read(context);
    await NotificationService.instance.requestPermission();
    store.updateSettings((s) => s.onboarded = true);
  }

  void _next() => _pc.animateToPage(1, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final last = _page == 1;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: Column(
          children: [
            // Üst: lacivert sahne
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(child: _Glow()),
                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
                          child: Row(
                            children: [
                              const TekerimMark(size: 34, background: false),
                              const SizedBox(width: 8),
                              Text(kAppName, style: display(20, weight: FontWeight.w800, color: Colors.white)),
                              const Spacer(),
                              AnimatedOpacity(
                                opacity: last ? 0 : 1,
                                duration: const Duration(milliseconds: 200),
                                child: TextButton(
                                  onPressed: last ? null : _next,
                                  style: TextButton.styleFrom(minimumSize: const Size(56, 44)),
                                  child: Text('Atla',
                                      style: body(14, weight: FontWeight.w700, color: AppColors.navySoft)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: PageView(
                            controller: _pc,
                            onPageChanged: (i) => setState(() => _page = i),
                            children: const [_SceneGarage(), _SceneCosts()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Alt: açık panel
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: EdgeInsets.fromLTRB(24, 26, 24, bottom + 14),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a),
                            child: child,
                          ),
                        ),
                        child: Column(
                          key: ValueKey(_page),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_titles[_page], style: display(28, weight: FontWeight.w800, height: 1.12)),
                            const SizedBox(height: 10),
                            Text(_texts[_page], style: body(15, color: AppColors.inkSoft, height: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          for (var i = 0; i < 2; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              margin: const EdgeInsets.only(right: 6),
                              width: i == _page ? 26 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _page ? AppColors.accent : AppColors.border,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      BigButton(
                        label: last ? 'Hemen başla' : 'Devam',
                        trailingIcon: Icons.arrow_forward,
                        onPressed: last ? _start : _next,
                      ),
                      if (kCloudEnabled)
                        TextButton(
                          onPressed: () => showLinkAccountSheet(context, signIn: true),
                          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                          child: Text('Hesabım var, giriş yap',
                              style: body(15, weight: FontWeight.w700, color: AppColors.link)),
                        ),
                      Text(
                        'Kayıt gerekmez. Devam ederek KVKK aydınlatma metnini ve gizlilik politikasını kabul etmiş olursun.',
                        textAlign: TextAlign.center,
                        style: body(11, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sağ üstten yayılan amber ışık.
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.9, -0.7),
          radius: 1.1,
          colors: [AppColors.accent.withValues(alpha: 0.22), AppColors.navy.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// Hafifçe yukarı aşağı süzülen öğe.
class _Float extends StatefulWidget {
  const _Float({required this.child, this.delay = 0, this.amount = 5});
  final Widget child;
  final int delay;
  final double amount;

  @override
  State<_Float> createState() => _FloatState();
}

class _FloatState extends State<_Float> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, (Curves.easeInOut.transform(_c.value) - 0.5) * 2 * widget.amount),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Sahne kabı: 320×300'lük kompozisyonu ekrana sığacak şekilde ölçekler.
class _Scene extends StatelessWidget {
  const _Scene({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(width: 320, height: 300, child: Stack(clipBehavior: Clip.none, children: children)),
        ),
      ),
    );
  }
}

/// Beyaz yüzen etiket.
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.iconColor, required this.text, this.sub});
  final IconData icon;
  final Color iconColor;
  final String text;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration:
                BoxDecoration(color: iconColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: body(12, weight: FontWeight.w800)),
              if (sub != null) Text(sub!, style: body(10, weight: FontWeight.w600, color: AppColors.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniRing extends StatelessWidget {
  const _MiniRing({required this.value, required this.color, required this.big, required this.small});
  final double value;
  final Color color;
  final String big;
  final String small;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: const Color(0x26FFFFFF),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(big, style: display(15, weight: FontWeight.w800, color: Colors.white, height: 1)),
              Text(small, style: body(9, weight: FontWeight.w700, color: AppColors.navySoft)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 1. sahne: araç kartı + hatırlatma etiketleri.
class _SceneGarage extends StatelessWidget {
  const _SceneGarage();

  @override
  Widget build(BuildContext context) {
    return _Scene(children: [
      // Arkadaki ikinci kart
      Positioned(
        left: 46,
        top: 58,
        child: Transform.rotate(
          angle: -0.09,
          child: Container(
            width: 240,
            height: 160,
            decoration: BoxDecoration(color: const Color(0xFF353C7E), borderRadius: BorderRadius.circular(26)),
          ),
        ),
      ),
      // Ana araç kartı
      Positioned(
        left: 30,
        top: 74,
        child: _Float(
          amount: 3,
          child: Transform.rotate(
            angle: 0.03,
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F4D),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0x22FFFFFF)),
                boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 30, offset: Offset(0, 16))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PlateBadge('34 TKR 34', size: 12),
                  const SizedBox(height: 8),
                  Text('Fiat Egea', style: display(18, weight: FontWeight.w800, color: Colors.white)),
                  Text('2021 · Benzin · 56.400 km', style: body(11, color: AppColors.navySoft)),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MiniRing(value: 0.72, color: AppColors.accent, big: '4', small: 'ay'),
                      _MiniRing(value: 0.35, color: Color(0xFF4ADE80), big: '7', small: 'ay'),
                      _MiniRing(value: 0.12, color: Color(0xFFFF6B6B), big: '12', small: 'gün'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      const Positioned(
        right: 0,
        top: 20,
        child: _Float(
          delay: 300,
          child: _Chip(
              icon: Icons.notifications_active, iconColor: Color(0xFFB26A00), text: 'Muayene', sub: '12 gün kaldı'),
        ),
      ),
      const Positioned(
        left: 0,
        bottom: 6,
        child: _Float(
          delay: 900,
          child:
              _Chip(icon: Icons.build, iconColor: AppColors.catMaint, text: 'Periyodik bakım', sub: '1.200 km kaldı'),
        ),
      ),
    ]);
  }
}

/// 2. sahne: aylık gider kartı + km başı, usta puanı, devir etiketleri.
class _SceneCosts extends StatelessWidget {
  const _SceneCosts();

  static const _bars = [
    (0.45, AppColors.catFuel),
    (0.62, AppColors.catFuel),
    (0.38, AppColors.catMaint),
    (0.80, AppColors.catFuel),
    (0.52, AppColors.catIns),
    (0.95, AppColors.accent),
  ];

  @override
  Widget build(BuildContext context) {
    return _Scene(children: [
      Positioned(
        left: 34,
        top: 60,
        child: _Float(
          amount: 3,
          child: Container(
            width: 252,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 30, offset: Offset(0, 16))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ekim gideri', style: body(11, weight: FontWeight.w700, color: AppColors.inkSoft)),
                Text('₺6.240', style: display(26, weight: FontWeight.w800)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 78,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < _bars.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: FractionallySizedBox(
                            heightFactor: _bars[i].$1,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration:
                                  BoxDecoration(color: _bars[i].$2, borderRadius: BorderRadius.circular(7)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const Positioned(
        right: 0,
        top: 14,
        child: _Float(
          delay: 300,
          child: _Chip(icon: Icons.route, iconColor: AppColors.catFuel, text: '₺4,85 / km', sub: 'yakıt maliyetin'),
        ),
      ),
      const Positioned(
        left: 0,
        bottom: 30,
        child: _Float(
          delay: 800,
          child: _Chip(
              icon: Icons.star_rounded, iconColor: Color(0xFFB26A00), text: 'Özgür Oto  ★ 5', sub: 'usta defterin'),
        ),
      ),
      const Positioned(
        right: 6,
        bottom: 0,
        child: _Float(
          delay: 1300,
          child: _Chip(
              icon: Icons.swap_horiz, iconColor: AppColors.navy, text: 'Aracı devret', sub: 'geçmişi yeni sahibine'),
        ),
      ),
    ]);
  }
}
