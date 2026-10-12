// Ay sonu özeti: bir takvim ayının toplam gideri, önceki aya göre değişim,
// yapılan yol, yakıt/şarj verimi, öne çıkanlar ve araç bazında dağılım.

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'km.dart';
import 'reminders.dart';

class Highlight {
  Highlight(this.icon, this.color, this.tint, this.title, this.text);
  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String text;
}

class VehicleShare {
  VehicleShare(this.vehicle, this.kurus, this.fraction);
  final Vehicle vehicle;
  final int kurus;
  final double fraction;
}

class MonthSummary {
  MonthSummary({
    required this.month,
    required this.totalKurus,
    required this.prevTotalKurus,
    required this.km,
    required this.count,
    required this.energyPer100Kurus,
    required this.highlights,
    required this.vehicles,
    required this.biggestLabel,
  });

  /// Ayın 1'i.
  final DateTime month;
  final int totalKurus;
  final int prevTotalKurus;
  final int km;
  final int count;
  final int? energyPer100Kurus;
  final List<Highlight> highlights;
  final List<VehicleShare> vehicles;

  /// En büyük kalemin adı (bildirim metni için), yoksa null.
  final String? biggestLabel;

  String get monthName => kMonthsLong[month.month - 1];
  String get prevMonthName => kMonthsLong[(month.month + 10) % 12];

  /// Önceki aya göre yüzde değişim (önceki ay 0 ise null).
  int? get deltaPercent {
    if (prevTotalKurus <= 0) return null;
    return (((totalKurus - prevTotalKurus) / prevTotalKurus) * 100).round();
  }
}

DateTime _monthStart(DateTime d) => DateTime(d.year, d.month);
DateTime _monthEnd(DateTime m) => DateTime(m.year, m.month + 1).subtract(const Duration(milliseconds: 1));

bool _inMonth(DateTime d, DateTime m) => d.year == m.year && d.month == m.month;

int? _energyPer100(List<Vehicle> vehicles, List<ExpenseRecord> records, DateTime m) {
  var spent = 0;
  var km = 0;
  for (final v in vehicles) {
    final s = records
        .where((r) =>
            r.vehicleId == v.id &&
            _inMonth(r.date, m) &&
            (r.category == RecordCategory.fuel || r.category == RecordCategory.charge))
        .fold<int>(0, (a, r) => a + r.amountKurus);
    final k = kmDrivenBetween(v, records, m, _monthEnd(m));
    if (s > 0 && k > 0) {
      spent += s;
      km += k;
    }
  }
  if (km < 50 || spent == 0) return null;
  return (spent * 100 / km).round();
}

/// En eski kaydın ayı (özet ekranında "önceki ay" sınırı).
DateTime firstDataMonth(List<Vehicle> vehicles, List<ExpenseRecord> records) {
  final ids = {for (final v in vehicles) v.id};
  var first = _monthStart(DateTime.now());
  for (final v in vehicles) {
    if (v.createdAt.isBefore(first)) first = _monthStart(v.createdAt);
  }
  for (final r in records) {
    if (ids.contains(r.vehicleId) && r.date.isBefore(first)) first = _monthStart(r.date);
  }
  return first;
}

