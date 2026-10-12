// Araç geçmişi raporu: alıcının göreceği özet. Tutarlar (kaza hasarı hariç) yer almaz.
// Bağlantıyla paylaşmada aynı veri shares/{id}.snapshot olarak yazılacak.

import '../core/format.dart';
import '../data/models.dart';
import 'maintenance.dart';

class KeyJob {
  KeyJob(this.label, this.date, this.km);
  final String label;
  final DateTime date;
  final int? km;
}

/// Belge/süre durumu: geçerli mi, ne zaman bitiyor.
class DocStatus {
  DocStatus(this.label, this.until);
  final String label;
  final DateTime? until;
  bool get known => until != null;
  bool get valid => until != null && !until!.isBefore(today());
}

class VehicleReport {
  VehicleReport({
    required this.trackingSince,
    required this.kmPoints,
    required this.kmConsistent,
    required this.kmPerYear,
    required this.keyJobs,
    required this.docs,
    required this.plan,
  });

  /// Tekerim'de ilk veri tarihi.
  final DateTime trackingSince;

  /// Tarih sırasına göre km okumaları (aynı gün tek nokta).
  final List<KmPoint> kmPoints;

  /// Km hiç geri gitmemiş mi? (100 km'den büyük düşüş yoksa true)
  final bool kmConsistent;

  /// Yıllık ortalama km (en az 60 günlük veri varsa).
  final int? kmPerYear;

  /// Her işlem türünün en son yapıldığı tarih ve km (triger, balata…).
  final List<KeyJob> keyJobs;

  final List<DocStatus> docs;

  /// Bakım planı kalemlerinin güncel durumu.
  final List<MaintenanceStatus> plan;

  int? get firstKm => kmPoints.isEmpty ? null : kmPoints.first.km;
  int? get lastKm => kmPoints.isEmpty ? null : kmPoints.last.km;
}

VehicleReport computeReport({
  required Vehicle vehicle,
  required List<ExpenseRecord> records,
  required List<MaintenanceStatus> plan,
}) {
  final v = vehicle;
  final own = records.where((r) => r.vehicleId == v.id).toList();

  // Takip başlangıcı
  var since = dateOnly(v.createdAt);
  for (final r in own) {
    if (r.date.isBefore(since)) since = dateOnly(r.date);
  }
  for (final p in v.kmLog) {
    if (p.date.isBefore(since)) since = dateOnly(p.date);
  }

  // Km okumaları: km güncellemeleri + km'li kayıtlar + güncel km. Aynı gün → en büyük.
  final byDay = <DateTime, int>{};
  void add(DateTime d, int km) {
    if (km <= 0) return;
    final k = dateOnly(d);
    final cur = byDay[k];
    if (cur == null || km > cur) byDay[k] = km;
  }

  for (final p in v.kmLog) {
    add(p.date, p.km);
  }
  for (final r in own) {
    if (r.km != null) add(r.date, r.km!);
  }
  add(v.kmUpdatedAt, v.currentKm);
  final days = byDay.keys.toList()..sort();
  final points = [for (final d in days) KmPoint(d, byDay[d]!)];

  var consistent = true;
  for (var i = 1; i < points.length; i++) {
    if (points[i].km < points[i - 1].km - 100) {
      consistent = false;
      break;
    }
  }

  int? perYear;
  if (points.length >= 2) {
    final span = daysBetween(points.first.date, points.last.date);
    final diff = points.last.km - points.first.km;
    if (span >= 60 && diff > 0) perYear = (diff / span * 365).round();
  }

  // Önemli işlemler: bakım kayıtlarındaki işlemler + lastik değişimi
  final last = <String, ExpenseRecord>{};
  for (final r in own) {
    final keys = <String>[
      if (r.category == RecordCategory.maintenance) ...r.jobs,
      if (r.category == RecordCategory.tire) 'tire',
    ];
    for (final k in keys) {
      final cur = last[k];
      if (cur == null || r.date.isAfter(cur.date)) last[k] = r;
    }
  }
  final order = [...kJobLabels.keys, 'tire'];
  final jobs = <KeyJob>[
    for (final k in order)
      if (last[k] != null)
        KeyJob(k == 'tire' ? 'Lastik işlemi' : jobLabel(k), last[k]!.date, last[k]!.km),
  ];

  return VehicleReport(
    trackingSince: since,
    kmPoints: points,
    kmConsistent: consistent,
    kmPerYear: perYear,
    keyJobs: jobs,
    docs: [
      DocStatus('Muayene', v.inspectionDueDate),
      DocStatus('Trafik sigortası', v.trafficInsuranceEndDate),
      DocStatus('Kasko', v.cascoEndDate),
    ],
    plan: plan,
  );
}

/// "Mart 2025"
String monthYear(DateTime d) => '${kMonthsLong[d.month - 1]} ${d.year}';
