// Ortak pencereler: km güncelleme, hesap bağlama.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
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

/// "Verilerini güvenceye al" penceresi.
///
/// Hesap bağlama (Google / Apple / e-posta bağlantısı) Firebase kurulumundan
/// sonra aktif olacak. O zamana kadar veriler bu telefonda saklanır.
Future<void> showLinkAccountSheet(BuildContext context) async {
  final store = StoreScope.read(context);
  final vCount = store.vehicles.length;
  final rCount = store.allRecords.length;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TintIcon(Icons.cloud_upload_outlined, AppColors.soonText, AppColors.soonBg, size: 56),
            const SizedBox(height: 14),
            Text('Verilerini güvenceye al', style: display(22, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              '$vCount araç ve $rCount kayıt şu an sadece bu telefonda. Hesabını bağladığında telefon değişse de hepsi gelir.',
              style: body(14, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.catMaintTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.catMaint, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Google, Apple ve e-posta bağlantısıyla tek dokunuşla bağlanma, bulut kurulumu tamamlanınca burada açılacak.',
                      style: body(13, weight: FontWeight.w600, color: const Color(0xFF1B3FA8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BigButton(
              label: 'Tamam',
              dark: true,
              onPressed: () => Navigator.pop(c),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () {
                  store.updateSettings((s) => s.linkCardDismissedAt = DateTime.now());
                  Navigator.pop(c);
                },
                child: Text('Şimdi değil', style: body(14, weight: FontWeight.w700, color: AppColors.inkSoft)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
