// 1 · Garajım: araç kartları, yaklaşan hatırlatmalar, hesap bağlama kartı.
// Geniş ekranda (Fold açık yatay, tablet) solda liste, sağda seçili aracın detayı.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../logic/maintenance.dart';
import '../../logic/reminders.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import 'reminders_screen.dart';
import 'settings_screen.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_form_screen.dart';

class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key, this.twoPane = false});
  final bool twoPane;

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  String? _selectedId;

  void _open(Vehicle v) {
    if (widget.twoPane) {
      setState(() => _selectedId = v.id);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: v.id)),
      );
    }
  }

  void _addVehicle() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VehicleFormScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final vehicles = store.vehicles;

    final list = _GarageList(
      vehicles: vehicles,
      selectedId: widget.twoPane ? (_selectedId ?? (vehicles.isEmpty ? null : vehicles.first.id)) : null,
      onOpen: _open,
      onAdd: _addVehicle,
    );

    if (!widget.twoPane || vehicles.isEmpty) return list;

    final selected = store.vehicle(_selectedId ?? '') ?? vehicles.first;
    return TwoPane(
      leftOffset: 88,
      start: list,
      end: VehicleDetailView(key: ValueKey(selected.id), vehicleId: selected.id, embedded: true),
    );
  }
}

