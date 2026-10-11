// 17 · Usta defterim: kayıtlardaki servis adlarından otomatik oluşan liste.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../logic/workshops.dart';
import '../widgets/common.dart';

const _palette = [
  (AppColors.catMaint, AppColors.catMaintTint),
  (AppColors.catIns, AppColors.catInsTint),
  (AppColors.catTire, AppColors.catTireTint),
  (AppColors.catFuel, AppColors.catFuelTint),
  (AppColors.catCharge, AppColors.catChargeTint),
  (AppColors.catTax, AppColors.catTaxTint),
];

class WorkshopsScreen extends StatefulWidget {
  const WorkshopsScreen({super.key});

  @override
  State<WorkshopsScreen> createState() => _WorkshopsScreenState();
}

class _WorkshopsScreenState extends State<WorkshopsScreen> {
  bool _byRecent = false;
  String? _open;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ids = {for (final v in store.vehicles) v.id};
    final list = computeWorkshops(store.allRecords, vehicleIds: ids);
    if (_byRecent) list.sort((a, b) => b.lastDate.compareTo(a.lastDate));
    _open ??= list.isEmpty ? null : list.first.key;
    final total = list.fold<int>(0, (s, w) => s + w.totalKurus);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(bottom: bottomSpace(context)),
          children: [
            const ScreenHeader(title: 'Usta defterim', subtitle: 'Kayıtlardaki servis adlarından otomatik'),
            MaxWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (list.isEmpty)
                      const AppCard(
                        child: EmptyState(
                          icon: Icons.person_outline,
                          title: 'Henüz usta yok',
                          text: 'Bakım veya lastik kaydı girerken "Servis / usta" alanını doldur; burada kendiliğinden listelenir.',
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text('${list.length} servis · toplam ${money(total)}',
                                style: body(13, weight: FontWeight.w600, color: AppColors.inkSoft)),
                          ),
                          _SortToggle(
                            byRecent: _byRecent,
                            onChanged: (b) => setState(() => _byRecent = b),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < list.length; i++) ...[
                        _WorkshopCard(
                          workshop: list[i],
                          colors: _palette[list[i].key.hashCode.abs() % _palette.length],
                          open: _open == list[i].key,
                          onToggle: () => setState(() => _open = _open == list[i].key ? '' : list[i].key),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.catMaintTint, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: AppColors.catMaint),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Kayıt girerken servis adını yazmaya başlayınca bu listeden öneri çıkar; aynı usta farklı yazımlarla çoğalmaz.',
                              style: body(12, weight: FontWeight.w500),
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
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.byRecent, required this.onChanged});
  final bool byRecent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(bool v, String label) {
      final sel = byRecent == v;
      return Material(
        color: sel ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(v),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(label,
                style: body(12, weight: FontWeight.w700, color: sel ? AppColors.ink : AppColors.inkSoft)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg(false, 'Harcama'), seg(true, 'Son ziyaret')]),
    );
  }
}

class _WorkshopCard extends StatelessWidget {
  const _WorkshopCard({
    required this.workshop,
    required this.colors,
    required this.open,
    required this.onToggle,
  });
  final Workshop workshop;
  final (Color, Color) colors;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final w = workshop;
    final names = [
      for (final id in w.vehicleIds)
        if (store.vehicle(id) != null)
          (store.vehicle(id)!.model.isNotEmpty ? store.vehicle(id)!.model : store.vehicle(id)!.plate),
    ];
    final initial = w.name.characters.first.toUpperCase();
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: colors.$2, borderRadius: BorderRadius.circular(14)),
                    child: Text(initial, style: display(18, weight: FontWeight.w800, color: colors.$1)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.name, style: body(15, weight: FontWeight.w700)),
                        Text('${names.join(', ')} · son: ${dateShort(w.lastDate)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: body(12, color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(money(w.totalKurus), style: display(15, weight: FontWeight.w700)),
                      Text('${w.visits} ziyaret', style: body(12, color: AppColors.inkSoft)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (open) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final j in w.jobs.take(6))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: colors.$2, borderRadius: BorderRadius.circular(99)),
                          child: Text(j, style: body(12, weight: FontWeight.w700, color: colors.$1)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final r in w.records.take(10))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: dateShort(r.date), style: body(13, weight: FontWeight.w700)),
                                TextSpan(
                                  text: ' · ${r.title}${w.vehicleIds.length > 1 && store.vehicle(r.vehicleId) != null ? ' · ${store.vehicle(r.vehicleId)!.plate}' : ''}',
                                  style: body(13, color: AppColors.inkSoft),
                                ),
                              ]),
                            ),
                          ),
                          Text(money(r.amountKurus), style: body(13, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  if (w.records.length > 10)
                    Text('ve ${w.records.length - 10} kayıt daha', style: body(12, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Servis geçmişindeki "Usta defterim" bağlantı kartı.
class WorkshopsLinkCard extends StatelessWidget {
  const WorkshopsLinkCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ids = {for (final v in store.vehicles) v.id};
    final list = computeWorkshops(store.allRecords, vehicleIds: ids);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkshopsScreen())),
      child: Row(
        children: [
          const TintIcon(Icons.person_outline, AppColors.catMaint, AppColors.catMaintTint, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Usta defterim', style: body(14, weight: FontWeight.w700)),
                Text(
                  list.isEmpty ? 'Servis adı girdikçe burada toplanır' : '${list.length} servis · en çok: ${list.first.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
