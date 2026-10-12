// Satılan (devredilen) araçlar: salt okunur harcama özeti. Yeni kayıt eklenemez.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../logic/maintenance.dart';
import '../widgets/common.dart';

class SoldVehiclesScreen extends StatelessWidget {
  const SoldVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final sold = store.archivedVehicles;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(bottom: bottomSpace(context)),
          children: [
            const ScreenHeader(title: 'Satılan araçlar', subtitle: 'Sahip olduğun dönemin harcama özeti'),
            MaxWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sold.isEmpty)
                      const AppCard(
                        child: EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Satılan araç yok',
                          text: 'Bir aracını devrettiğinde harcama özeti burada kalır.',
                        ),
                      ),
                    for (final v in sold) ...[
                      _SoldCard(vehicle: v),
                      const SizedBox(height: 12),
                    ],
                    if (sold.isNotEmpty)
                      Text(
                        'Bu araçların harcamaları Harcamalar ekranındaki toplamlarda da görünür.',
                        textAlign: TextAlign.center,
                        style: body(12, color: AppColors.inkSoft),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoldCard extends StatelessWidget {
  const _SoldCard({required this.vehicle});
  final Vehicle vehicle;

  Future<void> _delete(BuildContext context) async {
    final ok = await confirm(
      context,
      title: '${vehicle.plate} kayıtları silinsin mi?',
      message: 'Bu aracın sende kalan harcama kayıtları kalıcı olarak silinir. Yeni sahibindeki kopya etkilenmez.',
    );
    if (!ok || !context.mounted) return;
    StoreScope.read(context).deleteVehicle(vehicle.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = vehicle;
    final recs = store.allRecords.where((r) => r.vehicleId == v.id).toList();
    final total = recs.fold<int>(0, (s, r) => s + r.amountKurus);
    final byCat = <RecordCategory, int>{};
    for (final r in recs) {
      byCat[r.category] = (byCat[r.category] ?? 0) + r.amountKurus;
    }
    final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final from = v.createdAt;
    final to = v.archivedAt ?? DateTime.now();
    final months = ((to.difference(from).inDays) / 30.4).round();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PlateBadge(v.plate, size: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text(v.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w700)),
              ),
              const StatusPill('Satıldı', DueState.ok),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [
              'Devir: ${dateShort(to)}',
              if (v.soldTo != null) v.soldTo!,
            ].join(' · '),
            style: body(12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Mini('Toplam gider', money(total))),
              const SizedBox(width: 8),
              Expanded(child: _Mini('Kayıt', '${recs.length}')),
              const SizedBox(width: 8),
              Expanded(child: _Mini('Sahiplik', months < 1 ? '< 1 ay' : '$months ay')),
            ],
          ),
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final e in cats.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    TintIcon.category(e.key, size: 28),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.key.label, style: body(13, weight: FontWeight.w600))),
                    Text(money(e.value), style: body(13, weight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _delete(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.lateText, minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Kayıtları sil'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, color: AppColors.inkSoft)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: display(15, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
