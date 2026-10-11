// Yaklaşan gider tahmini: önümüzdeki N günde tarihi belli giderler
// (poliçe, muayene, MTV, lastik, bakım, ceza) + düzenli yakıt/şarj ortalaması.
// Tutarlar kullanıcının kendi geçmiş kayıtlarından tahmin edilir.

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'reminders.dart';

class ForecastItem {
  ForecastItem({
    required this.reminder,
    required this.amountKurus,
    required this.basis,
    required this.icon,
    required this.color,
    required this.tint,
  });

  final ReminderItem reminder;

  /// Tahmini tutar; geçmişi yoksa null ("Bilinmiyor").
  final int? amountKurus;

  /// Tutarın dayanağı: "geçen yıl", "son muayene", "ilk kez" …
  final String basis;
  final IconData icon;
  final Color color;
  final Color tint;

  Vehicle get vehicle => reminder.vehicle;
  DateTime get date => reminder.dueDate;
}

class ForecastMonth {
  ForecastMonth(this.month, this.kurus);
  final DateTime month; // ayın 1'i
  int kurus;
}

class ForecastResult {
  ForecastResult({
    required this.start,
    required this.end,
    required this.items,
    required this.energyMonthlyKurus,
    required this.energyTotalKurus,
    required this.hasEnergyHistory,
    required this.months,
  });

  final DateTime start;
  final DateTime end;
  final List<ForecastItem> items;

  /// Son dönemin ortalamasıyla aylık (30 gün) yakıt + şarj.
  final int energyMonthlyKurus;

  /// Tahmin aralığındaki yakıt + şarj toplamı.
  final int energyTotalKurus;
  final bool hasEnergyHistory;
  final List<ForecastMonth> months;

  int get fixedTotal => items.fold(0, (s, i) => s + (i.amountKurus ?? 0));
  int get total => fixedTotal + energyTotalKurus;
  int get unknownCount => items.where((i) => i.amountKurus == null).length;

  /// Tutarı en büyük kalem (garaj şeridinde "en büyüğü kasko, 9 gün").
  ForecastItem? get biggest {
    ForecastItem? b;
    for (final i in items) {
      if ((i.amountKurus ?? 0) <= 0) continue;
      if (b == null || i.amountKurus! > b.amountKurus!) b = i;
    }
    return b;
  }
}

