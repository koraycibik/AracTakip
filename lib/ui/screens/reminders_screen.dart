// 10 · Hatırlatmalar: en yakın kart, Yaklaşan / Geciken / Tamamlanan.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../logic/maintenance.dart';
import '../../logic/reminders.dart';
import '../widgets/common.dart';
import 'maintenance_plan_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, this.standalone = false, this.onOpenGarage});

  /// Garajdan açıldıysa (alt menü dışında) geri butonu gösterilir.
  final bool standalone;
  final VoidCallback? onOpenGarage;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  int _tab = 0; // 0 yaklaşan, 1 geciken, 2 tamamlanan

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.reminders;
    final upcoming = all.where((r) => !r.isOverdue).toList();
    final overdue = all.where((r) => r.isOverdue).toList();
    final done = store.completedDecisions;
    final nearest = overdue.isNotEmpty ? overdue.first : (upcoming.isEmpty ? null : upcoming.first);

    final content = ListView(
      padding: EdgeInsets.fromLTRB(20, widget.standalone ? 4 : 16, 20, bottomSpace(context)),
      children: [
        MaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.standalone)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Hatırlatmalar', style: display(28, weight: FontWeight.w800)),
                ),
              if (nearest != null) ...[
                _NearestCard(reminder: nearest),
                const SizedBox(height: 14),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PillChoice(
                    label: 'Yaklaşan · ${upcoming.length}',
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  PillChoice(
                    label: 'Geciken · ${overdue.length}',
                    selected: _tab == 1,
                    color: overdue.isEmpty ? AppColors.ink : AppColors.lateText,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  PillChoice(
                    label: 'Tamamlanan',
                    selected: _tab == 2,
                    onTap: () => setState(() => _tab = 2),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (store.vehicles.isEmpty)
                EmptyState(
                  icon: Icons.notifications_none,
                  title: 'Henüz araç yok',
                  text: 'Araç ekleyince muayene, sigorta ve bakım hatırlatmaları burada görünür.',
                  action: widget.onOpenGarage == null
                      ? null
                      : BigButton(label: 'Garaja git', dark: true, onPressed: widget.onOpenGarage),
                )
              else if (_tab == 0)
                ..._list(upcoming, 'Yaklaşan bir şey yok', 'Her şey yolunda görünüyor.')
              else if (_tab == 1)
                ..._list(overdue, 'Geciken yok', 'Tebrikler, hepsi zamanında.')
              else if (done.isEmpty)
                const EmptyState(
                  icon: Icons.task_alt,
                  title: 'Henüz tamamlanan yok',
                  text: 'İşaretlediğin hatırlatmalar burada listelenir.',
                )
              else
                for (final d in done) ...[
                  AppCard(
                    radius: 18,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const TintIcon(Icons.check, AppColors.okText, AppColors.okBg),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.title, style: body(14, weight: FontWeight.w700)),
                              Text(
                                '${store.vehicle(d.vehicleId)?.plate ?? ''} · ${dateLong(d.decidedAt)}',
                                style: body(12, color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                        ),
                        const StatusPill('Yapıldı', DueState.ok),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 8),
              _NotifyInfo(),
            ],
          ),
        ),
      ],
    );

    if (!widget.standalone) return content;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Hatırlatmalar'),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  List<Widget> _list(List<ReminderItem> items, String emptyTitle, String emptyText) {
    if (items.isEmpty) {
      return [EmptyState(icon: Icons.task_alt, title: emptyTitle, text: emptyText)];
    }
    return [
      for (final r in items) ...[
        ReminderTile(reminder: r),
        const SizedBox(height: 8),
      ],
    ];
  }
}

