// 7 · Araç geçmişi raporu (alıcının göreceği salt okunur görünüm).
//
// Bağlantıyla paylaşma Firebase kurulumundan sonra açılacak: rapor anlık
// kopya olarak shares/{id} belgesine yazılacak, alıcı bağlantıyı uygulamada
// açtığında önce tam ekran reklam, sonra bu ekran gösterilecek.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../widgets/common.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = store.vehicle(vehicleId);
    if (v == null) return const Scaffold(body: Center(child: Text('Araç bulunamadı')));

    final service = store.recordsFor(v.id).where((r) => r.category.isServiceHistory).toList();
    final maint = service.where((r) => r.category == RecordCategory.maintenance).toList();
    final accidents = store.accidentsFor(v.id);
    final inspectionOk =
        v.inspectionDueDate != null && !v.inspectionDueDate!.isBefore(today());
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, 22),
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: MaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SquareIconButton(
                        icon: Icons.close,
                        tooltip: 'Kapat',
                        light: true,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x1FFFFFFF),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Sadece görüntüleme',
                                style: body(12, weight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Araç geçmişi raporu',
                      style: body(13, weight: FontWeight.w600, color: AppColors.navySoft)),
                  const SizedBox(height: 8),
                  PlateBadge(v.plate),
                  const SizedBox(height: 8),
                  Text(
                    [v.title, if (v.year != null) '${v.year}'].join(' · '),
                    style: display(22, weight: FontWeight.w700, color: Colors.white),
                  ),
                  Text('${v.type.label} · ${v.fuelType.label} · son kayıtlı km ${thousands(v.currentKm)}',
                      style: body(13, color: AppColors.navySoft)),
                ],
              ),
            ),
          ),
          MaxWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _Stat('Bakım kaydı', '${maint.length}')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat('Son bakım',
                            maint.isEmpty ? '—' : '${kMonthsShort[maint.first.date.month - 1]} ${maint.first.date.year}'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat('Muayene', inspectionOk ? 'Geçerli' : 'Bilinmiyor',
                            good: inspectionOk),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader('Bakım geçmişi'),
                  const SizedBox(height: 8),
                  if (service.isEmpty)
                    AppCard(child: Text('Kayıtlı bakım yok.', style: body(13, color: AppColors.inkSoft)))
                  else
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (var i = 0; i < service.length; i++)
                            _ReportRow(
                              record: service[i],
                              last: i == service.length - 1,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  const SectionHeader('Kaza ve hasar kayıtları'),
                  const SizedBox(height: 8),
                  if (accidents.isEmpty)
                    AppCard(
                        child: Text('Araç sahibi kaza veya hasar kaydı girmemiş.',
                            style: body(13, color: AppColors.inkSoft)))
                  else
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (var i = 0; i < accidents.length; i++)
                            _AccidentRow(accident: accidents[i], last: i == accidents.length - 1),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    'Bilgiler araç sahibi tarafından girilmiştir · Oluşturulma ${dateNumeric(DateTime.now())} · 30 gün geçerli',
                    textAlign: TextAlign.center,
                    style: body(11, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 16),
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
                            'Bu, alıcının göreceği raporun ön izlemesi. Bağlantıyla paylaşma bulut kurulumu tamamlanınca açılacak; alıcı bağlantıyı Araç Takip uygulamasında açacak.',
                            style: body(13, weight: FontWeight.w600, color: const Color(0xFF1B3FA8)),
                          ),
                        ),
                      ],
                    ),
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

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.good = false});
  final String label;
  final String value;
  final bool good;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: good ? AppColors.okBg : AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(11, weight: FontWeight.w600, color: good ? AppColors.okText : AppColors.inkSoft)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: display(17, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.record, required this.last});
  final ExpenseRecord record;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final meta = [
      dateShort(r.date),
      if (r.km != null) '${thousands(r.km!)} km',
      if (r.jobs.isNotEmpty) r.jobs.map(jobLabel).join(', '),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintIcon.category(r.category, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: body(14, weight: FontWeight.w700)),
                Text(meta, style: body(12, color: AppColors.inkSoft)),
                if (r.note != null && r.note!.trim().isNotEmpty)
                  Text(r.note!.trim(), style: body(12, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccidentRow extends StatelessWidget {
  const _AccidentRow({required this.accident, required this.last});
  final Accident accident;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final a = accident;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintIcon(Icons.car_crash, a.damageKurus > 0 ? AppColors.catFine : AppColors.catOther,
              a.damageKurus > 0 ? AppColors.catFineTint : AppColors.catOtherTint,
              size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(dateShort(a.date), style: body(14, weight: FontWeight.w700))),
                    Text(money(a.damageKurus),
                        style: display(14,
                            weight: FontWeight.w700,
                            color: a.damageKurus > 0 ? AppColors.lateText : AppColors.ink)),
                  ],
                ),
                Text(a.description, style: body(12, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