/// [vehicles] içindeki araçlar için tahmin. [reminders] AppStore.reminders'tan gelir
/// (kullanıcının tamamladığı / ertelediği hatırlatmalar zaten çıkarılmıştır).
ForecastResult computeForecast({
  required List<Vehicle> vehicles,
  required List<ExpenseRecord> records,
  required List<MaintenanceItem> items,
  required List<ReminderItem> reminders,
  int days = 90,
}) {
  final start = today();
  final end = start.add(Duration(days: days - 1));
  final ids = {for (final v in vehicles) v.id};
  final recs = records.where((r) => ids.contains(r.vehicleId)).toList()
    ..sort((a, b) => b.date.compareTo(a.date)); // yeniden eskiye

  ExpenseRecord? lastWhere(String vehicleId, bool Function(ExpenseRecord) test) {
    for (final r in recs) {
      if (r.vehicleId == vehicleId && test(r)) return r;
    }
    return null;
  }

  // Tutarın dayanağı: kayıt yaklaşık 1 yıl önceyse "geçen yıl".
  String basisFor(ExpenseRecord r, String fallback) {
    final d = daysBetween(r.date, DateTime.now());
    if (d >= 300 && d <= 430) return 'geçen yıl';
    return fallback;
  }

  final out = <ForecastItem>[];
  for (final rem in reminders) {
    if (!ids.contains(rem.vehicle.id)) continue;
    if (rem.dueDate.isAfter(end)) continue;
    final vid = rem.vehicle.id;
    ExpenseRecord? src;
    String basis;
    CategoryStyle style;
    switch (rem.kind) {
      case ReminderKind.trafficInsurance:
        src = lastWhere(vid, (r) => r.category == RecordCategory.insurance && r.insuranceKind == 'traffic');
        basis = src == null ? 'ilk kez' : basisFor(src, 'son poliçe');
        style = categoryStyle(RecordCategory.insurance);
      case ReminderKind.casco:
        src = lastWhere(vid, (r) => r.category == RecordCategory.insurance && r.insuranceKind == 'casco');
        basis = src == null ? 'ilk kez' : basisFor(src, 'son poliçe');
        style = const CategoryStyle(Icons.shield_outlined, AppColors.catMaint, AppColors.catMaintTint);
      case ReminderKind.inspection:
        src = lastWhere(vid, (r) => r.category == RecordCategory.inspection);
        basis = src == null ? 'ilk kez' : 'son muayene';
        style = categoryStyle(RecordCategory.inspection);
      case ReminderKind.mtv:
        src = lastWhere(vid, (r) => r.category == RecordCategory.tax);
        basis = src == null ? 'ilk kez' : 'son taksit';
        style = categoryStyle(RecordCategory.tax);
      case ReminderKind.seasonalTire:
        src = lastWhere(vid, (r) => r.category == RecordCategory.tire);
        basis = src == null ? 'ilk kez' : 'geçen sezon';
        style = categoryStyle(RecordCategory.tire);
      case ReminderKind.maintenance:
        MaintenanceItem? item;
        for (final i in items) {
          if (i.id == rem.sourceId) item = i;
        }
        final jobs = item?.resetJobs.toSet() ?? const <String>{};
        src = jobs.isEmpty
            ? null
            : lastWhere(vid, (r) => r.category == RecordCategory.maintenance && r.jobs.any(jobs.contains));
        basis = src == null ? 'ilk kez' : 'son yapılan';
        style = categoryStyle(RecordCategory.maintenance);
      case ReminderKind.recordDue:
        for (final r in recs) {
          if (r.id == rem.sourceId) src = r;
        }
        basis = 'kayıtlı tutar';
        style = categoryStyle(src?.category ?? RecordCategory.fine);
    }
    out.add(ForecastItem(
      reminder: rem,
      amountKurus: src?.amountKurus,
      basis: basis,
      icon: style.icon,
      color: style.color,
      tint: style.tint,
    ));
  }
  out.sort((a, b) => a.date.compareTo(b.date));

  // Yakıt + şarj: son 90 günün günlük ortalaması (araç daha yeniyse ilk kayıttan bu yana).
  var perDay = 0.0;
  var hasHistory = false;
  for (final v in vehicles) {
    final energy = recs
        .where((r) =>
            r.vehicleId == v.id &&
            (r.category == RecordCategory.fuel || r.category == RecordCategory.charge))
        .toList();
    if (energy.isEmpty) continue;
    final windowStart = start.subtract(const Duration(days: 90));
    final inWindow = energy.where((r) => !r.date.isBefore(windowStart)).toList();
    if (inWindow.isEmpty) continue;
    hasHistory = true;
    final first = inWindow.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);
    var span = daysBetween(first, start) + 1;
    if (span < 14) span = 14; // tek bir dolumla aşırı tahmin yapma
    if (span > 90) span = 90;
    final sum = inWindow.fold<int>(0, (s, r) => s + r.amountKurus);
    perDay += sum / span;
  }

  // Aylara dağıt.
  final months = <ForecastMonth>[];
  var m = DateTime(start.year, start.month);
  while (!m.isAfter(end)) {
    months.add(ForecastMonth(m, 0));
    m = DateTime(m.year, m.month + 1);
  }
  ForecastMonth monthOf(DateTime d) {
    for (final fm in months.reversed) {
      if (!d.isBefore(fm.month)) return fm;
    }
    return months.first; // gecikmiş kalemler bu aya
  }

  for (final i in out) {
    monthOf(i.date).kurus += i.amountKurus ?? 0;
  }
  var energyTotal = 0;
  for (final fm in months) {
    final mStart = fm.month.isBefore(start) ? start : fm.month;
    final next = DateTime(fm.month.year, fm.month.month + 1);
    final mEnd = next.subtract(const Duration(days: 1));
    final last = mEnd.isAfter(end) ? end : mEnd;
    final d = daysBetween(mStart, last) + 1;
    final k = (perDay * d).round();
    fm.kurus += k;
    energyTotal += k;
  }

  return ForecastResult(
    start: start,
    end: end,
    items: out,
    energyMonthlyKurus: (perDay * 30).round(),
    energyTotalKurus: energyTotal,
    hasEnergyHistory: hasHistory,
    months: months,
  );
}