MonthSummary computeMonthSummary({
  required DateTime month,
  required List<Vehicle> vehicles,
  required List<ExpenseRecord> records,
  required List<ReminderItem> reminders,
}) {
  final m = _monthStart(month);
  final prev = DateTime(m.year, m.month - 1);
  final ids = {for (final v in vehicles) v.id};
  final mine = records.where((r) => ids.contains(r.vehicleId)).toList();
  final inMonth = mine.where((r) => _inMonth(r.date, m)).toList();
  final total = inMonth.fold<int>(0, (s, r) => s + r.amountKurus);
  final prevTotal = mine.where((r) => _inMonth(r.date, prev)).fold<int>(0, (s, r) => s + r.amountKurus);

  var km = 0;
  for (final v in vehicles) {
    km += kmDrivenBetween(v, records, m, _monthEnd(m));
  }
  final per100 = _energyPer100(vehicles, records, m);
  final prevPer100 = _energyPer100(vehicles, records, prev);

  // Araç bazında
  final shares = <VehicleShare>[];
  for (final v in vehicles) {
    final k = inMonth.where((r) => r.vehicleId == v.id).fold<int>(0, (s, r) => s + r.amountKurus);
    if (k > 0) shares.add(VehicleShare(v, k, total == 0 ? 0 : k / total));
  }
  shares.sort((a, b) => b.kurus.compareTo(a.kurus));

  final hs = <Highlight>[];
  String? biggestLabel;

  // 1) En büyük kalem: kategori bazında (bakımda kaydın başlığı ve servis adı).
  if (inMonth.isNotEmpty) {
    final byCat = <RecordCategory, int>{};
    for (final r in inMonth) {
      final c = r.category == RecordCategory.charge ? RecordCategory.fuel : r.category;
      byCat[c] = (byCat[c] ?? 0) + r.amountKurus;
    }
    final top = byCat.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (top.value > 0) {
      final style = categoryStyle(top.key);
      final pct = total == 0 ? 0 : (top.value * 100 / total).round();
      String label;
      String text;
      if (top.key == RecordCategory.maintenance || top.key == RecordCategory.tire) {
        final biggest = inMonth.where((r) => r.category == top.key).reduce((a, b) => a.amountKurus >= b.amountKurus ? a : b);
        label = biggest.title.toLowerCase();
        final where = biggest.serviceName ?? "harcamanın %$pct'i";
        text = '${money(top.value)} · $where';
      } else {
        final fuels = inMonth.where((r) => r.category == RecordCategory.fuel).toList();
        final hasCharge = inMonth.any((r) => r.category == RecordCategory.charge);
        label = top.key == RecordCategory.fuel
            ? (fuels.isEmpty && hasCharge
                ? 'şarj'
                : (!hasCharge && fuels.isNotEmpty && fuels.every((r) => r.isLpg))
                    ? 'LPG'
                    : (!hasCharge && fuels.isNotEmpty && fuels.every((r) => r.fuelKind == 'gasoline'))
                        ? 'benzin'
                        : 'yakıt')
            : top.key.label.toLowerCase();
        text = "${money(top.value)} · harcamanın %$pct'i";
      }
      biggestLabel = label;
      hs.add(Highlight(style.icon, style.color, style.tint, 'En büyük kalem: $label', text));
    }
  }

  // 2) Yakıt / şarj verimi önceki aya göre
  if (per100 != null && prevPer100 != null && prevPer100 > 0) {
    final d = ((per100 - prevPer100) * 100 / prevPer100).round();
    final s = categoryStyle(RecordCategory.fuel);
    if (d < 0) {
      hs.add(Highlight(s.icon, s.color, s.tint, 'Yakıt verimi iyileşti',
          '100 km ${money(per100)}, ${prevMonthNameOf(m)} ayından %${-d} az'));
    } else if (d > 0) {
      hs.add(Highlight(s.icon, s.color, s.tint, '100 km maliyeti arttı',
          '100 km ${money(per100)}, ${prevMonthNameOf(m)} ayından %$d fazla'));
    }
  }

  // 3) Hatırlatmalar: özeti çıkarılan ay en fazla geçen aysa güncel durumu göster.
  final now = DateTime.now();
  final thisMonth = _monthStart(now);
  final isRecent = !m.isBefore(DateTime(thisMonth.year, thisMonth.month - 1));
  if (isRecent) {
    final overdue = reminders.where((r) => r.isOverdue && ids.contains(r.vehicle.id)).toList();
    if (overdue.isEmpty) {
      hs.add(Highlight(Icons.check, AppColors.okText, AppColors.okBg, 'Geciken hatırlatma yok', 'Tüm tarihler zamanında'));
    } else {
      hs.add(Highlight(Icons.error_outline, AppColors.lateText, AppColors.lateBg,
          '${overdue.length} hatırlatma gecikti', overdue.take(2).map((r) => r.title).join(', ')));
    }
    final next = DateTime(m.year, m.month + 1);
    final upcoming = reminders
        .where((r) => !r.isOverdue && ids.contains(r.vehicle.id) && _inMonth(r.dueDate, next))
        .toList();
    if (upcoming.isNotEmpty) {
      final r = upcoming.first;
      hs.add(Highlight(r.icon, AppColors.catIns, AppColors.catInsTint, '${kMonthsLocative[next.month - 1]} seni bekleyen',
          upcoming.length > 1
              ? '${r.title} · ${dayMonth(r.dueDate)} ve ${upcoming.length - 1} kalem daha'
              : '${r.title} · ${dayMonth(r.dueDate)}'));
    }
  }

  return MonthSummary(
    month: m,
    totalKurus: total,
    prevTotalKurus: prevTotal,
    km: km,
    count: inMonth.length,
    energyPer100Kurus: per100,
    highlights: hs,
    vehicles: shares,
    biggestLabel: biggestLabel,
  );
}

String prevMonthNameOf(DateTime m) => kMonthsLong[(m.month + 10) % 12];

/// Bildirim metni: "₺6.100 harcadın, en büyük kalem periyodik bakım."
String monthSummaryNotificationBody(MonthSummary s) {
  if (s.count == 0) return '${s.monthName} ayında kayıt girmedin. Özetine göz at.';
  final big = s.biggestLabel == null ? '' : ', en büyük kalem ${s.biggestLabel}';
  return '${money(s.totalKurus)} harcadın$big.';
}
