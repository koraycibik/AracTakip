// 0 · Karşılama: giriş formu yok, "Hemen başla" ile doğrudan garaja.

import 'package:flutter/material.dart';

import '../../core/features.dart';
import '../../core/layout.dart';
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

/// Kaydırılan 3 tanıtım sayfası. İlk araç eklenince garajda kısa tur başlar.
class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pc = PageController();
  int _page = 0;

  static final _pages = [
    const _PageData(
      Icons.notifications_active_outlined,
      'Hiçbir tarihi kaçırma',
      'Muayene, trafik sigortası, kasko, MTV, mevsimlik lastik ve bakım. '
          'Tarihi gelmeden haber veririz; bakımı senin km\'ne göre tahmin ederiz.',
    ),
    const _PageData(
      Icons.bar_chart_rounded,
      'Masraflarını gör',
      'Yakıt, şarj, bakım, ceza… Harcamalarını gir; aylık özetin, 100 km maliyetin ve '
          'önümüzdeki 90 günün tahmini gideri çıksın.',
    ),
    _PageData(
      Icons.star_rounded,
      kShareEnabled ? 'Ustanı puanla, geçmişini paylaş' : 'Ustalarını puanla',
      kShareEnabled
          ? 'Gittiğin servislere puan ver, kendine not düş. Aracını satarken bakım ve kaza geçmişini bir bağlantıyla gönder.'
          : 'Gittiğin servisler kendiliğinden listelenir. Puan ver, kendine not düş; bir sonraki sefere kime gideceğini bil.',
    ),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  bool get _last => _page == _pages.length - 1;

  Future<void> _start() async {
    final store = StoreScope.read(context);
    await NotificationService.instance.requestPermission();
    store.updateSettings((s) => s.onboarded = true);
  }

  void _next() => _pc.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pc,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (var i = 0; i < _pages.length; i++)
                  _Page(
                    data: _pages[i],
                    onSkip: i == _pages.length - 1
                        ? null
                        : () => _pc.animateToPage(_pages.length - 1,
                            duration: const Duration(milliseconds: 320), curve: Curves.easeOut),
                  ),
              ],
            ),
          ),
          MaxWidth(
            maxWidth: 560,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.paddingOf(context).bottom + 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page ? AppColors.accent : AppColors.border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  BigButton(
                    label: _last ? 'Hemen başla' : 'İleri',
                    trailingIcon: Icons.arrow_forward,
                    onPressed: _last ? _start : _next,
                  ),
                  const SizedBox(height: 4),
                  if (kCloudEnabled)
                    TextButton(
                      onPressed: () => showLinkAccountSheet(context, signIn: true),
                      child: Text('Hesabım var, giriş yap',
                          style: body(15, weight: FontWeight.w700, color: AppColors.link)),
                    ),
                  Text(
                    'Kayıt gerekmez. Devam ederek KVKK aydınlatma metnini ve gizlilik politikasını kabul etmiş olursun.',
                    textAlign: TextAlign.center,
                    style: body(12, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageData {
  const _PageData(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;
}

class _Page extends StatelessWidget {
  const _Page({required this.data, this.onSkip});
  final _PageData data;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SingleChildScrollView(
      child: MaxWidth(
        maxWidth: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(24, top + 16, 12, 34),
              decoration: const BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const TekerimMark(size: 40, background: false),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(kAppName, style: display(22, weight: FontWeight.w800, color: Colors.white)),
                      ),
                      if (onSkip != null)
                        TextButton(
                          onPressed: onSkip,
                          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                          child: Text('Atla', style: body(14, weight: FontWeight.w700, color: AppColors.navySoft)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        child: Icon(data.icon, size: 46, color: AppColors.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.title, style: display(28, weight: FontWeight.w800, height: 1.15)),
                  const SizedBox(height: 10),
                  Text(data.text, style: body(15, color: AppColors.inkSoft, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
