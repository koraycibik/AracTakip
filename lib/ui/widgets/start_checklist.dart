// Garajdaki "Tekerim'i tanı" kartı: yeni kullanıcının ilk adımları.
// Maddeler yapıldıkça kendiliğinden işaretlenir; hepsi bitince ya da kapatılınca kaybolur.

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../screens/maintenance_plan_screen.dart';
import '../screens/record_add_screen.dart';
import '../screens/workshops_screen.dart';
import 'common.dart';
import 'dialogs.dart';

class StartChecklist extends StatelessWidget {
  const StartChecklist({super.key, required this.onAddVehicle});
  final VoidCallback onAddVehicle;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.settings.checklistDismissed || store.vehicles.isEmpty) return const SizedBox.shrink();
    final v = store.vehicles.first;
    final electric = v.fuelType == FuelType.electric;
    final hasEnergy = store.allRecords
        .any((r) => r.category == RecordCategory.fuel || r.category == RecordCategory.charge);

    final items = <_Item>[
      _Item('İlk aracını ekle', 'Plaka, km ve tarihler', true, onAddVehicle),
      _Item(
        electric ? 'İlk şarj kaydını gir' : 'İlk yakıt kaydını gir',
        'Km\'yi de yaz: 100 km maliyetini hesaplarız',
        hasEnergy,
        () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RecordAddScreen(
                vehicleId: v.id, initialCategory: electric ? RecordCategory.charge : RecordCategory.fuel))),
      ),
      _Item('Kilometreni güncelle', 'Bakım tarihi tahmini buna göre düzelir', store.seen('done_km'),
          () => showKmDialog(context, v)),
      _Item('Bakım planına göz at', 'Hangi bakım ne zaman, km ya da ay', store.seen('done_plan'), () {
        store.markSeen('done_plan');
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => MaintenancePlanScreen(vehicleId: v.id)));
      }),
      _Item('Bir ustaya puan ver', 'Bakım kaydına servis adını yaz, sonra puanla', store.hasRatedWorkshop,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkshopsScreen()))),
    ];
    final done = items.where((i) => i.done).length;
    if (done == items.length) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Tekerim\'i tanı', style: display(16, weight: FontWeight.w800))),
              Text('$done/${items.length}', style: body(13, weight: FontWeight.w800, color: AppColors.inkSoft)),
              IconButton(
                tooltip: 'Kapat',
                icon: const Icon(Icons.close, size: 20, color: AppColors.inkSoft),
                onPressed: () => store.updateSettings((s) => s.checklistDismissed = true),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: done / items.length,
                minHeight: 6,
                backgroundColor: AppColors.divider,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (final it in items)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: it.done ? null : it.onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Icon(it.done ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 22, color: it.done ? AppColors.okText : AppColors.inkFaint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.title,
                                style: body(14,
                                    weight: FontWeight.w700,
                                    color: it.done ? AppColors.inkSoft : AppColors.ink)),
                            if (!it.done)
                              Text(it.sub, style: body(12, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                    ),
                    if (!it.done) const Icon(Icons.chevron_right, color: AppColors.inkSoft),
                    const SizedBox(width: 6),
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

class _Item {
  _Item(this.title, this.sub, this.done, this.onTap);
  final String title;
  final String sub;
  final bool done;
  final VoidCallback onTap;
}
