// Alt menüdeki "Geçmiş" sekmesi: araç seçici + servis geçmişi.

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../widgets/common.dart';
import 'service_history_screen.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String? _vehicleId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final vehicles = store.vehicles;
    if (vehicles.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.description_outlined,
          title: 'Henüz araç yok',
          text: 'Garajdan araç ekleyince geçmişi burada görürsün.',
        ),
      );
    }
    final selected = store.vehicle(_vehicleId ?? '') ?? vehicles.first;

    final picker = vehicles.length < 2
        ? null
        : SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: vehicles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final v = vehicles[i];
                return PillChoice(
                  label: v.plate,
                  selected: v.id == selected.id,
                  color: AppColors.navy,
                  onTap: () => setState(() => _vehicleId = v.id),
                );
              },
            ),
          );

    return ServiceHistoryBody(
      key: ValueKey(selected.id),
      vehicleId: selected.id,
      header: picker,
    );
  }
}
