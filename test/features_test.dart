// Marka/model kataloğu ve yeni özelliklerin hesap testleri.
// Çalıştırmak için: flutter test

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:arac_takip/data/models.dart';
import 'package:arac_takip/data/vehicle_catalog.dart';
import 'package:arac_takip/logic/month_summary.dart';
import 'package:arac_takip/logic/true_cost.dart';
import 'package:arac_takip/logic/workshops.dart';

Vehicle _car({String id = 'v1', DateTime? created}) => Vehicle(
      id: id,
      plate: '34 ABC 123',
      type: VehicleType.car,
      brand: 'Renault',
      model: 'Clio',
      fuelType: FuelType.gasoline,
      currentKm: 60000,
      kmUpdatedAt: DateTime.now(),
      createdAt: created ?? DateTime.now().subtract(const Duration(days: 400)),
    );

ExpenseRecord _rec(String vid, RecordCategory c, DateTime d, int kurus, {int? km, String? service}) =>
    ExpenseRecord(
      id: newId(),
      vehicleId: vid,
      category: c,
      date: d,
      amountKurus: kurus,
      km: km,
      serviceName: service,
      createdAt: d,
    );

void main() {
  test('katalog: her araç tipinde marka var, Türkçe arama çalışıyor', () {
    final raw = File('assets/data/vehicle_catalog.json').readAsStringSync();
    final cat = VehicleCatalog.parse(raw);
    for (final t in VehicleType.values) {
      expect(cat[t]!.isNotEmpty, true, reason: '${t.label} için marka yok');
    }
    final cars = cat[VehicleType.car]!;
    final fiat = cars.firstWhere((b) => b.name == 'Fiat');
    expect(fiat.models.contains('Egea'), true);
    expect(searchTr(cars.map((b) => b.name).toList(), 'citroen').first, 'Citroën');
    expect(searchTr(cars.map((b) => b.name).toList(), 'mercedes benz').first, 'Mercedes-Benz');
  });

  test('normalizeTr Türkçe karakterleri ve boşlukları yok sayar', () {
    expect(normalizeTr('Özgür Oto Sanayi'), normalizeTr('ozgur oto  SANAYİ'));
    expect(normalizeTr('Şahin'), 'sahin');
  });

  test('usta defteri aynı ustayı farklı yazımlarda birleştirir', () {
    final d = DateTime(2026, 9, 1);
    final recs = [
      _rec('v1', RecordCategory.maintenance, d, 275000, service: 'Özgür Oto Sanayi'),
      _rec('v1', RecordCategory.maintenance, d.subtract(const Duration(days: 200)), 320000, service: 'ozgur oto sanayi'),
      _rec('v1', RecordCategory.tire, d, 60000, service: 'Lastikçi Mehmet'),
    ];
    final ws = computeWorkshops(recs);
    expect(ws.length, 2);
    expect(ws.first.visits, 2);
    expect(ws.first.totalKurus, 595000);
    expect(ws.first.name, 'Özgür Oto Sanayi');
  });

  test('gerçek maliyet: günlük ve km başı', () {
    final v = _car();
    final now = DateTime.now();
    final recs = [
      _rec('v1', RecordCategory.fuel, now.subtract(const Duration(days: 300)), 365000, km: 50000),
      _rec('v1', RecordCategory.fuel, now.subtract(const Duration(days: 1)), 365000, km: 60000),
    ];
    final c = computeTrueCost(v, recs, CostPeriod.year);
    expect(c.days, 365);
    expect(c.totalKurus, 730000);
    expect(c.perDayKurus, 2000);
    expect(c.km, 10000);
    expect(c.perKmKurus, 73);
  });

  test('ay özeti: toplam ve önceki aya göre değişim', () {
    final v = _car();
    final recs = [
      _rec('v1', RecordCategory.fuel, DateTime(2026, 8, 10), 100000),
      _rec('v1', RecordCategory.maintenance, DateTime(2026, 9, 5), 150000),
      _rec('v1', RecordCategory.fuel, DateTime(2026, 9, 20), 50000),
    ];
    final s = computeMonthSummary(month: DateTime(2026, 9), vehicles: [v], records: recs, reminders: const []);
    expect(s.totalKurus, 200000);
    expect(s.count, 2);
    expect(s.deltaPercent, 100);
    expect(s.highlights.first.title.startsWith('En büyük kalem'), true);
  });
}