class _GarageList extends StatelessWidget {
  const _GarageList({
    required this.vehicles,
    required this.selectedId,
    required this.onOpen,
    required this.onAdd,
  });
  final List<Vehicle> vehicles;
  final String? selectedId;
  final ValueChanged<Vehicle> onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final reminders = store.reminders;
    final hasAlert = reminders.any((r) => r.isOverdue || r.daysLeft <= 7);
    final dismissed = store.settings.linkCardDismissedAt;
    final showLink = vehicles.isNotEmpty &&
        (dismissed == null || DateTime.now().difference(dismissed).inDays >= 7);

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomSpace(context)),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${greeting()} · ${dateHeader(DateTime.now())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(13, weight: FontWeight.w500, color: AppColors.inkSoft)),
                  Text('Garajım', style: display(30, weight: FontWeight.w800)),
                ],
              ),
            ),
            SquareIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Ayarlar',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const SizedBox(width: 8),
            SquareIconButton(
              icon: Icons.notifications_none,
              tooltip: 'Hatırlatmalar',
              badge: hasAlert,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const RemindersScreen(standalone: true))),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (showLink) ...[
          _LinkCard(onTap: () => showLinkAccountSheet(context)),
          const SizedBox(height: 14),
        ],
        if (vehicles.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(8),
            child: EmptyState(
              icon: Icons.directions_car,
              title: 'Garajın boş',
              text: 'İlk aracını ekle; muayene, sigorta ve bakım tarihlerini senin yerine takip edelim.',
              action: BigButton(label: 'Araç ekle', icon: Icons.add, dark: true, onPressed: onAdd),
            ),
          )
        else ...[
          _FeaturedCard(
            vehicle: vehicles.first,
            selected: selectedId == vehicles.first.id,
            onTap: () => onOpen(vehicles.first),
          ),
          for (final v in vehicles.skip(1)) ...[
            const SizedBox(height: 10),
            _VehicleRow(vehicle: v, selected: selectedId == v.id, onTap: () => onOpen(v)),
          ],
          const SizedBox(height: 12),
          _AddVehicleButton(onTap: onAdd),
          if (reminders.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionHeader(
              'Yaklaşanlar',
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RemindersScreen(standalone: true))),
                child: Text('Tümü', style: body(13, weight: FontWeight.w700, color: AppColors.link)),
              ),
            ),
            const SizedBox(height: 6),
            for (final r in reminders.take(3)) ...[
              ReminderTile(reminder: r, compact: true),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ],
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.soonBg,
      radius: 18,
      border: Border.all(color: const Color(0xFFF2D08C), width: 1.5),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined, color: AppColors.soonText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verilerini güvenceye al', style: body(14, weight: FontWeight.w700)),
                Text('Telefon değişse de kaybolmasın',
                    style: body(12, color: const Color(0xFF6B4A00))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
            child: Text('Bağla', style: body(13, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Öne çıkan araç kartı (lacivert, plaka, kalan süre halkaları).
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.vehicle, required this.onTap, this.selected = false});
  final Vehicle vehicle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final rems = store.remindersFor(vehicle.id).take(3).toList();

    return Material(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.accent, width: 2.5))
              : null,
          child: Stack(
            children: [
              Positioned(
                right: -60,
                top: -70,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.16),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                top: 30,
                child: Icon(vehicleIcon(vehicle.type), size: 92, color: const Color(0x38FFFFFF)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlateBadge(vehicle.plate),
                    const SizedBox(height: 10),
                    Text(vehicle.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: display(22, weight: FontWeight.w700, color: Colors.white)),
                    Text(
                      [
                        if (vehicle.year != null) '${vehicle.year}',
                        vehicle.fuelType.label,
                        '${thousands(vehicle.currentKm)} km',
                      ].join(' · '),
                      style: body(13, color: AppColors.navySoft),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: rems.isEmpty
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.task_alt, color: AppColors.ringGreen, size: 20),
                                const SizedBox(width: 8),
                                Text('Yaklaşan bir şey yok',
                                    style: body(14, weight: FontWeight.w600, color: Colors.white)),
                              ],
                            )
                          : Row(
                              children: [
                                for (final r in rems)
                                  Expanded(child: _RingItem(reminder: r)),
                                for (var i = rems.length; i < 3; i++) const Expanded(child: SizedBox()),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingItem extends StatelessWidget {
  const _RingItem({required this.reminder});
  final ReminderItem reminder;

  @override
  Widget build(BuildContext context) {
    final days = reminder.daysLeft;
    final value = reminder.isOverdue ? 1.0 : (1 - (days / 365)).clamp(0.05, 1.0);
    final color = switch (reminder.state) {
      DueState.overdue => const Color(0xFFFF6B6B),
      DueState.soon => AppColors.ringOrange,
      DueState.ok => AppColors.ringGreen,
    };
    return Column(
      children: [
        RingProgress(
          value: value.toDouble(),
          color: color,
          center: reminder.isOverdue ? '!' : timeLeftShort(reminder.dueDate),
          size: 54,
        ),
        const SizedBox(height: 6),
        Text(
          _shortTitle(reminder),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: body(12, color: AppColors.navySoft),
        ),
      ],
    );
  }

  String _shortTitle(ReminderItem r) {
    switch (r.kind) {
      case ReminderKind.inspection:
        return 'Muayene';
      case ReminderKind.trafficInsurance:
        return 'Trafik sig.';
      case ReminderKind.casco:
        return 'Kasko';
      case ReminderKind.mtv:
        return 'MTV';
      case ReminderKind.seasonalTire:
        return r.title.startsWith('Kış') ? 'Kış lastiği' : 'Yaz lastiği';
      case ReminderKind.maintenance:
        return r.title.split(' (').first;
      case ReminderKind.recordDue:
        return 'Ceza';
    }
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.vehicle, required this.onTap, this.selected = false});
  final Vehicle vehicle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final rems = store.remindersFor(vehicle.id);
    final next = rems.isEmpty ? null : rems.first;
    final color = vehicle.fuelType == FuelType.electric ? AppColors.catCharge : AppColors.catIns;

    return AppCard(
      radius: 22,
      onTap: onTap,
      border: selected ? Border.all(color: AppColors.accent, width: 2.5) : null,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
            child: Icon(vehicleIcon(vehicle.type), color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: display(15, weight: FontWeight.w700)),
                Text('${vehicle.plate} · ${vehicle.fuelType.label} · ${thousands(vehicle.currentKm)} km',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(12, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (next == null || next.state == DueState.ok)
            const StatusPill('Güncel', DueState.ok)
          else
            StatusPill(_pillText(next), next.state),
        ],
      ),
    );
  }

  String _pillText(ReminderItem r) {
    final t = r.title.split(' ').first;
    return '$t ${r.badgeText}';
  }
}

class _AddVehicleButton extends StatelessWidget {
  const _AddVehicleButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFB7BCCB), width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, color: AppColors.catOther),
              const SizedBox(width: 8),
              Text('Yeni araç ekle', style: body(15, weight: FontWeight.w700, color: AppColors.catOther)),
            ],
          ),
        ),
      ),
    );
  }
}
