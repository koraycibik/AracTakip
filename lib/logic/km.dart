// Kilometre hesapları: ortalama günlük km ve bir dönemde yapılan yol.

import '../core/format.dart';
import '../data/models.dart';

/// Aracın bilinen tüm km noktaları (elle güncellemeler + km'li kayıtlar).
List<KmPoint> kmPoints(Vehicle v, Iterable<ExpenseRecord> records) {
  final pts = <KmPoint>[
    ...v.kmLog,
    for (final r in records)
      if (r.vehicleId == v.id && r.km != null && r.km! > 0) KmPoint(r.date, r.km!),
  ];
  pts.sort((a, b) => a.date.compareTo(b.date));
  return pts;
}

/// Son 90 günün km'li verilerinden günlük ortalama km.
/// Yeterli veri yoksa (en az 2 nokta ve 1 gün) null döner.
double? avgKmPerDay(Vehicle v, Iterable<ExpenseRecord> records) {
  final all = kmPoints(v, records);
  if (all.length < 2) return null;
  final since = DateTime.now().subtract(const Duration(days: 90));
  var pts = all.where((p) => p.date.isAfter(since)).toList();
  if (pts.length < 2) pts = all;
  final first = pts.first;
  // En yüksek km'yi son nokta kabul et (yanlış sıralı girişlere karşı).
  var last = pts.last;
  for (final p in pts) {
    if (p.km > last.km) last = p;
  }
  final days = last.date.difference(first.date).inHours / 24.0;
  if (days < 1) return null;
  final diff = last.km - first.km;
  if (diff <= 0) return null;
  return diff / days;
}

/// [start, end] aralığında yapılan yol (km).
int kmDrivenBetween(
    Vehicle v, Iterable<ExpenseRecord> records, DateTime start, DateTime end) {
  final all = kmPoints(v, records);
  KmPoint? before;
  final inRange = <KmPoint>[];
  for (final p in all) {
    if (p.date.isBefore(start)) {
      before = p;
    } else if (!p.date.isAfter(end)) {
      inRange.add(p);
    }
  }
  if (before != null) inRange.insert(0, before);
  if (inRange.length < 2) return 0;
  var minKm = inRange.first.km;
  var maxKm = inRange.first.km;
  for (final p in inRange) {
    if (p.km < minKm) minKm = p.km;
    if (p.km > maxKm) maxKm = p.km;
  }
  return maxKm - minKm;
}

/// Son [days] günde yakıt+şarj harcamasının 100 km'ye düşen payı (kuruş). Veri yoksa null.
int? energyCostPer100Km(Vehicle v, Iterable<ExpenseRecord> records, {int days = 90}) {
  final end = DateTime.now();
  final start = dateOnly(end.subtract(Duration(days: days)));
  final km = kmDrivenBetween(v, records, start, end);
  if (km < 50) return null;
  var spent = 0;
  for (final r in records) {
    if (r.vehicleId != v.id) continue;
    if (r.category != RecordCategory.fuel && r.category != RecordCategory.charge) continue;
    if (r.date.isBefore(start) || r.date.isAfter(end)) continue;
    spent += r.amountKurus;
  }
  if (spent == 0) return null;
  return (spent * 100 / km).round();
}
