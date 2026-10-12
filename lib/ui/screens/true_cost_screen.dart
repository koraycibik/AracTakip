// 16 · Gerçek maliyet: günlük, km başı, aylık; kategori dağılımı ve araç karşılaştırması.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../logic/true_cost.dart';
import '../widgets/common.dart';

class TrueCostScreen extends StatefulWidget {
  const TrueCostScreen({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  State<TrueCostScreen> createState() => _TrueCostScreenState();
}

class _TrueCostScreenState extends State<TrueCostScreen> {
  CostPeriod _period = CostPeriod.year;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = store.vehicle(widget.vehicleId);
    if (v == null) return const Scaffold();
    final split = store.settings.splitLpg;
    final c = computeTrueCost(v, store.allRecords, _period, splitLpg: split);
    final perKm = c.perKmKurus;

    // Karşılaştırma: km başı maliyeti hesaplanabilen tüm araçlar.
    final compare = <(String, double, bool)>[];
    for (final o in store.vehicles) {
      final oc = o.id == v.id ? c : computeTrueCost(o, store.allRecords, _period, splitLpg: split);
      final pk = oc.perKmKurus;
      if (pk != null) compare.add((o.title, pk, o.id == v.id));
    }
    compare.sort((a, b) => b.$2.compareTo(a.$2));
    final maxPk = compare.isEmpty ? 1.0 : compare.first.$2;
    final top = MediaQuery.paddingOf(context).top;

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
                        icon: Icons.arrow_back,
                        tooltip: 'Geri',
                        light: true,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Gerçek maliyet', style: display(22, weight: FontWeight.w800, color: Colors.white)),
                            Text('${v.plate} · ${v.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: body(13, color: AppColors.navySoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Segmented(
                    value: _period,
                    onChanged: (p) => setState(() => _period = p),
                  ),
                  const SizedBox(height: 18),
                  Text('Günlük maliyet', style: body(13, weight: FontWeight.w600, color: AppColors.navySoft)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(c.totalKurus == 0 ? '—' : money(c.perDayKurus),
                        style: display(44, weight: FontWeight.w800, color: Colors.white)),
                  ),
                  Text(
                    c.totalKurus == 0
                        ? 'Bu dönemde gider kaydı yok.'
                        : 'Bu araç sana her gün ortalama bu kadara mal oluyor (${thousands(c.days)} gün).',
                    style: body(13, color: AppColors.navySoft),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _Tile('Km başı', perKm == null ? '—' : moneyPerKm(perKm))),
                      const SizedBox(width: 8),
                      Expanded(child: _Tile('Aylık', money(c.perMonthKurus))),
                      const SizedBox(width: 8),
                      Expanded(child: _Tile('Toplam', money(c.totalKurus))),
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
                  if (c.isShort && c.totalKurus > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.soonBg, borderRadius: BorderRadius.circular(14)),
                      child: Text(
                        'Bu araçla ilgili ${c.days} günlük veri var. Sonuçlar ilk aylarda tek seferlik ödemeler (poliçe, vergi) yüzünden yüksek görünebilir.',
                        style: body(12, weight: FontWeight.w600, color: AppColors.soonText),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(perKm == null ? 'Kullanım giderleri' : 'Km başına kullanım gideri',
                                  style: display(16, weight: FontWeight.w700)),
                            ),
                            Text(c.km > 0 ? '${thousands(c.km)} km' : 'km verisi yok',
                                style: body(12, weight: FontWeight.w600, color: AppColors.inkSoft)),
                          ],
                        ),
                        if (v.fuelType.hasLpg) ...[
                          const SizedBox(height: 8),
                          const Align(alignment: Alignment.centerLeft, child: LpgSplitToggle()),
                        ],
                        const SizedBox(height: 4),
                        Text('Yol yaptıkça artan giderler: yakıt, bakım ve lastik.',
                            style: body(12, color: AppColors.inkSoft)),
                        const SizedBox(height: 8),
                        for (final g in c.usageGroups)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(color: g.color, borderRadius: BorderRadius.circular(3)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(g.label, style: body(14, weight: FontWeight.w600))),
                                Text(money(g.kurus), style: body(14, weight: FontWeight.w700)),
                                if (perKm != null)
                                  SizedBox(
                                    width: 72,
                                    child: Text(moneyPerKm(c.groupPerKm(g)!),
                                        textAlign: TextAlign.right,
                                        style: body(13, weight: FontWeight.w600, color: AppColors.inkSoft)),
                                  ),
                              ],
                            ),
                          ),
                        if (c.usagePerKmKurus != null) ...[
                          const Divider(height: 18, color: AppColors.divider),
                          Row(
                            children: [
                              Expanded(child: Text('Toplam', style: body(14, weight: FontWeight.w800))),
                              Text(money(c.usageKurus), style: body(14, weight: FontWeight.w800)),
                              SizedBox(
                                width: 72,
                                child: Text(moneyPerKm(c.usagePerKmKurus!),
                                    textAlign: TextAlign.right,
                                    style: body(13, weight: FontWeight.w800, color: AppColors.ink)),
                              ),
                            ],
                          ),
                        ],
                        if (perKm == null) ...[
                          const SizedBox(height: 6),
                          Text('Km başı maliyet için kayıtlara km gir ya da kilometreyi düzenli güncelle.',
                              style: body(12, color: AppColors.inkSoft)),
                        ],
                      ],
                    ),
                  ),
                  if (c.fixedGroups.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Sabit giderler', style: display(16, weight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Araç dursa da ödenenler; km\'ye değil zamana göre.',
                              style: body(12, color: AppColors.inkSoft)),
                          const SizedBox(height: 8),
                          for (final g in c.fixedGroups)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: g.color, borderRadius: BorderRadius.circular(3)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(g.label, style: body(14, weight: FontWeight.w600))),
                                  Text(money(g.kurus), style: body(14, weight: FontWeight.w700)),
                                  SizedBox(
                                    width: 84,
                                    child: Text('${money(c.groupPerMonth(g))}/ay',
                                        textAlign: TextAlign.right,
                                        style: body(13, weight: FontWeight.w600, color: AppColors.inkSoft)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (compare.length > 1) ...[
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Araçlarını karşılaştır · km başı', style: display(16, weight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          for (final x in compare)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(x.$1,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: body(14, weight: x.$3 ? FontWeight.w700 : FontWeight.w600)),
                                      ),
                                      Text(moneyPerKm(x.$2), style: body(14, weight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: LinearProgressIndicator(
                                      value: x.$2 / maxPk,
                                      minHeight: 8,
                                      backgroundColor: AppColors.divider,
                                      color: x.$3 ? AppColors.navy : AppColors.inkFaint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Kaza ve hasar tutarları dahil değil. Satın alma bedeli ve değer kaybı hesaba katılmaz.',
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

class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.onChanged});
  final CostPeriod value;
  final ValueChanged<CostPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(CostPeriod p, String label) {
      final sel = p == value;
      return Expanded(
        child: Material(
          color: sel ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(p),
            child: SizedBox(
              height: 40,
              child: Center(
                child: Text(label,
                    style: body(13, weight: FontWeight.w700, color: sel ? AppColors.ink : AppColors.navySoft)),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(13)),
      child: Row(children: [seg(CostPeriod.year, 'Son 12 ay'), seg(CostPeriod.all, 'Eklediğimden beri')]),
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
          Text(label, style: body(12, color: AppColors.navySoft)),
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
