// 3 · Araç detayı: km, bu ay harcama, durum kutuları, bakım planı,
// servis geçmişi, kaza/hasar ve son kayıtlar.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../logic/maintenance.dart';
import '../../logic/reminders.dart';
import '../../logic/true_cost.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import 'accident_screen.dart';
import 'maintenance_plan_screen.dart';
import 'record_add_screen.dart';
import 'service_history_screen.dart';
import 'true_cost_screen.dart';
import 'vehicle_form_screen.dart';

class VehicleDetailScreen extends StatelessWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: VehicleDetailView(vehicleId: vehicleId));
  }
}

class VehicleDetailView extends StatelessWidget {
  const VehicleDetailView({super.key, required this.vehicleId, this.embedded = false});
  final String vehicleId;

  /// Geniş ekranda garajın sağ bölmesinde gösteriliyorsa true (geri butonu yok).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = store.vehicle(vehicleId);
    if (v == null) {
      return const Center(child: Text('Araç bulunamadı'));
    }
    final records = store.recordsFor(v.id);
    final rems = store.remindersFor(v.id);
    final maint = store.maintenanceFor(v);
    final soonMaint = maint.where((m) => m.state != DueState.ok).length;

    return ListView(
      padding: EdgeInsets.only(bottom: bottomSpace(context)),
      children: [
        _Header(vehicle: v, embedded: embedded),
        MaxWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader('Durum'),
                const SizedBox(height: 10),
                _StatusGrid(vehicle: v, reminders: rems, maintenance: maint),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _LinkTile(
                        icon: Icons.build,
                        color: AppColors.catMaint,
                        tint: AppColors.catMaintTint,
                        title: 'Bakım planı',
                        subtitle: soonMaint == 0 ? '${maint.length} kalem' : '$soonMaint yaklaşıyor',
                        subtitleColor: soonMaint == 0 ? null : AppColors.soonText,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => MaintenancePlanScreen(vehicleId: v.id))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LinkTile(
                        icon: Icons.description_outlined,
                        color: AppColors.soonText,
                        tint: AppColors.soonBg,
                        title: 'Servis geçmişi',
                        subtitle: '${records.where((r) => r.category.isServiceHistory).length} kayıt',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ServiceHistoryScreen(vehicleId: v.id))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LinkTile(
                        icon: Icons.car_crash,
                        color: AppColors.catFine,
                        tint: AppColors.catFineTint,
                        title: 'Kaza / hasar',
                        subtitle: '${store.accidentsFor(v.id).length} kayıt',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => AccidentScreen(vehicleId: v.id))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SectionHeader(
                  'Son kayıtlar',
                  trailing: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => RecordAddScreen(vehicleId: v.id))),
                    icon: const Icon(Icons.add, size: 18, color: AppColors.link),
                    label: Text('Ekle', style: body(13, weight: FontWeight.w700, color: AppColors.link)),
                  ),
                ),
                const SizedBox(height: 6),
                if (records.isEmpty)
                  AppCard(
                    child: Text('Henüz kayıt yok. Yakıt, bakım ya da başka bir gideri "+" ile ekleyebilirsin.',
                        style: body(13, color: AppColors.inkSoft)),
                  )
                else
                  for (final r in records.take(6)) ...[
                    RecordTile(record: r),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.vehicle, required this.embedded});
  final Vehicle vehicle;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = vehicle;
    final per100 = store.energyPer100(v);
    final top = embedded ? 16.0 : MediaQuery.paddingOf(context).top + 12;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(embedded ? 0 : 32)),
      ),
      child: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!embedded) ...[
                  SquareIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Geri',
                    light: true,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(child: Align(alignment: Alignment.centerLeft, child: PlateBadge(v.plate))),
                SquareIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Aracı düzenle',
                  light: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VehicleFormScreen(editVehicleId: v.id))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              [v.title, if (v.year != null) '${v.year}', v.fuelType.label].join(' · '),
              style: body(14, color: AppColors.navySoft),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: thousands(v.currentKm),
                          style: display(40, weight: FontWeight.w800, color: Colors.white)),
                      TextSpan(text: '  km', style: body(16, color: AppColors.navySoft)),
                    ])),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => showKmDialog(context, v),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: body(13, weight: FontWeight.w700),
                  ),
                  child: const Text('Km güncelle'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _HeaderStat('Bu ay harcama', money(store.monthTotal(v.id)))),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeaderStat(
                    v.fuelType == FuelType.electric ? 'Şarj / 100 km' : 'Yakıt / 100 km',
                    per100 == null ? '—' : money(per100),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeaderStat(
                    'Gerçek maliyet ›',
                    _perDayText(store, v),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => TrueCostScreen(vehicleId: v.id))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _perDayText(AppStore store, Vehicle v) {
    final c = computeTrueCost(v, store.allRecords, CostPeriod.year);
    if (c.totalKurus == 0) return '—';
    return '${money(c.perDayKurus)}/gün';
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat(this.label, this.value, {this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x1AFFFFFF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label,
                    style: body(12,
                        weight: onTap == null ? FontWeight.w400 : FontWeight.w700,
                        color: onTap == null ? AppColors.navySoft : AppColors.accent)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: display(18, weight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Durum kutuları: kasko, trafik sigortası, muayene, MTV, mevsim lastiği, en yakın bakım.
class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.vehicle, required this.reminders, required this.maintenance});
  final Vehicle vehicle;
  final List<ReminderItem> reminders;
  final List<MaintenanceStatus> maintenance;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final v = vehicle;

    ReminderItem? find(ReminderKind k) {
      for (final r in reminders) {
        if (r.kind == k) return r;
      }
      return null;
    }

    Future<void> editDate(String title, DateTime? current, void Function(DateTime?) set) async {
      final d = await pickDate(context,
          initial: current ?? DateTime.now().add(const Duration(days: 365)));
      if (d == null) return;
      set(d);
      store.updateVehicle(v);
    }

    MaintenanceStatus? nearest;
    for (final m in maintenance) {
      if (m.estimatedDue == null && m.state != DueState.overdue) continue;
      if (nearest == null) {
        nearest = m;
        continue;
      }
      final a = m.estimatedDue ?? DateTime(1970);
      final b = nearest.estimatedDue ?? DateTime(1970);
      if (a.isBefore(b)) nearest = m;
    }

    final mtv = find(ReminderKind.mtv);
    final tire = find(ReminderKind.seasonalTire);

    final tiles = <Widget>[
      _dateTile('Kasko', Icons.shield_outlined, AppColors.catMaint, AppColors.catMaintTint,
          v.cascoEndDate, () => editDate('Kasko', v.cascoEndDate, (d) => v.cascoEndDate = d)),
      _dateTile('Trafik sig.', Icons.verified_user, AppColors.catIns, AppColors.catInsTint,
          v.trafficInsuranceEndDate,
          () => editDate('Trafik', v.trafficInsuranceEndDate, (d) => v.trafficInsuranceEndDate = d)),
      _dateTile('Muayene', Icons.fact_check, AppColors.catInsp, AppColors.catInspTint,
          v.inspectionDueDate,
          () => editDate('Muayene', v.inspectionDueDate, (d) => v.inspectionDueDate = d)),
      _StatusTile(
        label: 'MTV',
        icon: Icons.receipt_long,
        color: AppColors.catTax,
        tint: AppColors.catTaxTint,
        value: mtv == null ? (v.mtvReminder ? 'Ödendi' : 'Kapalı') : mtv.badgeText,
        state: mtv?.state ?? DueState.ok,
        progress: mtv == null ? 1 : _timeProgress(mtv.dueDate, 182),
        sub: mtv == null ? null : mtv.title.replaceFirst('MTV ', ''),
      ),
      _StatusTile(
        label: tire == null ? 'Lastik' : (tire.title.startsWith('Kış') ? 'Kış lastiği' : 'Yaz lastiği'),
        icon: Icons.tire_repair,
        color: AppColors.catTire,
        tint: AppColors.catTireTint,
        value: tire == null ? (v.seasonalTireReminder ? 'Güncel' : 'Kapalı') : tire.badgeText,
        state: tire?.state ?? DueState.ok,
        progress: tire == null ? 1 : _timeProgress(tire.dueDate, 180),
      ),
      _StatusTile(
        label: nearest == null ? 'Bakım' : nearest.item.name.split(' (').first,
        icon: Icons.build,
        color: AppColors.catFuel,
        tint: AppColors.catFuelTint,
        value: nearest == null ? '—' : nearest.leftText,
        state: nearest?.state ?? DueState.ok,
        progress: nearest == null ? 0 : 1 - nearest.used,
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MaintenancePlanScreen(vehicleId: v.id))),
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 520 ? 6 : 3;
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }

  static double _timeProgress(DateTime due, int windowDays) {
    final d = daysBetween(DateTime.now(), due);
    if (d <= 0) return 0;
    return (d / windowDays).clamp(0.0, 1.0);
  }

  Widget _dateTile(String label, IconData icon, Color color, Color tint, DateTime? date,
      VoidCallback onTap) {
    if (date == null) {
      return _StatusTile(
        label: label,
        icon: icon,
        color: color,
        tint: tint,
        value: '+ Ekle',
        valueColor: AppColors.link,
        state: DueState.ok,
        progress: null,
        onTap: onTap,
      );
    }
    final days = daysBetween(DateTime.now(), date);
    final state = days < 0
        ? DueState.overdue
        : days <= 30
            ? DueState.soon
            : DueState.ok;
    return _StatusTile(
      label: label,
      icon: icon,
      color: color,
      tint: tint,
      value: timeLeft(date),
      state: state,
      progress: _timeProgress(date, 365),
      sub: dateNumeric(date),
      onTap: onTap,
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.tint,
    required this.value,
    required this.state,
    required this.progress,
    this.sub,
    this.onTap,
    this.valueColor,
  });
  final String label;
  final IconData icon;
  final Color color;
  final Color tint;
  final String value;
  final DueState state;

  /// Kalan oran (1 = dolu). null ise çubuk yok.
  final double? progress;
  final String? sub;
  final VoidCallback? onTap;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final (fg, _) = stateColors(state);
    final barColor = switch (state) {
      DueState.overdue => const Color(0xFFE5484D),
      DueState.soon => AppColors.accent,
      DueState.ok => AppColors.barGreen,
    };
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintIcon(icon, color, tint, size: 32),
          const SizedBox(height: 8),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(12, weight: FontWeight.w600, color: AppColors.inkSoft)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: display(17,
                    weight: FontWeight.w700,
                    color: valueColor ?? (state == DueState.ok ? AppColors.ink : fg))),
          ),
          if (sub != null)
            Text(sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(11, color: AppColors.inkSoft)),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.color,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.subtitleColor,
  });
  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintIcon(icon, color, tint, size: 36),
          const SizedBox(height: 8),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(13, weight: FontWeight.w700)),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(11,
                  weight: FontWeight.w600, color: subtitleColor ?? AppColors.inkSoft)),
        ],
      ),
    );
  }
}

/// Kayıt satırı (servis geçmişi ve araç detayında). Dokununca düzenleme açılır.
class RecordTile extends StatelessWidget {
  const RecordTile({super.key, required this.record, this.showVehicle = false});
  final ExpenseRecord record;
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final meta = <String>[
      dateShort(r.date),
      if (r.km != null) '${thousands(r.km!)} km',
      if (r.serviceName != null && r.serviceName!.isNotEmpty) r.serviceName!,
    ].join(' · ');
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RecordAddScreen(vehicleId: r.vehicleId, editRecordId: r.id))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintIcon.category(r.category, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(14, weight: FontWeight.w700)),
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(12, color: AppColors.inkSoft)),
                if (r.note != null && r.note!.trim().isNotEmpty && r.category != RecordCategory.other)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(r.note!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: body(12, color: AppColors.inkSoft)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(money(r.amountKurus), style: display(14, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
