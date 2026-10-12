// 15 · Yaklaşan gider tahmini (90 gün).

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../logic/forecast.dart';
import '../widgets/common.dart';

/// Garaj ve özet ekranlarında kullanılan kısa ad: "Clio", yoksa plaka.
String vehicleShortName(Vehicle v) => v.model.trim().isNotEmpty ? v.model.trim() : v.plate;

ForecastResult forecastFor(AppStore store, {Set<String>? vehicleIds}) {
  final vs = vehicleIds == null
      ? store.vehicles
      : store.vehicles.where((v) => vehicleIds.contains(v.id)).toList();
  return computeForecast(
    vehicles: vs,
    records: store.allRecords,
    items: store.allItems,
    reminders: store.reminders,
  );
}

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key, this.vehicleId});
  final String? vehicleId;

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  Set<String>? _vehicleIds; // null = tüm araçlar

  @override
  void initState() {
    super.initState();
    if (widget.vehicleId != null) _vehicleIds = {widget.vehicleId!};
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final vehicles = store.vehicles;
    final sel = effectiveSelection(_vehicleIds, vehicles);
    final f = forecastFor(store, vehicleIds: sel);
    final multi = sel.length > 1;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(bottom: bottomSpace(context)),
          children: [
            ScreenHeader(
              title: 'Yaklaşan giderler',
              subtitle: '${dayMonth(f.start)} – ${dayMonth(f.end)} · 90 gün',
            ),
            MaxWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (vehicles.length > 1) ...[
                      PlateSelector(
                        vehicles: vehicles,
                        selected: sel,
                        onChanged: (s) => setState(() => _vehicleIds = s),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _TotalCard(result: f),
                    const SizedBox(height: 18),
                    const SectionHeader('Tarihi belli olanlar'),
                    const SizedBox(height: 8),
                    if (f.items.isEmpty)
                      AppCard(
                        child: Text(
                          'Önümüzdeki 90 günde tarihi belli bir gider görünmüyor. Araç detayından muayene ve poliçe tarihlerini eklediğinden emin ol.',
                          style: body(13, color: AppColors.inkSoft),
                        ),
                      )
                    else
                      for (final i in f.items) ...[
                        _FixedRow(item: i, showVehicle: multi),
                        const SizedBox(height: 8),
                      ],
                    const SizedBox(height: 10),
                    const SectionHeader('Düzenli giderler'),
                    const SizedBox(height: 8),
                    _EnergyRow(result: f),
                    const SizedBox(height: 14),
                    _InfoNote(
                      text: 'Tutarlar senin geçmiş kayıtlarından tahmin edilir: poliçe ve vergide son ödediğin tutar, '
                          'bakımda aynı işlemin son tutarı. Geçmişi olmayan kalemler "Bilinmiyor" görünür ve toplama katılmaz.',
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

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.result});
  final ForecastResult result;

  @override
  Widget build(BuildContext context) {
    final months = result.months;
    final max = months.fold<int>(1, (m, e) => e.kurus > m ? e.kurus : m);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Beklenen toplam', style: body(13, weight: FontWeight.w600, color: AppColors.navySoft)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('≈ ${money(result.total)}',
                style: display(32, weight: FontWeight.w800, color: Colors.white)),
          ),
          if (result.unknownCount > 0)
            Text('+ tutarı bilinmeyen ${result.unknownCount} kalem',
                style: body(12, weight: FontWeight.w600, color: AppColors.navySoft)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < months.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(months[i].kurus == 0 ? '—' : money(months[i].kurus),
                            style: body(11, weight: FontWeight.w700, color: Colors.white)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 4 + 52 * (months[i].kurus / max),
                        decoration: BoxDecoration(
                          color: i == 0 ? AppColors.accent : const Color(0x3DFFFFFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(kMonthsShort[months[i].month.month - 1],
                          style: body(12, weight: FontWeight.w600, color: AppColors.navySoft)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FixedRow extends StatelessWidget {
  const _FixedRow({required this.item, required this.showVehicle});
  final ForecastItem item;
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    final r = item.reminder;
    final parts = <String>[
      if (showVehicle) vehicleShortName(item.vehicle),
      '${r.kmRemaining != null && r.dueDate.isAfter(today()) ? '~' : ''}${dayMonth(r.dueDate)}',
      r.isOverdue ? 'gecikti' : timeLeft(r.dueDate),
    ];
    final known = item.amountKurus != null;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        children: [
          TintIcon(item.icon, item.color, item.tint, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: body(14, weight: FontWeight.w700)),
                Text(parts.join(' · '),
                    style: body(12,
                        weight: FontWeight.w500,
                        color: r.isOverdue ? AppColors.lateText : AppColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(known ? '≈ ${money(item.amountKurus!)}' : 'Bilinmiyor',
                  style: display(15, weight: FontWeight.w700, color: known ? AppColors.ink : AppColors.inkFaint)),
              Text(item.basis, style: body(11, color: AppColors.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnergyRow extends StatelessWidget {
  const _EnergyRow({required this.result});
  final ForecastResult result;

  @override
  Widget build(BuildContext context) {
    final s = categoryStyle(RecordCategory.fuel);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        children: [
          TintIcon(s.icon, s.color, s.tint, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yakıt ve şarj', style: body(14, weight: FontWeight.w700)),
                Text(
                  result.hasEnergyHistory
                      ? 'Son dönem ortalaması: ayda ${money(result.energyMonthlyKurus)}'
                      : 'Yakıt / şarj kaydı girdikçe tahmin edilir',
                  style: body(12, weight: FontWeight.w500, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(result.hasEnergyHistory ? '≈ ${money(result.energyTotalKurus)}' : '—',
              style: display(15, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.catMaintTint, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.catMaint),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: body(12, weight: FontWeight.w500, color: AppColors.ink))),
        ],
      ),
    );
  }
}

/// Garajdaki "Önümüzdeki 90 gün beklenen gider" şeridi.
class ForecastStrip extends StatelessWidget {
  const ForecastStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.vehicles.isEmpty) return const SizedBox.shrink();
    final f = forecastFor(store);
    final big = f.biggest;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForecastScreen())),
      child: Row(
        children: [
          const TintIcon(Icons.calendar_month, Color(0xFFB26A00), AppColors.soonBg, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Önümüzdeki 90 gün beklenen gider',
                    style: body(12, weight: FontWeight.w600, color: AppColors.inkSoft)),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: f.total == 0 ? 'Henüz tahmin yok' : '≈ ${money(f.total)}'),
                    if (big != null)
                      TextSpan(
                        text: ' · en büyüğü ${big.reminder.title.toLowerCase()}, '
                            '${big.reminder.isOverdue ? 'gecikti' : timeLeft(big.date)}',
                        style: body(12, weight: FontWeight.w600, color: AppColors.soonText),
                      ),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: display(18, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.ink),
        ],
      ),
    );
  }
}
