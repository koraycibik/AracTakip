// İstatistik hesapları: dönem, çubuklar, kategori dağılımı, yapılan yol.
// Kaza/hasar tutarları buraya hiç girmez.

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'km.dart';

enum StatsPeriod {
  week('Hafta'),
  month('Ay'),
  sixMonths('6 Ay'),
  year('Yıl'),
  custom('Özel');

  const StatsPeriod(this.label);
  final String label;
}

class StatsBar {
  StatsBar(this.label, this.start, this.end);
  final String label;
  final DateTime start; // dahil
  final DateTime end; // hariç
  int amountKurus = 0;
}

class CategoryGroup {
  CategoryGroup(this.label, this.icon, this.color, this.tint, this.categories);
  final String label;
  final IconData icon;
  final Color color;
  final Color tint;
  final Set<RecordCategory> categories;
  int amountKurus = 0;
}

class StatsResult {
  StatsResult({
    required this.title,
    required this.start,
    required this.end,
    required this.bars,
    required this.groups,
    required this.totalKurus,
    required this.kmDriven,
    required this.energyPer100Kurus,
  });
  final String title;
  final DateTime start;
  final DateTime end;
  final List<StatsBar> bars;
  final List<CategoryGroup> groups;
  final int totalKurus;
  final int kmDriven;
  final int? energyPer100Kurus;
}

StatsResult computeStats({
  required List<Vehicle> vehicles,
  required List<ExpenseRecord> records,
  required StatsPeriod period,
  DateTimeRange? customRange,
}) {
  final now = DateTime.now();
  final t = today();
  late DateTime start;
  late DateTime end; // hariç
  late String title;
  final bars = <StatsBar>[];

  switch (period) {
    case StatsPeriod.week:
      start = t.subtract(Duration(days: t.weekday - 1));
      end = start.add(const Duration(days: 7));
      title = 'Bu hafta (${dayMonth(start)} – ${dayMonth(end.subtract(const Duration(days: 1)))})';
      for (var i = 0; i < 7; i++) {
        final s = start.add(Duration(days: i));
        bars.add(StatsBar(kWeekdaysShort[i], s, s.add(const Duration(days: 1))));
      }
      break;
    case StatsPeriod.month:
      end = t.add(const Duration(days: 1));
      start = end.subtract(const Duration(days: 28));
      title = 'Son 4 hafta';
      for (var i = 0; i < 4; i++) {
        final s = start.add(Duration(days: i * 7));
        bars.add(StatsBar(dayMonth(s), s, s.add(const Duration(days: 7))));
      }
      break;
    case StatsPeriod.sixMonths:
      start = DateTime(t.year, t.month - 5, 1);
      end = DateTime(t.year, t.month + 1, 1);
      title = 'Son 6 ay';
      for (var i = 0; i < 6; i++) {
        final s = DateTime(start.year, start.month + i, 1);
        bars.add(StatsBar(kMonthsShort[s.month - 1], s, DateTime(s.year, s.month + 1, 1)));
      }
      break;
    case StatsPeriod.year:
      start = DateTime(t.year, t.month - 11, 1);
      end = DateTime(t.year, t.month + 1, 1);
      title = 'Son 12 ay';
      for (var i = 0; i < 12; i++) {
        final s = DateTime(start.year, start.month + i, 1);
        bars.add(StatsBar(kMonthsShort[s.month - 1].substring(0, 1), s,
            DateTime(s.year, s.month + 1, 1)));
      }
      break;
    case StatsPeriod.custom:
      final r = customRange ??
          DateTimeRange(start: t.subtract(const Duration(days: 30)), end: t);
      start = dateOnly(r.start);
      end = dateOnly(r.end).add(const Duration(days: 1));
      title = '${dateShort(start)} – ${dateShort(end.subtract(const Duration(days: 1)))}';
      final days = end.difference(start).inDays;
      if (days <= 14) {
        for (var i = 0; i < days; i++) {
          final s = start.add(Duration(days: i));
          bars.add(StatsBar('${s.day}', s, s.add(const Duration(days: 1))));
        }
      } else if (days <= 120) {
        var s = start;
        while (s.isBefore(end)) {
          var e = s.add(const Duration(days: 7));
          if (e.isAfter(end)) e = end;
          bars.add(StatsBar(dayMonth(s), s, e));
          s = e;
        }
      } else {
        var s = DateTime(start.year, start.month, 1);
        while (s.isBefore(end)) {
          final e = DateTime(s.year, s.month + 1, 1);
          final bs = s.isBefore(start) ? start : s;
          final be = e.isAfter(end) ? end : e;
          bars.add(StatsBar(kMonthsShort[s.month - 1], bs, be));
          s = e;
        }
      }
      break;
  }

  final groups = [
    CategoryGroup('Yakıt ve şarj', Icons.local_gas_station, AppColors.catFuel,
        AppColors.catFuelTint, {RecordCategory.fuel, RecordCategory.charge}),
    CategoryGroup('Bakım ve lastik', Icons.build, AppColors.catMaint,
        AppColors.catMaintTint, {RecordCategory.maintenance, RecordCategory.tire}),
    CategoryGroup('Sigorta ve muayene', Icons.verified_user, AppColors.catIns,
        AppColors.catInsTint, {RecordCategory.insurance, RecordCategory.inspection}),
    CategoryGroup('Vergi, ceza ve diğer', Icons.receipt_long, AppColors.catTax,
        AppColors.catTaxTint, {RecordCategory.tax, RecordCategory.fine, RecordCategory.other}),
  ];

  final vehicleIds = vehicles.map((v) => v.id).toSet();
  var total = 0;
  var energy = 0;
  for (final r in records) {
    if (!vehicleIds.contains(r.vehicleId)) continue;
    if (r.date.isBefore(start) || !r.date.isBefore(end)) continue;
    total += r.amountKurus;
    if (r.category == RecordCategory.fuel || r.category == RecordCategory.charge) {
      energy += r.amountKurus;
    }
    for (final b in bars) {
      if (!r.date.isBefore(b.start) && r.date.isBefore(b.end)) {
        b.amountKurus += r.amountKurus;
        break;
      }
    }
    for (final g in groups) {
      if (g.categories.contains(r.category)) {
        g.amountKurus += r.amountKurus;
        break;
      }
    }
  }

  final rangeEnd = end.isAfter(now) ? now : end;
  var km = 0;
  for (final v in vehicles) {
    km += kmDrivenBetween(v, records, start, rangeEnd);
  }

  groups.sort((a, b) => b.amountKurus.compareTo(a.amountKurus));

  return StatsResult(
    title: title,
    start: start,
    end: end,
    bars: bars,
    groups: groups,
    totalKurus: total,
    kmDriven: km,
    energyPer100Kurus: (km >= 50 && energy > 0) ? (energy * 100 / km).round() : null,
  );
}
