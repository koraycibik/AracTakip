// 1 · Garajım: araç kartları, yaklaşan hatırlatmalar, hesap bağlama kartı.
// Geniş ekranda (Fold açık yatay, tablet) solda liste, sağda seçili aracın detayı.

import 'package:flutter/material.dart';

import '../../core/features.dart';
import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../logic/maintenance.dart';
import '../../services/cloud_service.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import 'forecast_screen.dart';
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
        if (showLink && kCloudEnabled)
          ListenableBuilder(
            listenable: CloudService.instance.user,
            builder: (context, _) => CloudService.instance.isLinked
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _LinkCard(onTap: () => showLinkAccountSheet(context)),
                  ),
          ),
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
          for (var i = 0; i < vehicles.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _VehicleCard(
              vehicle: vehicles[i],
              selected: selectedId == vehicles[i].id,
              onTap: () => onOpen(vehicles[i]),
            ),
          ],
          const SizedBox(height: 12),
          _AddVehicleButton(onTap: onAdd),
          const SizedBox(height: 12),
          const ForecastStrip(),
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

/// Araç kartı (lacivert, plaka, 3 halka: bakım, trafik sigortası, muayene).
/// Garajdaki her araç bu kartla gösterilir.
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.onTap, this.selected = false});
  final Vehicle vehicle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = vehicle;

    // En yakın bakım kalemi (geciken önce, sonra en erken tahmini tarih).
    MaintenanceStatus? maint;
    for (final m in store.maintenanceFor(v)) {
      if (maint == null) {
        maint = m;
        continue;
      }
      if (m.state == DueState.overdue && maint.state != DueState.overdue) {
        maint = m;
        continue;
      }
      if (maint.state == DueState.overdue && m.state != DueState.overdue) continue;
      final a = m.estimatedDue;
      final b = maint.estimatedDue;
      if (a != null && (b == null || a.isBefore(b))) maint = m;
    }

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
                child: Icon(vehicleIcon(v.type), size: 92, color: const Color(0x38FFFFFF)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlateBadge(v.plate, showTr: false),
                    const SizedBox(height: 10),
                    Text(v.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: display(22, weight: FontWeight.w700, color: Colors.white)),
                    Text(
                      [
                        if (v.year != null) '${v.year}',
                        v.fuelType.label,
                        '${thousands(v.currentKm)} km',
                      ].join(' · '),
                      style: body(13, color: AppColors.navySoft),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _maintRing(maint)),
                          Expanded(child: _dateRing('Trafik sigortası', v.trafficInsuranceEndDate)),
                          Expanded(child: _dateRing('Muayene', v.inspectionDueDate)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MonthTotalRow(total: store.monthTotal(v.id)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bakım: halkada kalan ay, altında kalan km.
  Widget _maintRing(MaintenanceStatus? m) {
    if (m == null) {
      return const _DashRing(label: 'Bakım', center: '—', sub: 'Plan yok', value: 0, state: null);
    }
    String center;
    String? unit;
    if (m.state == DueState.overdue) {
      center = '!';
      unit = 'gecikti';
    } else if (m.estimatedDue != null) {
      (center, unit) = timeLeftParts(m.estimatedDue!);
    } else {
      center = '—';
    }
    String sub;
    final km = m.kmRemaining;
    if (km != null) {
      sub = km <= 0 ? '${thousands(-km)} km geçti' : '${thousands(km)} km';
    } else if (m.dueByMonths != null) {
      sub = timeLeft(m.dueByMonths!);
    } else {
      sub = '—';
    }
    return _DashRing(label: 'Bakım', center: center, unit: unit, sub: sub, value: m.used, state: m.state);
  }

  /// Tarihli kalem: halkada kalan süre, altında tarih.
  Widget _dateRing(String label, DateTime? date) {
    if (date == null) {
      return _DashRing(label: label, center: '+', sub: 'Tarih ekle', value: 0, state: null);
    }
    final days = daysBetween(DateTime.now(), date);
    final state = days < 0
        ? DueState.overdue
        : days <= 30
            ? DueState.soon
            : DueState.ok;
    final value = days < 0 ? 1.0 : (1 - days / 365).clamp(0.05, 1.0).toDouble();
    final (center, unit) = timeLeftParts(date);
    return _DashRing(
      label: label,
      center: center,
      unit: unit,
      sub: dateNumeric(date),
      value: value,
      state: state,
    );
  }
}

/// Araç kartının altında: içinde bulunulan ayın toplam gideri.
class _MonthTotalRow extends StatelessWidget {
  const _MonthTotalRow({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    final month = kMonthsLong[DateTime.now().month - 1];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$month ayı gideri',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, color: AppColors.navySoft)),
          ),
          const SizedBox(width: 8),
          Text(money(total), style: display(17, weight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

class _DashRing extends StatelessWidget {
  const _DashRing({
    required this.label,
    required this.center,
    required this.sub,
    required this.value,
    required this.state,
    this.unit,
  });
  final String label;
  final String center;
  final String? unit;
  final String sub;
  final double value;

  /// null: veri yok (soluk halka)
  final DueState? state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      DueState.overdue => const Color(0xFFFF6B6B),
      DueState.soon => AppColors.ringOrange,
      DueState.ok => AppColors.ringGreen,
      null => const Color(0x40FFFFFF),
    };
    final subColor = switch (state) {
      DueState.overdue => const Color(0xFFFFA3A3),
      DueState.soon => const Color(0xFFFFC27A),
      _ => Colors.white,
    };
    return Column(
      children: [
        RingProgress(value: value, color: color, center: center, unit: unit, size: 64),
        const SizedBox(height: 6),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: body(12, color: AppColors.navySoft)),
        Text(sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: body(12, weight: FontWeight.w700, color: subColor)),
      ],
    );
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
