// Ortak pencereler: km güncelleme, hesap bağlama.

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../services/cloud_service.dart';
import 'common.dart';

/// Kilometre güncelleme penceresi.
Future<void> showKmDialog(BuildContext context, Vehicle v) async {
  final store = StoreScope.read(context);
  final ctrl = TextEditingController(text: thousands(v.currentKm));
  final result = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${v.title} kilometresi', style: display(20, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Son güncelleme: ${dateLong(v.kmUpdatedAt)}',
              style: body(13, color: AppColors.inkSoft)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            style: display(30, weight: FontWeight.w800),
            decoration: const InputDecoration(suffixText: 'km'),
            onSubmitted: (t) => Navigator.pop(c, parseKm(t)),
          ),
          const SizedBox(height: 8),
          Text('Bakım tahminleri bu bilgiye göre yeniden hesaplanır.',
              style: body(12, color: AppColors.inkSoft)),
          const SizedBox(height: 16),
          BigButton(
            label: 'Kaydet',
            dark: true,
            icon: Icons.check,
            onPressed: () => Navigator.pop(c, parseKm(ctrl.text)),
          ),
        ],
      ),
    ),
  );
  if (result == null) return;
  if (result < v.currentKm && context.mounted) {
    final ok = await confirm(context,
        title: 'Km azalıyor',
        message:
            'Girdiğin değer (${thousands(result)} km) mevcut km\'den (${thousands(v.currentKm)}) küçük. Düzeltme olarak kaydedilsin mi?',
        ok: 'Kaydet',
        danger: false);
    if (!ok) return;
  }
  store.updateKm(v.id, result);
  if (context.mounted) toast(context, 'Kilometre güncellendi');
}

/// "Verilerini güvenceye al" penceresi: tek dokunuşla Google hesabını bağlar.
/// [signIn] true ise karşılama ekranındaki "Hesabım var, giriş yap" metinleri kullanılır.
Future<void> showLinkAccountSheet(BuildContext context, {bool signIn = false}) async {
  final store = StoreScope.read(context);
  final vCount = store.vehicles.length;
  final rCount = store.allRecords.length;
  final android = defaultTargetPlatform == TargetPlatform.android;
  final start = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TintIcon(Icons.cloud_done_outlined, AppColors.okText, AppColors.okBg, size: 56),
            const SizedBox(height: 14),
            Text(signIn ? 'Hesabına giriş yap' : 'Verilerini güvenceye al',
                style: display(22, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              signIn
                  ? "Daha önce Tekerim'i Google hesabınla bağladıysan, aynı hesapla devam et; araçların ve kayıtların bu telefona gelsin."
                  : (vCount == 0
                      ? 'Hesabını bağla; telefon değişse de araçların ve kayıtların seninle gelsin.'
                      : '$vCount araç ve $rCount kaydın var. Hesabını bağla; telefon değişse de hepsi seninle gelsin.'),
              style: body(14, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 18),
            if (android)
              BigButton(
                label: 'Google ile devam et',
                icon: Icons.account_circle_outlined,
                dark: true,
                onPressed: () => Navigator.pop(c, true),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.catMaintTint, borderRadius: BorderRadius.circular(16)),
                child: Text('iPhone için "Apple ile devam et" yakında geliyor.',
                    style: body(13, weight: FontWeight.w600, color: const Color(0xFF1B3FA8))),
              ),
            const SizedBox(height: 10),
            Text('Şifre yok. Google hesabın yalnızca kim olduğunu doğrulamak için kullanılır.',
                style: body(12, color: AppColors.inkSoft)),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () {
                  if (!signIn) store.updateSettings((s) => s.linkCardDismissedAt = DateTime.now());
                  Navigator.pop(c, false);
                },
                child: Text('Şimdi değil', style: body(14, weight: FontWeight.w700, color: AppColors.inkSoft)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (start == true && context.mounted) await linkWithGoogleFlow(context);
}

/// Google ile bağlama akışı (pencere, onay, ilerleme ve sonuç mesajları).
Future<void> linkWithGoogleFlow(BuildContext context) async {
  final cloud = CloudService.instance;
  final store = StoreScope.read(context);
  try {
    final outcome = await cloud.linkWithGoogle();
    if (!context.mounted) return;
    switch (outcome) {
      case LinkOutcome.canceled:
        return;
      case LinkOutcome.linked:
        toast(context, 'Hesabın bağlandı. Verilerin artık yedekleniyor.');
      case LinkOutcome.existingAccount:
        final ok = store.isEmpty ||
            await confirm(
              context,
              title: 'Bu Google hesabıyla kayıtlı verilerin var',
              message:
                  'O hesaba geçiyoruz. Bu telefondaki ${store.vehicles.length} araç ve ${store.allRecords.length} kayıt da o hesaba eklenecek.',
              ok: 'Devam et',
              danger: false,
            );
        if (!ok || !context.mounted) return;
        await _withProgress(context, 'Verilerin getiriliyor…', cloud.switchToExistingAccount);
        if (context.mounted) toast(context, 'Hesabına giriş yapıldı.');
    }
  } catch (e) {
    debugPrint('Google ile bağlanamadı: $e');
    if (context.mounted) {
      toast(context, 'Bağlanamadı (${cloudErrorCode(e)}). İnternet bağlantını kontrol edip tekrar dene.');
    }
  }
}

/// İşlem sürerken ekranı kilitleyen küçük bekleme penceresi.
Future<void> _withProgress(BuildContext context, String text, Future<void> Function() job) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 16),
            Expanded(child: Text(text, style: body(15, weight: FontWeight.w600))),
          ],
        ),
      ),
    ),
  );
  try {
    await job();
  } finally {
    nav.pop();
  }
}

/// Uzun süren bir işlemi bekleme penceresiyle çalıştırır (ayarlar ekranı için).
Future<void> runWithProgress(BuildContext context, String text, Future<void> Function() job) =>
    _withProgress(context, text, job);
