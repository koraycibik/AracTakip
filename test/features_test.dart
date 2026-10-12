// Marka/model kataloğu ve yeni özelliklerin hesap testleri.
// Çalıştırmak için: flutter test

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:arac_takip/data/models.dart';
import 'package:arac_takip/data/vehicle_catalog.dart';
import 'package:arac_takip/data/app_store.dart';
import 'package:arac_takip/logic/month_summary.dart';
import 'package:arac_takip/logic/stats.dart';
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
    expect(searchTr(cars.map((b) => b.name).toList(), 'citroen', (s) => s).first, 'Citroën');
    expect(searchTr(cars.map((b) => b.name).toList(), 'mercedes benz', (s) => s).first, 'Mercedes-Benz');
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

  test('LPG ayrı gösterimde yakıt Benzin ve LPG olarak bölünür', () {
    final v = _car()..fuelType = FuelType.gasolineLpg;
    final d = DateTime.now();
    final recs = [
      _rec('v1', RecordCategory.fuel, d, 70000)..fuelKind = 'lpg',
      _rec('v1', RecordCategory.fuel, d, 30000)..fuelKind = 'gasoline',
    ];
    final split = computeStats(vehicles: [v], records: recs, period: StatsPeriod.week, splitLpg: true);
    final lpg = split.groups.firstWhere((g) => g.label == 'LPG');
    final benzin = split.groups.firstWhere((g) => g.label == 'Benzin');
    expect(lpg.amountKurus, 70000);
    expect(benzin.amountKurus, 30000);
    final together = computeStats(vehicles: [v], records: recs, period: StatsPeriod.week);
    expect(together.groups.firstWhere((g) => g.label == 'Yakıt ve şarj').amountKurus, 100000);
  });

  test('eski LPG araçlar Benzin + LPG olur, türü boş yakıt kayıtları LPG sayılır', () {
    final store = AppStore();
    store.replaceAll({
      'vehicles': [
        {'id': 'v9', 'plate': '06 AB 1', 'type': 'car', 'brand': 'Fiat', 'model': 'Egea', 'fuelType': 'lpg', 'currentKm': 1000}
      ],
      'records': [
        {'id': 'r1', 'vehicleId': 'v9', 'category': 'fuel', 'date': DateTime.now().toIso8601String(), 'amountKurus': 5000}
      ],
    });
    expect(store.vehicles.single.fuelType, FuelType.gasolineLpg);
    expect(store.allRecords.single.isLpg, true);
  });

  test('usta puanı ve notu kaydedilir, boşalınca silinir', () {
    final store = AppStore();
    final key = normalizeTr('Özgür Oto');
    store.saveReview(WorkshopReview(key: key, name: 'Özgür Oto', rating: 4, note: 'Temiz iş', city: 'Bursa', updatedAt: DateTime.now()));
    final copy = AppStore()..replaceAll(store.exportData());
    final r = copy.reviewFor(key)!;
    expect(r.rating, 4);
    expect(r.note, 'Temiz iş');
    expect(r.city, 'Bursa');
    store.saveReview(WorkshopReview(key: key, name: 'Özgür Oto', updatedAt: DateTime.now()));
    expect(store.reviewFor(key), null);
  });
}
