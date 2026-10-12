// Araç eklenince otomatik yazılan bakım planı kalemleri ve
// bakım kaydında seçilebilen işlemler.
//
// Aralıklar sadece BAŞLANGIÇ ÖNERİSİDİR; kullanıcı kendi aracının
// kullanım kılavuzuna göre bakım planı ekranından düzenleyebilir.

import 'models.dart';

class MaintenancePreset {
  const MaintenancePreset(
    this.key,
    this.name, {
    this.km,
    this.months,
    required this.resetJobs,
  });
  final String key;
  final String name;
  final int? km;
  final int? months;
  final List<String> resetJobs;
}

/// Varsayılan bakım planı: sadece periyodik bakım.
/// Diğer kalemleri (triger, balata, antifriz...) kullanıcı isterse
/// bakım planı ekranından "Kalem ekle" ile ekler.
List<MaintenancePreset> maintenancePresetsFor(VehicleType type, FuelType fuel) {
  if (fuel == FuelType.electric) {
    return const [
      MaintenancePreset('periodic', 'Periyodik bakım (genel kontrol)',
          km: 30000, months: 12, resetJobs: ['general_check']),
    ];
  }
  const oil = ['engine_oil', 'oil_filter'];
  switch (type) {
    case VehicleType.car:
      return const [MaintenancePreset('periodic', 'Periyodik bakım', km: 10000, months: 12, resetJobs: oil)];
    case VehicleType.motorcycle:
      return const [MaintenancePreset('periodic', 'Periyodik bakım', km: 6000, months: 12, resetJobs: oil)];
    case VehicleType.atv:
      return const [MaintenancePreset('periodic', 'Periyodik bakım', km: 3000, months: 12, resetJobs: oil)];
    case VehicleType.van:
    case VehicleType.minibus:
      return const [MaintenancePreset('periodic', 'Periyodik bakım', km: 15000, months: 12, resetJobs: oil)];
    case VehicleType.truck:
    case VehicleType.bus:
      return const [MaintenancePreset('periodic', 'Periyodik bakım', km: 30000, months: 12, resetJobs: oil)];
  }
}

/// Bakım kaydında "Yapılan işlemler" listesi.
List<String> jobsFor(VehicleType type, FuelType fuel) {
  if (fuel == FuelType.electric) {
    return const [
      'general_check',
      'cabin_filter',
      'brake_pads',
      'brake_fluid',
      'ac_service',
      'battery_check',
    ];
  }
  final list = <String>[
    'engine_oil',
    'oil_filter',
    'air_filter',
    if (type != VehicleType.motorcycle && type != VehicleType.atv) 'cabin_filter',
    'fuel_filter',
    if (fuel != FuelType.diesel) 'spark_plug',
    if (type == VehicleType.motorcycle || type == VehicleType.atv) 'chain',
    if (type != VehicleType.motorcycle && type != VehicleType.atv) 'timing_belt',
    'brake_pads',
    'coolant',
    'brake_fluid',
    'battery_check',
    if (fuel == FuelType.gasolineLpg) 'lpg_service',
    if (type == VehicleType.truck || type == VehicleType.bus || type == VehicleType.minibus) 'transmission_oil',
    if (type != VehicleType.motorcycle && type != VehicleType.atv) 'ac_service',
  ];
  return list;
}
