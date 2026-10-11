// Bakım planı kaleminin durumu: kalan km / süre, tahmini tarih, doluluk.

import '../core/format.dart';
import '../data/models.dart';

enum DueState { ok, soon, overdue }

class MaintenanceStatus {
  MaintenanceStatus({
    required this.item,
    required this.kmRemaining,
    required this.dueByMonths,
    required this.dueByKm,
    required this.estimatedDue,
    required this.used,
    required this.state,
  });

  final MaintenanceItem item;

  /// Kalan km (km kuralı yoksa null). Negatifse geçmiş.
  final int? kmRemaining;

  /// Süre kuralına göre bitiş tarihi.
  final DateTime? dueByMonths;

  /// Ortalama kullanıma göre km'nin dolacağı tahmini tarih.
  final DateTime? dueByKm;

  /// Hangisi önce gelirse.
  final DateTime? estimatedDue;

  /// 0..1 doluluk.
  final double used;
  final DueState state;

  /// "5.750 km" / "1 ay" / "5 gün geçti"
  String get leftText {
    final timeFirst = kmRemaining == null ||
        (dueByMonths != null && dueByKm != null && dueByMonths!.isBefore(dueByKm!));
    if (state == DueState.overdue) {
      if (kmRemaining != null && kmRemaining! <= 0) {
        return '${thousands(-kmRemaining!)} km geçti';
      }
      if (dueByMonths != null) return timeLeft(dueByMonths!);
    }
    if (timeFirst && dueByMonths != null) return timeLeft(dueByMonths!);
    if (kmRemaining != null) return '${thousands(kmRemaining!)} km';
    return '—';
  }

  /// "~ Mayıs 2027" / "Kasım 2026"
  String get whenText {
    final d = estimatedDue;
    if (d == null) return 'Km verisi bekleniyor';
    final approx = dueByKm != null && (dueByMonths == null || dueByKm!.isBefore(dueByMonths!));
    return '${approx ? '~ ' : ''}${kMonthsLong[d.month - 1]} ${d.year}';
  }
}

MaintenanceStatus maintenanceStatus(
  MaintenanceItem item,
  Vehicle v,
  double? avgKmPerDay,
) {
  final now = today();
  final baseKm = item.lastDoneKm ?? v.currentKm;
  final baseDate = dateOnly(item.lastDoneDate ?? v.createdAt);

  int? kmRemaining;
  double usedKm = 0;
  if (item.intervalKm != null && item.intervalKm! > 0) {
    kmRemaining = baseKm + item.intervalKm! - v.currentKm;
    usedKm = (v.currentKm - baseKm) / item.intervalKm!;
  }

  DateTime? dueByMonths;
  double usedTime = 0;
  if (item.intervalMonths != null && item.intervalMonths! > 0) {
    dueByMonths = addMonths(baseDate, item.intervalMonths!);
    final total = dueByMonths.difference(baseDate).inDays;
    if (total > 0) usedTime = now.difference(baseDate).inDays / total;
  }

  DateTime? dueByKm;
  if (kmRemaining != null && avgKmPerDay != null && avgKmPerDay > 0) {
    final days = kmRemaining > 0 ? (kmRemaining / avgKmPerDay).round() : 0;
    // Çok uzak tahminleri sınırla (10 yıl).
    dueByKm = now.add(Duration(days: days.clamp(0, 3650)));
  }

  DateTime? estimated;
  for (final d in [dueByMonths, dueByKm]) {
    if (d == null) continue;
    if (estimated == null || d.isBefore(estimated)) estimated = d;
  }

  var used = usedKm > usedTime ? usedKm : usedTime;
  if (used < 0) used = 0;
  if (used > 1) used = 1;

  final kmOver = kmRemaining != null && kmRemaining <= 0;
  final timeOver = dueByMonths != null && dueByMonths.isBefore(now);
  DueState state;
  if (kmOver || timeOver) {
    state = DueState.overdue;
  } else {
    final kmSoonLimit =
        item.intervalKm == null ? 0 : (item.intervalKm! * 0.1).clamp(500, 1000);
    final kmSoon = kmRemaining != null && kmRemaining <= kmSoonLimit;
    final timeSoon = estimated != null && estimated.difference(now).inDays <= 30;
    state = (kmSoon || timeSoon) ? DueState.soon : DueState.ok;
  }

  return MaintenanceStatus(
    item: item,
    kmRemaining: kmRemaining,
    dueByMonths: dueByMonths,
    dueByKm: dueByKm,
    estimatedDue: estimated,
    used: used,
    state: state,
  );
}
