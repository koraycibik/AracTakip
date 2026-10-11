// Usta defterim: kayıtlardaki servis / usta adlarından otomatik liste.
// Büyük-küçük harf, Türkçe karakter ve boşluk farkları aynı usta sayılır.

import '../data/models.dart';
import '../data/vehicle_catalog.dart' show normalizeTr;

class Workshop {
  Workshop(this.key, this.name);
  final String key;

  /// Görünen ad: en son kayıttaki yazım.
  String name;
  final List<ExpenseRecord> records = [];
  final Set<String> vehicleIds = {};

  int get visits => records.length;
  int get totalKurus => records.fold(0, (s, r) => s + r.amountKurus);
  DateTime get lastDate => records.first.date;

  /// Bu ustada yapılan işlemler (en sık yapılan önce).
  List<String> get jobs {
    final count = <String, int>{};
    for (final r in records) {
      final labels = r.category == RecordCategory.tire
          ? const ['Lastik']
          : (r.jobs.isEmpty ? [r.title] : r.jobs.map(jobLabel));
      for (final l in labels) {
        count[l] = (count[l] ?? 0) + 1;
      }
    }
    final l = count.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
    return l;
  }
}

/// Servis adı girilmiş tüm kayıtlar, ustaya göre gruplanmış (en çok harcama önce).
List<Workshop> computeWorkshops(List<ExpenseRecord> records, {Set<String>? vehicleIds}) {
  final sorted = records
      .where((r) =>
          r.serviceName != null &&
          r.serviceName!.trim().isNotEmpty &&
          (vehicleIds == null || vehicleIds.contains(r.vehicleId)))
      .toList()
    ..sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
  final map = <String, Workshop>{};
  for (final r in sorted) {
    final name = r.serviceName!.trim();
    final key = normalizeTr(name);
    if (key.isEmpty) continue;
    final w = map.putIfAbsent(key, () => Workshop(key, name));
    w.records.add(r);
    w.vehicleIds.add(r.vehicleId);
  }
  final list = map.values.toList()..sort((a, b) => b.totalKurus.compareTo(a.totalKurus));
  return list;
}

/// Kayıt ekranındaki servis adı önerileri: yazılana uyanlar, en son kullanılan önce.
List<String> serviceSuggestions(List<ExpenseRecord> records, String typed, {int limit = 5}) {
  final ws = computeWorkshops(records)..sort((a, b) => b.lastDate.compareTo(a.lastDate));
  final q = normalizeTr(typed);
  final out = <String>[];
  for (final w in ws) {
    if (q.isNotEmpty && (!w.key.contains(q) || w.key == q)) continue;
    out.add(w.name);
    if (out.length >= limit) break;
  }
  return out;
}
