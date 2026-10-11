// Hatırlatmalar: her açılışta araç tarihleri, bakım planı ve kayıtlardan
// yeniden hesaplanır. Kullanıcının kararları (tamamlandı / ertelendi)
// ReminderDecision olarak saklanır.

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/models.dart';
import 'maintenance.dart';

enum ReminderKind {
  inspection,
  trafficInsurance,
  casco,
  mtv,
  seasonalTire,
  maintenance,
  recordDue,
}

class ReminderItem {
  ReminderItem({
    required this.key,
    required this.kind,
    required this.vehicle,
    required this.title,
    required this.dueDate,
    this.sourceId,
    this.kmRemaining,
    this.state = DueState.ok,
  });

  final String key;
  final ReminderKind kind;
  final Vehicle vehicle;
  final String title;
  final DateTime dueDate;
  final String? sourceId;
  final int? kmRemaining;
  final DueState state;

  bool get isOverdue => state == DueState.overdue;

  int get daysLeft => daysBetween(DateTime.now(), dueDate);

  /// Rozet metni: "9 gün", "1.700 km", "3 gün geçti"
  String get badgeText {
    if (kind == ReminderKind.maintenance && kmRemaining != null) {
      if (kmRemaining! <= 0) return '${thousands(-kmRemaining!)} km geçti';
      final byDays = daysLeft;
      // Km daha yakınsa km göster
      if (kmRemaining! < 5000 && byDays > 30) return '${thousands(kmRemaining!)} km';
    }
    return timeLeft(dueDate);
  }

  String get subtitle => '${vehicle.plate} · ${dateLong(dueDate)}';

  IconData get icon {
    switch (kind) {
      case ReminderKind.inspection:
        return Icons.fact_check;
      case ReminderKind.trafficInsurance:
        return Icons.verified_user;
      case ReminderKind.casco:
        return Icons.shield_outlined;
      case ReminderKind.mtv:
        return Icons.receipt_long;
      case ReminderKind.seasonalTire:
        return Icons.tire_repair;
      case ReminderKind.maintenance:
        return Icons.build;
      case ReminderKind.recordDue:
        return Icons.gavel;
    }
  }
}

String _dk(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Tüm araçlar için aktif hatırlatmalar (tarihe göre sıralı).
List<ReminderItem> computeReminders({
  required List<Vehicle> vehicles,
  required List<ExpenseRecord> records,
  required List<MaintenanceItem> items,
  required List<ReminderDecision> decisions,
  required double? Function(Vehicle) avgKm,
}) {
  final now = today();
  final decided = <String, ReminderDecision>{
    for (final d in decisions) d.key: d,
  };

  bool isClosed(String key) {
    final d = decided[key];
    if (d == null) return false;
    if (d.status == 'snoozed') {
      return d.snoozedUntil != null && d.snoozedUntil!.isAfter(DateTime.now());
    }
    return true;
  }

  DueState stateFor(DateTime due) {
    final days = daysBetween(now, due);
    if (days < 0) return DueState.overdue;
    if (days <= 30) return DueState.soon;
    return DueState.ok;
  }

  final out = <ReminderItem>[];

  for (final v in vehicles) {
    void addDate(ReminderKind kind, String title, DateTime? due) {
      if (due == null) return;
      final key = '${kind.name}|${v.id}|${_dk(due)}';
      if (isClosed(key)) return;
      out.add(ReminderItem(
        key: key,
        kind: kind,
        vehicle: v,
        title: title,
        dueDate: dateOnly(due),
        state: stateFor(due),
      ));
    }

    addDate(ReminderKind.inspection, 'Araç muayenesi', v.inspectionDueDate);
    addDate(ReminderKind.trafficInsurance, 'Trafik sigortası yenileme',
        v.trafficInsuranceEndDate);
    addDate(ReminderKind.casco, 'Kasko yenileme', v.cascoEndDate);

    // Tekrarlayan hatırlatmalar: sadece araç eklendikten sonraki dönemler.
    final created = dateOnly(v.createdAt);

    if (v.mtvReminder) {
      final candidates = <(DateTime, String)>[];
      for (final y in [now.year - 1, now.year, now.year + 1]) {
        candidates.add((DateTime(y, 1, 31), 'MTV 1. taksit'));
        candidates.add((DateTime(y, 7, 31), 'MTV 2. taksit'));
      }
      for (final c in candidates) {
        final due = c.$1;
        // Dönem, aracın eklenmesinden sonra başlamış olmalı (Ocak / Temmuz başı).
        final periodStart = DateTime(due.year, due.month, 1);
        if (periodStart.isBefore(created) && due.isBefore(created)) continue;
        if (due.isBefore(created)) continue;
        if (daysBetween(now, due) > 200) continue;
        final key = 'mtv|${v.id}|${_dk(due)}';
        if (isClosed(key)) continue;
        out.add(ReminderItem(
          key: key,
          kind: ReminderKind.mtv,
          vehicle: v,
          title: c.$2,
          dueDate: due,
          state: stateFor(due),
        ));
        break; // Sadece en yakın açık dönem
      }
    }

    if (v.seasonalTireReminder && v.type != VehicleType.atv) {
      final candidates = <(DateTime, String)>[];
      for (final y in [now.year - 1, now.year, now.year + 1]) {
        candidates.add((DateTime(y, 4, 15), 'Yaz lastiğine geçiş'));
        candidates.add((DateTime(y, 11, 1), 'Kış lastiğine geçiş'));
      }
      candidates.sort((a, b) => a.$1.compareTo(b.$1));
      for (final c in candidates) {
        final due = c.$1;
        if (due.isBefore(created)) continue;
        // Geçmiş mevsim geçişi 45 günden eskiyse artık gösterme
        if (daysBetween(due, now) > 45) continue;
        final key = 'seasonalTire|${v.id}|${_dk(due)}';
        if (isClosed(key)) continue;
        out.add(ReminderItem(
          key: key,
          kind: ReminderKind.seasonalTire,
          vehicle: v,
          title: c.$2,
          dueDate: due,
          state: stateFor(due),
        ));
        break;
      }
    }

    // Bakım planı
    final avg = avgKm(v);
    for (final it in items.where((i) => i.vehicleId == v.id && i.notify)) {
      final st = maintenanceStatus(it, v, avg);
      var due = st.estimatedDue;
      if (due == null) {
        // Sadece km kuralı var ve ortalama bilinmiyor: km dolduysa bugün göster
        if (st.state == DueState.overdue) {
          due = now;
        } else {
          continue;
        }
      }
      final key =
          'maintenance|${v.id}|${it.id}|${it.lastDoneKm}|${it.lastDoneDate?.toIso8601String()}';
      if (isClosed(key)) continue;
      out.add(ReminderItem(
        key: key,
        kind: ReminderKind.maintenance,
        vehicle: v,
        title: it.name,
        dueDate: dateOnly(due),
        sourceId: it.id,
        kmRemaining: st.kmRemaining,
        state: st.state,
      ));
    }

    // Son ödeme tarihli kayıtlar (ceza vb.)
    for (final r in records.where((rec) => rec.vehicleId == v.id && rec.dueDate != null)) {
      final key = 'recordDue|${v.id}|${r.id}';
      if (isClosed(key)) continue;
      out.add(ReminderItem(
        key: key,
        kind: ReminderKind.recordDue,
        vehicle: v,
        title: r.category == RecordCategory.fine
            ? 'Trafik cezası son ödeme'
            : '${r.category.label} son ödeme',
        dueDate: dateOnly(r.dueDate!),
        sourceId: r.id,
        state: stateFor(r.dueDate!),
      ));
    }
  }

  out.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return out;
}
