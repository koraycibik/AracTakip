// 0 · Karşılama: giriş formu yok, "Hemen başla" ile doğrudan garaja.

import 'package:flutter/material.dart';

import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../services/notification_service.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _start(BuildContext context) async {
    final store = StoreScope.read(context);
    await NotificationService.instance.requestPermission();
    store.updateSettings((s) => s.onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: MaxWidth(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
                child: Column(
                  children: const [
                    _Feature(Icons.notifications_none, AppColors.soonText, AppColors.soonBg,
                        'Hiçbir tarihi kaçırma', 'Muayene, sigorta, kasko, MTV, lastik ve bakım'),
                    SizedBox(height: 16),
                    _Feature(Icons.bar_chart, AppColors.catMaint, AppColors.catMaintTint,
                        'Masraflarını gör', 'Yakıt, şarj, bakım, sanayi ve fazlası'),
                    SizedBox(height: 16),
                    _Feature(Icons.fact_check, AppColors.catInsp, AppColors.catInspTint,
                        'Geçmişini paylaş', 'Satarken bakım ve kaza raporunu gönder'),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.paddingOf(context).bottom + 20),
                child: Column(
                  children: [
                    BigButton(
                      label: 'Hemen başla',
                      trailingIcon: Icons.arrow_forward,
                      onPressed: () => _start(context),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => showLinkAccountSheet(context),
                      child: Text('Hesabım var, giriş yap',
                          style: body(15, weight: FontWeight.w700, color: AppColors.link)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kayıt gerekmez. Devam ederek KVKK aydınlatma metnini ve gizlilik politikasını kabul etmiş olursun.',
                      textAlign: TextAlign.center,
                      style: body(12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(24, top + 40, 24, 34),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -110,
            top: -100 - top,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Positioned(
            right: 0,
            bottom: 0,
            child: Icon(Icons.directions_car, size: 130, color: Color(0x2EFFFFFF)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const TekerimMark(size: 56, background: false),
                  const SizedBox(width: 10),
                  Text(kAppName, style: display(26, weight: FontWeight.w800, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 20),
              Text('Aracının her şeyi,\ntek yerde.',
                  style: display(34, weight: FontWeight.w800, color: Colors.white, height: 1.12)),
              const SizedBox(height: 10),
              SizedBox(
                width: 260,
                child: Text('Otomobil, motosiklet, ATV ya da kamyon. Hepsini takip et.',
                    style: body(15, color: AppColors.navySoft)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.color, this.tint, this.title, this.text);
  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TintIcon(icon, color, tint, size: 46),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: body(15, weight: FontWeight.w700)),
              Text(text, style: body(13, color: AppColors.inkSoft)),
            ],
          ),
        ),
      ],
    );
  }
}
