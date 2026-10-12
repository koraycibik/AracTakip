// Garajdaki devir kartları: gelen teklif(ler) ve "Satılan araçlar" bağlantısı.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../services/transfer_service.dart';
import '../screens/sold_vehicles_screen.dart';
import 'coach.dart';
import 'common.dart';
import 'dialogs.dart';

/// Bana gelen devir teklifleri (yoksa hiçbir şey çizmez).
class IncomingTransfersCard extends StatelessWidget {
  const IncomingTransfersCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TransferOffer>>(
      valueListenable: TransferService.instance.incoming,
      builder: (context, list, _) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: i == 0
                    ? TipAnchor(
                        tipKey: 'tip_transfer_incoming',
                        title: 'Sana araç devredildi',
                        text: 'Kabul edersen araç; bakım geçmişi, km kayıtları ve kaza bilgileriyle garajına eklenir. '
                            'Önceki sahibin kayıtları "Önceki sahip" etiketiyle görünür, senin harcamalarına karışmaz.',
                        child: _OfferCard(offer: list[i]),
                      )
                    : _OfferCard(offer: list[i]),
              ),
          ],
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});
  final TransferOffer offer;

  Future<void> _accept(BuildContext context) async {
    final store = StoreScope.read(context);
    final same = store.vehicleByPlate(offer.plate);
    final ok = await confirm(
      context,
      title: same != null ? '${offer.plate} geçmişi eklensin mi?' : '${offer.plate} garajına eklensin mi?',
      message: same != null
          ? 'Garajında bu plakalı araç zaten var. Önceki sahibin bakım, lastik, muayene ve kaza kayıtları, '
              'km geçmişi ve usta notları bu aracın üzerine "Önceki sahip" etiketiyle eklenecek; kendi kayıtların değişmez.'
          : 'Araç; bakım, lastik ve muayene geçmişi, km kayıtları, bakım planı, kaza kayıtları ve usta notlarıyla '
              'birlikte eklenecek.',
      ok: 'Kabul et',
      danger: false,
    );
    if (!ok || !context.mounted) return;
    try {
      await runWithProgress(context, 'Araç ekleniyor…', () async {
        await TransferService.instance.accept(store, offer);
      });
      if (context.mounted) {
        toast(context, same != null ? '${offer.plate} geçmişi aracına eklendi.' : '${offer.plate} garajına eklendi.');
      }
    } catch (e) {
      if (context.mounted) toast(context, transferErrorText(e));
    }
  }

  Future<void> _decline(BuildContext context) async {
    final store = StoreScope.read(context);
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Teklif reddedilsin mi?', style: display(18, weight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${offer.fromName} reddettiğini görür; isterse tekrar gönderebilir.',
                  style: body(13, color: AppColors.inkSoft)),
              const SizedBox(height: 14),
              BigButton(label: 'Reddet', dark: true, onPressed: () => Navigator.pop(c, 1)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(c, 2),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: AppColors.lateText),
                child: const Text('Reddet ve bu araç için bir daha teklif alma'),
              ),
              TextButton(onPressed: () => Navigator.pop(c, 0), child: const Text('Vazgeç')),
            ],
          ),
        ),
      ),
    );
    if (choice == null || choice == 0 || !context.mounted) return;
    try {
      await runWithProgress(context, 'Gönderiliyor…',
          () => TransferService.instance.decline(store, offer, block: choice == 2));
    } catch (e) {
      if (context.mounted) toast(context, transferErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = offer;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const TintIcon(Icons.swap_horiz, AppColors.navy, AppColors.soonBg, size: 36),
              const SizedBox(width: 10),
              Expanded(child: Text('Araç devir teklifi', style: display(16, weight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PlateBadge(o.plate, size: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text(o.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${o.fromName} gönderdi · ${dateShort(o.expiresAt)} tarihine kadar geçerli',
              style: body(12, color: AppColors.inkSoft)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _decline(context),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('Reddet'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _accept(context),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.ink,
                    textStyle: body(15, weight: FontWeight.w800),
                  ),
                  child: const Text('Kabul et'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Garajın altında: "Satılan araçlar (n) ›"
class SoldVehiclesLink extends StatelessWidget {
  const SoldVehiclesLink({super.key});

  @override
  Widget build(BuildContext context) {
    final sold = StoreScope.of(context).archivedVehicles;
    if (sold.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SoldVehiclesScreen())),
        child: Row(
          children: [
            const TintIcon(Icons.inventory_2_outlined, AppColors.catOther, AppColors.catOtherTint, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Satılan araçlar', style: body(14, weight: FontWeight.w700)),
                  Text('${sold.length} araç · harcama özetleri', style: body(12, color: AppColors.inkSoft)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}
