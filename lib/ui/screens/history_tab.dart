// Alt menüdeki "Geçmiş" sekmesi: araç seçici + servis geçmişi.

import 'package:flutter/material.dart';

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
        : PlateSelector(
            vehicles: vehicles,
            selected: {selected.id},
            multi: false,
            onChanged: (s) => setState(() => _vehicleId = s.first),
          );

    return ServiceHistoryBody(
      key: ValueKey(selected.id),
      vehicleId: selected.id,
      header: picker,
    );
  }
}