class _NearestCard extends StatelessWidget {
  const _NearestCard({required this.reminder});
  final ReminderItem reminder;

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final days = r.daysLeft;
    final color = switch (r.state) {
      DueState.overdue => const Color(0xFFFF6B6B),
      DueState.soon => AppColors.ringOrange,
      DueState.ok => AppColors.ringGreen,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          RingProgress(
            value: r.isOverdue ? 1 : (1 - days / 365).clamp(0.05, 1.0).toDouble(),
            color: color,
            center: timeLeftParts(r.dueDate).$1,
            unit: timeLeftParts(r.dueDate).$2,
            size: 66,
            stroke: 7,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.isOverdue ? 'Gecikti' : 'En yakın',
                    style: body(12, weight: FontWeight.w600, color: AppColors.navySoft)),
                Text(r.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: display(17, weight: FontWeight.w700, color: Colors.white)),
                Text(r.subtitle, style: body(12, color: AppColors.navySoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hatırlatma satırı + tamamlandı / ertele işlemleri.
class ReminderTile extends StatelessWidget {
  const ReminderTile({super.key, required this.reminder, this.compact = false});
  final ReminderItem reminder;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final style = _styleFor(r.kind);
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(12),
      onTap: r.kind == ReminderKind.maintenance
          ? () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MaintenancePlanScreen(vehicleId: r.vehicle.id)))
          : null,
      child: Row(
        children: [
          TintIcon(r.icon, style.$1, style.$2, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(14, weight: FontWeight.w700)),
                Text(r.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(12, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(r.badgeText, r.state),
          if (!compact) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'İşlemler',
              icon: const Icon(Icons.more_horiz, color: AppColors.inkSoft),
              onSelected: (a) => _action(context, a),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'done', child: Text('Tamamlandı olarak işaretle')),
                const PopupMenuItem(value: 'snooze7', child: Text('1 hafta ertele')),
                const PopupMenuItem(value: 'snooze30', child: Text('1 ay ertele')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _action(BuildContext context, String a) async {
    final store = StoreScope.read(context);
    final r = reminder;
    if (a == 'snooze7') {
      store.snoozeReminder(r, 7);
      toast(context, '1 hafta ertelendi');
      return;
    }
    if (a == 'snooze30') {
      store.snoozeReminder(r, 30);
      toast(context, '1 ay ertelendi');
      return;
    }
    // Tarihli kalemlerde yeni tarihi sor.
    if (r.kind == ReminderKind.inspection ||
        r.kind == ReminderKind.trafficInsurance ||
        r.kind == ReminderKind.casco) {
      final years = r.kind == ReminderKind.inspection ? 2 : 1;
      final suggested = addMonths(r.dueDate, 12 * years);
      final picked = await pickDate(context, initial: suggested, first: DateTime.now());
      if (picked == null) return;
      store.completeReminder(r, newDate: picked);
      if (context.mounted) toast(context, 'Yeni tarih kaydedildi: ${dateLong(picked)}');
      return;
    }
    store.completeReminder(r);
    if (context.mounted) toast(context, 'Tamamlandı');
  }

  (Color, Color) _styleFor(ReminderKind k) {
    switch (k) {
      case ReminderKind.inspection:
        return (AppColors.catInsp, AppColors.catInspTint);
      case ReminderKind.trafficInsurance:
        return (AppColors.catIns, AppColors.catInsTint);
      case ReminderKind.casco:
        return (AppColors.catMaint, AppColors.catMaintTint);
      case ReminderKind.mtv:
        return (AppColors.catTax, AppColors.catTaxTint);
      case ReminderKind.seasonalTire:
        return (AppColors.catTire, AppColors.catTireTint);
      case ReminderKind.maintenance:
        return (AppColors.catFuel, AppColors.catFuelTint);
      case ReminderKind.recordDue:
        return (AppColors.catFine, AppColors.catFineTint);
    }
  }
}

class _NotifyInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context).settings;
    final time = '${s.notifyHour.toString().padLeft(2, '0')}:${s.notifyMinute.toString().padLeft(2, '0')}';
    final leads = s.leadDays.join(', ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: AppColors.ink, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.notificationsEnabled
                  ? 'Bildirimler $leads gün kala ve son gün, saat $time\'da gelir.'
                  : 'Bildirimler kapalı. Ayarlardan açabilirsin.',
              style: body(13, color: AppColors.catOther),
            ),
          ),
        ],
      ),
    );
  }
}
