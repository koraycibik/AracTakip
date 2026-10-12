// 9 · Harcamalar (eski adıyla İstatistik): Hafta / Ay / 6 Ay / Yıl / Özel, araç filtresi,
// çubuk grafik, kategori dağılımı. Kaza tutarları dahil edilmez.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../logic/stats.dart';
import '../widgets/common.dart';
import 'month_summary_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatsPeriod _period = StatsPeriod.sixMonths;
  DateTimeRange? _custom;
  Set<String>? _vehicleIds; // null = tüm araçlar

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDateRange: _custom ??
          DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      locale: const Locale('tr'),
      helpText: 'Tarih aralığı seç',
      saveText: 'Uygula',
    );
    if (r != null) {
      setState(() {
        _custom = r;
        _period = StatsPeriod.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final allVehicles = store.vehicles;
    final sel = effectiveSelection(_vehicleIds, allVehicles);
    final vehicles = allVehicles.where((v) => sel.contains(v.id)).toList();

    final res = computeStats(
      vehicles: vehicles,
      records: store.allRecords,
      period: _period,
      customRange: _custom,
      splitLpg: store.settings.splitLpg,
    );
    final showLpgToggle = vehicles.any((v) => v.fuelType.hasLpg);
    final maxGroup = res.groups.isEmpty
        ? 0
        : res.groups.map((g) => g.amountKurus).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomSpace(context)),
      children: [
        MaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Harcamalar', style: display(28, weight: FontWeight.w800))),
                ],
              ),
              if (allVehicles.length > 1) ...[
                const SizedBox(height: 10),
                PlateSelector(
                  vehicles: allVehicles,
                  selected: sel,
                  onChanged: (s) => setState(() => _vehicleIds = s),
                ),
              ],
              if (allVehicles.isNotEmpty) ...[
                const SizedBox(height: 12),
                const MonthSummaryLinkCard(),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final p in StatsPeriod.values) ...[
                    Expanded(
                      child: _PeriodButton(
                        label: p.label,
                        selected: _period == p,
                        onTap: () {
                          if (p == StatsPeriod.custom) {
                            _pickRange();
                          } else {
                            setState(() => _period = p);
                          }
                        },
                      ),
                    ),
                    if (p != StatsPeriod.values.last) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _ChartCard(result: res),
              const SizedBox(height: 14),
              AppCard(
                radius: 24,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Nereye harcadım?', style: display(16, weight: FontWeight.w700))),
                        if (showLpgToggle) const LpgSplitToggle(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (res.totalKurus == 0)
                      Text('Bu dönemde kayıt yok.', style: body(13, color: AppColors.inkSoft))
                    else
                      for (final g in res.groups.where((g) => g.amountKurus > 0)) ...[
                        Row(
                          children: [
                            TintIcon(g.icon, g.color, g.tint, size: 30),
                            const SizedBox(width: 10),
                            Expanded(child: Text(g.label, style: body(14, weight: FontWeight.w600))),
                            Text(money(g.amountKurus), style: body(14, weight: FontWeight.w700)),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '%${(g.amountKurus * 100 / res.totalKurus).round()}',
                                textAlign: TextAlign.right,
                                style: body(13, color: AppColors.inkSoft),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 40, top: 6, bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: maxGroup == 0 ? 0 : g.amountKurus / maxGroup,
                              minHeight: 6,
                              backgroundColor: AppColors.divider,
                              valueColor: AlwaysStoppedAnimation(g.color),
                            ),
                          ),
                        ),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Yakıt ve şarj / 100 km',
                      value: res.energyPer100Kurus == null ? '—' : money(res.energyPer100Kurus!),
                      color: AppColors.catFuelTint,
                      textColor: const Color(0xFF8A3505),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: 'Yapılan yol',
                      value: '${thousands(res.kmDriven)} km',
                      color: AppColors.catMaintTint,
                      textColor: const Color(0xFF1B3FA8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.ink : AppColors.border, width: 2),
          ),
          child: Text(label,
              maxLines: 1,
              style: body(13, weight: FontWeight.w700, color: selected ? Colors.white : AppColors.ink)),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.result});
  final StatsResult result;

  @override
  Widget build(BuildContext context) {
    final bars = result.bars;
    final maxV = bars.isEmpty ? 0 : bars.map((b) => b.amountKurus).reduce((a, b) => a > b ? a : b);
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.title, style: body(13, color: AppColors.navySoft)),
                    Text(money(result.totalKurus),
                        style: display(32, weight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x1FFFFFFF),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('${thousands(result.kmDriven)} km yol',
                    style: body(12, weight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final b in bars)
                  Expanded(
                    child: Tooltip(
                      message: '${b.label}: ${money(b.amountKurus)}',
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: bars.length > 8 ? 2 : 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: maxV == 0 ? 4 : 4 + 96 * (b.amountKurus / maxV),
                              decoration: BoxDecoration(
                                color: (!now.isBefore(b.start) && now.isBefore(b.end))
                                    ? AppColors.accent
                                    : const Color(0x3DFFFFFF),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8), bottom: Radius.circular(3)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(b.label,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                softWrap: false,
                                style: body(bars.length > 8 ? 9.5 : 11, color: AppColors.navySoft)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color, required this.textColor});
  final String label;
  final String value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: body(12, weight: FontWeight.w600, color: textColor)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: display(22, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
