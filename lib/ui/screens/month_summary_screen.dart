// 18 · Ay sonu özeti (her ayın 1'indeki bildirimden ya da Harcamalar ekranından açılır).

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../logic/month_summary.dart';
import '../widgets/common.dart';

/// Varsayılan olarak geçen ayı gösterir.
DateTime lastMonth() {
  final n = DateTime.now();
  return DateTime(n.year, n.month - 1);
}

class MonthSummaryScreen extends StatefulWidget {
  const MonthSummaryScreen({super.key, this.month});
  final DateTime? month;

  @override
  State<MonthSummaryScreen> createState() => _MonthSummaryScreenState();
}

class _MonthSummaryScreenState extends State<MonthSummaryScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final m = widget.month ?? lastMonth();
    _month = DateTime(m.year, m.month);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final vehicles = store.vehicles;
    final s = computeMonthSummary(
      month: _month,
      vehicles: vehicles,
      records: store.allRecords,
      reminders: store.reminders,
    );
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final first = firstDataMonth(vehicles, store.allRecords);
    final canPrev = _month.isAfter(first);
    final canNext = _month.isBefore(thisMonth);
    final delta = s.deltaPercent;
    final up = delta != null && delta > 0;
    final top = MediaQuery.paddingOf(context).top;
    final isCurrent = _month == thisMonth;

    return LightStatusBar(
      child: Scaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: bottomSpace(context)),
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, 22),
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: MaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      Opacity(
                        opacity: canPrev ? 1 : 0.35,
                        child: SquareIconButton(
                          icon: Icons.chevron_left,
                          tooltip: 'Önceki ay',
                          light: true,
                          onTap: canPrev ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : () {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      Opacity(
                        opacity: canNext ? 1 : 0.35,
                        child: SquareIconButton(
                          icon: Icons.chevron_right,
                          tooltip: 'Sonraki ay',
                          light: true,
                          onTap: canNext ? () => setState(() => _month = DateTime(_month.year, _month.month + 1)) : () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${s.monthName} ${_month.year != now.year ? '${_month.year} ' : ''}özeti${isCurrent ? ' (devam ediyor)' : ''} · '
                    '${vehicles.length > 1 ? 'tüm araçlar' : (vehicles.isEmpty ? '' : vehicles.first.title)}',
                    style: body(13, weight: FontWeight.w600, color: AppColors.navySoft),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(money(s.totalKurus), style: display(44, weight: FontWeight.w800, color: Colors.white)),
                  ),
                  if (delta != null) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: up ? const Color(0x33FF6B6B) : const Color(0x2E4ADE80),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          delta == 0
                              ? '${kMonthsDative[(_month.month + 10) % 12]} göre aynı'
                              : '${up ? '▲' : '▼'} %${delta.abs()} ${kMonthsDative[(_month.month + 10) % 12]} göre',
                          style: body(12, weight: FontWeight.w700, color: up ? const Color(0xFFFFB3B3) : const Color(0xFF7CF0A6)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _Tile('Yapılan yol', s.km > 0 ? '${thousands(s.km)} km' : '—')),
                      const SizedBox(width: 8),
                      Expanded(child: _Tile('Kayıt', '${s.count}')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Tile('Yakıt / 100 km', s.energyPer100Kurus == null ? '—' : money(s.energyPer100Kurus!)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          MaxWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s.count == 0)
                    const AppCard(
                      child: EmptyState(
                        icon: Icons.event_note,
                        title: 'Bu ay kayıt yok',
                        text: 'Gider ekledikçe ay sonunda sana kısa bir özet hazırlarız.',
                      ),
                    ),
                  if (s.highlights.isNotEmpty) ...[
                    if (s.count == 0) const SizedBox(height: 12),
                    const SectionHeader('Öne çıkanlar'),
                    const SizedBox(height: 8),
                    for (final h in s.highlights) ...[
                      AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            TintIcon(h.icon, h.color, h.tint, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(h.title, style: body(14, weight: FontWeight.w700)),
                                  Text(h.text, style: body(12, color: AppColors.inkSoft)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                  if (s.vehicles.length > 1) ...[
                    const SizedBox(height: 4),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Araç bazında', style: display(16, weight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          for (final x in s.vehicles)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(x.vehicle.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: body(14, weight: FontWeight.w600)),
                                      ),
                                      Text(money(x.kurus), style: body(14, weight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: LinearProgressIndicator(
                                      value: x.fraction,
                                      minHeight: 8,
                                      backgroundColor: AppColors.divider,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
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

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label, style: body(12, color: AppColors.navySoft)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: display(17, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Harcamalar ekranındaki "Ay özeti" kartı.
class MonthSummaryLinkCard extends StatelessWidget {
  const MonthSummaryLinkCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final m = lastMonth();
    final s = computeMonthSummary(
      month: m,
      vehicles: store.vehicles,
      records: store.allRecords,
      reminders: const [],
    );
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MonthSummaryScreen(month: m))),
      child: Row(
        children: [
          const TintIcon(Icons.event_note, AppColors.navy, AppColors.catMaintTint, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.monthName} özeti', style: body(14, weight: FontWeight.w700)),
                Text(
                  s.count == 0 ? 'Geçen ay kayıt yok' : '${money(s.totalKurus)} · ${s.count} kayıt',
                  style: body(12, color: AppColors.inkSoft),
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
