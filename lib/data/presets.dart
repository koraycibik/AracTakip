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

List<MaintenancePreset> maintenancePresetsFor(VehicleType type, FuelType fuel) {
  // Elektrikli araçlar: yağ bakımı yok.
  if (fuel == FuelType.electric) {
    if (type == VehicleType.motorcycle || type == VehicleType.atv) {
      return const [
        MaintenancePreset('general_check', 'Genel kontrol',
            months: 12, resetJobs: ['general_check']),
        MaintenancePreset('brake_pads', 'Fren balatası',
            km: 15000, resetJobs: ['brake_pads']),
        MaintenancePreset('brake_fluid', 'Fren hidroliği',
            months: 24, resetJobs: ['brake_fluid']),
      ];
    }
    return const [
      MaintenancePreset('general_check', 'Genel kontrol',
          months: 12, resetJobs: ['general_check']),
      MaintenancePreset('cabin_filter', 'Polen filtresi',
          km: 15000, months: 12, resetJobs: ['cabin_filter']),
      MaintenancePreset('brake_pads', 'Fren balatası',
          km: 60000, resetJobs: ['brake_pads']),
      MaintenancePreset('brake_fluid', 'Fren hidroliği',
          months: 24, resetJobs: ['brake_fluid']),
      MaintenancePreset('ac_service', 'Klima bakımı',
          months: 24, resetJobs: ['ac_service']),
      MaintenancePreset('battery_check', 'Akü (12V) kontrolü',
          months: 12, resetJobs: ['battery_check']),
    ];
  }

  final isGasolineFamily = fuel == FuelType.gasoline ||
      fuel == FuelType.gasolineLpg ||
      fuel == FuelType.lpg ||
      fuel == FuelType.hybrid ||
      fuel == FuelType.pluginHybrid;
  final hasLpg = fuel == FuelType.lpg || fuel == FuelType.gasolineLpg;

  switch (type) {
    case VehicleType.motorcycle:
      return const [
        MaintenancePreset('periodic', 'Periyodik bakım (yağ ve filtre)',
            km: 6000, months: 12, resetJobs: ['engine_oil', 'oil_filter']),
        MaintenancePreset('chain', 'Zincir bakımı',
            km: 5000, months: 6, resetJobs: ['chain']),
        MaintenancePreset('air_filter', 'Hava filtresi',
            km: 12000, months: 24, resetJobs: ['air_filter']),
        MaintenancePreset('spark_plug', 'Buji',
            km: 12000, months: 24, resetJobs: ['spark_plug']),
        MaintenancePreset('brake_pads', 'Fren balatası',
            km: 15000, resetJobs: ['brake_pads']),
        MaintenancePreset('brake_fluid', 'Fren hidroliği',
            months: 24, resetJobs: ['brake_fluid']),
      ];
    case VehicleType.atv:
      return const [
        MaintenancePreset('periodic', 'Periyodik bakım (yağ ve filtre)',
            km: 3000, months: 12, resetJobs: ['engine_oil', 'oil_filter']),
        MaintenancePreset('air_filter', 'Hava filtresi',
            km: 6000, months: 12, resetJobs: ['air_filter']),
        MaintenancePreset('spark_plug', 'Buji',
            km: 6000, months: 24, resetJobs: ['spark_plug']),
        MaintenancePreset('brake_fluid', 'Fren hidroliği',
            months: 24, resetJobs: ['brake_fluid']),
      ];
    case VehicleType.truck:
      return const [
        MaintenancePreset('periodic', 'Periyodik bakım (yağ ve filtreler)',
            km: 30000, months: 12, resetJobs: ['engine_oil', 'oil_filter']),
        MaintenancePreset('fuel_filter', 'Yakıt filtresi',
            km: 30000, months: 12, resetJobs: ['fuel_filter']),
        MaintenancePreset('air_filter', 'Hava filtresi',
            km: 60000, months: 24, resetJobs: ['air_filter']),
        MaintenancePreset('brake_pads', 'Fren balatası',
            km: 60000, resetJobs: ['brake_pads']),
        MaintenancePreset('transmission_oil', 'Şanzıman yağı',
            km: 120000, months: 48, resetJobs: ['transmission_oil']),
        MaintenancePreset('coolant', 'Antifriz ve fren hidroliği',
            months: 24, resetJobs: ['coolant', 'brake_fluid']),
      ];
    case VehicleType.car:
    case VehicleType.van:
      final periodicKm = type == VehicleType.van ? 15000 : 10000;
      return [
        MaintenancePreset('periodic', 'Periyodik bakım (yağ ve filtreler)',
            km: periodicKm, months: 12, resetJobs: const ['engine_oil', 'oil_filter']),
        const MaintenancePreset('air_filter', 'Hava filtresi',
            km: 20000, months: 24, resetJobs: ['air_filter']),
        const MaintenancePreset('cabin_filter', 'Polen filtresi',
            km: 15000, months: 12, resetJobs: ['cabin_filter']),
        const MaintenancePreset('timing_belt', 'Triger seti',
            km: 90000, months: 60, resetJobs: ['timing_belt']),
        const MaintenancePreset('brake_pads', 'Ön fren balatası',
            km: 40000, resetJobs: ['brake_pads']),
        const MaintenancePreset('coolant', 'Antifriz ve fren hidroliği',
            months: 24, resetJobs: ['coolant', 'brake_fluid']),
        if (isGasolineFamily)
          const MaintenancePreset('spark_plug', 'Buji',
              km: 40000, months: 48, resetJobs: ['spark_plug']),
        if (fuel == FuelType.diesel)
          const MaintenancePreset('fuel_filter', 'Yakıt filtresi',
              km: 30000, months: 24, resetJobs: ['fuel_filter']),
        if (hasLpg)
          const MaintenancePreset('lpg_service', 'LPG sistem bakımı',
              km: 20000, months: 12, resetJobs: ['lpg_service']),
        const MaintenancePreset('battery_check', 'Akü kontrolü',
            months: 12, resetJobs: ['battery_check']),
      ];
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
    if (fuel == FuelType.lpg || fuel == FuelType.gasolineLpg) 'lpg_service',
    if (type == VehicleType.truck) 'transmission_oil',
    if (type != VehicleType.motorcycle && type != VehicleType.atv) 'ac_service',
  ];
  return list;
}
