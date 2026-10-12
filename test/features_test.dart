// Marka/model kataloğu ve yeni özelliklerin hesap testleri.
// Çalıştırmak için: flutter test

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:arac_takip/core/format.dart';
import 'package:arac_takip/data/models.dart';
import 'package:arac_takip/data/vehicle_catalog.dart';
import 'package:arac_takip/data/app_store.dart';
import 'package:arac_takip/logic/month_summary.dart';
import 'package:arac_takip/logic/report.dart';
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

  test('tanıtım: görülen ipuçları saklanır, tur sıfırlanınca tamamlananlar kalır', () {
    final store = AppStore();
    store.markSeen('tour_garage');
    store.markSeen('done_km');
    final copy = AppStore()..replaceAll(store.exportData());
    expect(copy.seen('tour_garage'), true);
    copy.resetTips();
    expect(copy.seen('tour_garage'), false);
    expect(copy.seen('done_km'), true);
  });

  test('rapor: km geçmişi, düşüş tespiti ve son yapılan işlemler', () {
    final v = _car();
    final d = DateTime.now();
    final recs = [
      _rec('v1', RecordCategory.fuel, d.subtract(const Duration(days: 200)), 50000, km: 50000),
      _rec('v1', RecordCategory.maintenance, d.subtract(const Duration(days: 100)), 300000, km: 55000)
        ..jobs = ['timing_belt', 'engine_oil'],
    ];
    final r = computeReport(vehicle: v, records: recs, plan: const []);
    expect(r.kmConsistent, true);
    expect(r.firstKm, 50000);
    expect(r.lastKm, 60000);
    expect(r.kmPerYear, isNotNull);
    expect(r.keyJobs.any((j) => j.label == 'Triger seti' && j.km == 55000), true);

    final bad = computeReport(
      vehicle: v,
      records: [_rec('v1', RecordCategory.fuel, d.subtract(const Duration(days: 10)), 1000, km: 90000)],
      plan: const [],
    );
    expect(bad.kmConsistent, false);
  });

  test('devir: geçmiş yeni sahibe geçer, harcamalara karışmaz; satıcıda arşivlenir', () {
    final seller = AppStore();
    seller.replaceAll({
      'vehicles': [
        {'id': 'v1', 'plate': '34 ABC 1', 'type': 'car', 'brand': 'Fiat', 'model': 'Egea', 'fuelType': 'gasoline',
         'currentKm': 60000, 'trafficInsuranceEndDate': DateTime(2027, 1, 1).toIso8601String()}
      ],
      'records': [
        {'id': 'r1', 'vehicleId': 'v1', 'category': 'maintenance', 'date': DateTime(2026, 3, 1).toIso8601String(),
         'amountKurus': 450000, 'km': 55000, 'jobs': ['timing_belt'], 'serviceName': 'Özgür Oto'},
        {'id': 'r2', 'vehicleId': 'v1', 'category': 'fuel', 'date': DateTime(2026, 9, 1).toIso8601String(),
         'amountKurus': 150000},
      ],
      'workshopReviews': [
        {'key': normalizeTr('Özgür Oto'), 'name': 'Özgür Oto', 'rating': 5, 'note': 'Temiz iş', 'updatedAt': DateTime.now().toIso8601String()}
      ],
    });
    final payload = seller.exportForTransfer('v1');
    expect((payload['records'] as List).length, 1); // yakıt gitmez
    expect((payload['vehicle'] as Map)['trafficInsuranceEndDate'], null);

    final buyer = AppStore();
    final v = buyer.importTransfer(payload, from: 'Koray');
    expect(buyer.vehicles.single.id, v.id);
    expect(buyer.allRecords, isEmpty); // harcamalara karışmaz
    expect(buyer.historyRecords.single.amountKurus, 450000);
    expect(buyer.historyRecords.single.fromPreviousOwner, true);
    expect(buyer.reviewFor(normalizeTr('Özgür Oto'))!.note, 'Temiz iş');

    seller.archiveVehicle('v1', soldTo: 'alici@gmail.com');
    expect(seller.vehicles, isEmpty);
    expect(seller.archivedVehicles.single.soldTo, 'alici@gmail.com');
    expect(seller.allRecords.length, 2); // satıcının harcama özeti kalır
  });

  test('plaka tek tip yazılır', () {
    expect(formatPlate('34abc123'), '34 ABC 123');
    expect(formatPlate('34 a  1234'), '34 A 1234');
    expect(formatPlate('06ıı55'), '06 II 55');
    expect(formatPlate('34A'), '34 A');
    expect(plateKey('34 ABC 123'), '34ABC123');
  });

  test('devir: alıcıda aynı plakalı araç varsa geçmiş onun üzerine eklenir', () {
    final seller = AppStore();
    seller.replaceAll({
      'vehicles': [
        {'id': 'v1', 'plate': '34abc123', 'type': 'car', 'brand': 'Fiat', 'model': 'Egea', 'fuelType': 'gasoline', 'currentKm': 70000}
      ],
      'records': [
        {'id': 'r1', 'vehicleId': 'v1', 'category': 'tire', 'date': DateTime(2026, 4, 1).toIso8601String(), 'amountKurus': 800000, 'km': 65000},
      ],
    });
    final buyer = AppStore();
    buyer.replaceAll({
      'vehicles': [
        {'id': 'b1', 'plate': '34 ABC 123', 'type': 'car', 'brand': '', 'model': '', 'fuelType': 'gasoline', 'currentKm': 60000}
      ],
    });
    final v = buyer.importTransfer(seller.exportForTransfer('v1'), from: 'Koray');
    expect(buyer.vehicles.length, 1);
    expect(v.id, 'b1');
    expect(v.currentKm, 70000);
    expect(v.brand, 'Fiat');
    expect(buyer.historyRecords.single.vehicleId, 'b1');
  });

  test('aynı plakalı iki araç birleşir, kayıtlar eskisine taşınır', () {
    final store = AppStore();
    store.replaceAll({
      'vehicles': [
        {'id': 'old', 'plate': '55 EB 219', 'type': 'car', 'brand': 'Opel', 'model': 'Astra', 'fuelType': 'gasoline_lpg',
         'currentKm': 167522, 'createdAt': DateTime(2026, 9, 1).toIso8601String()},
        {'id': 'new', 'plate': '55EB219', 'type': 'car', 'brand': 'Opel', 'model': 'Astra', 'fuelType': 'gasoline',
         'currentKm': 167000, 'createdAt': DateTime(2026, 10, 12).toIso8601String(),
         'inspectionDueDate': DateTime(2027, 5, 1).toIso8601String()},
      ],
      'records': [
        {'id': 'r1', 'vehicleId': 'new', 'category': 'fuel', 'date': DateTime.now().toIso8601String(), 'amountKurus': 260000},
      ],
      'maintenanceItems': [
        {'id': 'i1', 'vehicleId': 'old', 'presetKey': 'periodic', 'name': 'Periyodik bakım'},
        {'id': 'i2', 'vehicleId': 'new', 'presetKey': 'periodic', 'name': 'Periyodik bakım'},
      ],
    });
    expect(store.vehicles.length, 1);
    final v = store.vehicles.single;
    expect(v.id, 'old');
    expect(v.currentKm, 167522);
    expect(v.inspectionDueDate, DateTime(2027, 5, 1));
    expect(store.allRecords.single.vehicleId, 'old');
    expect(store.itemsFor('old').length, 1);
  });
}
