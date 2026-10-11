import 'package:flutter_test/flutter_test.dart';

import 'package:arac_takip/core/format.dart';
import 'package:arac_takip/data/models.dart';
import 'package:arac_takip/logic/maintenance.dart';

void main() {
  test('para biçimi ve okuma', () {
    expect(money(150000), '₺1.500');
    expect(money(184415), '₺1.844,15');
    expect(parseMoney('1.500'), 150000);
    expect(parseMoney('1500,50'), 150050);
    expect(parseMoney('1500.5'), 150050);
    expect(parseMoney('abc'), null);
  });

  test('km biçimi', () {
    expect(thousands(84250), '84.250');
    expect(parseKm('84.250'), 84250);
  });

  test('ay ekleme ay sonunu taşırmaz', () {
    expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
  });

  test('bakım kalemi km dolunca gecikmiş olur', () {
    final v = Vehicle(
      id: 'v1',
      plate: '34 ABC 123',
      type: VehicleType.car,
      brand: 'Fiat',
      model: 'Egea',
      fuelType: FuelType.gasoline,
      currentKm: 21000,
      kmUpdatedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    final item = MaintenanceItem(
      id: 'i1',
      vehicleId: 'v1',
      name: 'Periyodik bakım',
      intervalKm: 10000,
      intervalMonths: 12,
      lastDoneKm: 10000,
      lastDoneDate: DateTime.now(),
    );
    final s = maintenanceStatus(item, v, 40);
    expect(s.state, DueState.overdue);
    expect(s.kmRemaining, -1000);
  });
}
