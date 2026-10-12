// Gerçek maliyet: aracın günlük, km başı ve aylık maliyeti.
// Kaza/hasar tutarları dahil değildir; satın alma bedeli ve değer kaybı hesaba katılmaz.

import 'dart:ui';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'km.dart';

enum CostPeriod { year, all }

class CostGroup {
  CostGroup(this.label, this.color, this.cats, {this.match, this.usage = true});
  final String label;
  final Color color;
  final Set<RecordCategory> cats;

  /// Kullanıma bağlı (yakıt, bakım) mı, yoksa sabit (sigorta, vergi) mi?
  /// Sabit giderler km başına değil, aya göre gösterilir.
  final bool usage;

  /// Kategori yerine kayda göre eşleşme (LPG ayrı gösterildiğinde).
  final bool Function(ExpenseRecord r)? match;
  int kurus = 0;

  bool accepts(ExpenseRecord r) => match != null ? match!(r) : cats.contains(r.category);
}

class TrueCost {
  TrueCost({
    required this.vehicle,
    required this.start,
    required this.days,
    required this.km,
    required this.totalKurus,
    required this.groups,
  });

  final Vehicle vehicle;
  final DateTime start;
  final int days;

  /// Dönemde yapılan yol (bilinmiyorsa 0).
  final int km;
  final int totalKurus;
  final List<CostGroup> groups;

  int get perDayKurus => (totalKurus / days).round();
  int get perMonthKurus => (totalKurus / days * 30.4).round();

  /// Km başı (kuruş, ondalıklı). 100 km'den az yol varsa güvenilir değil → null.
  double? get perKmKurus => km >= 100 ? totalKurus / km : null;
  double? groupPerKm(CostGroup g) => km >= 100 ? g.kurus / km : null;
  int groupPerMonth(CostGroup g) => (g.kurus / days * 30.4).round();

  List<CostGroup> get usageGroups => groups.where((g) => g.usage).toList();
  List<CostGroup> get fixedGroups => groups.where((g) => !g.usage && g.kurus > 0).toList();
  int get usageKurus => usageGroups.fold(0, (s, g) => s + g.kurus);

  /// Sadece kullanıma bağlı giderlerin km başı maliyeti.
  double? get usagePerKmKurus => km >= 100 ? usageKurus / km : null;

  /// Bir aydan kısa veriyle hesaplanan sonuçlar yanıltıcı olabilir.
  bool get isShort => days < 30;
}

List<CostGroup> _groups(Vehicle v, bool splitLpg) => [
      if (splitLpg && v.fuelType.hasLpg)
        CostGroup('LPG', AppColors.catLpg, {RecordCategory.fuel}, match: (r) => r.isLpg),
      CostGroup(
          v.fuelType == FuelType.electric
              ? 'Şarj'
              : (v.fuelType.hasLpg
                  ? (splitLpg ? 'Benzin' : 'Yakıt (benzin + LPG)')
                  : (v.fuelType.usesCharge ? 'Yakıt ve şarj' : 'Yakıt')),
          AppColors.catFuel,
          {RecordCategory.fuel, RecordCategory.charge}),
      CostGroup('Sigorta ve kasko', AppColors.catIns, {RecordCategory.insurance}, usage: false),
      CostGroup('Bakım ve lastik', AppColors.catMaint, {RecordCategory.maintenance, RecordCategory.tire}),
      CostGroup('Vergi, muayene, ceza, diğer', AppColors.catTax,
          {RecordCategory.tax, RecordCategory.inspection, RecordCategory.fine, RecordCategory.other},
          usage: false),
    ];

TrueCost computeTrueCost(Vehicle v, List<ExpenseRecord> records, CostPeriod period, {bool splitLpg = false}) {
  final now = DateTime.now();
  final end = today();
  final own = records.where((r) => r.vehicleId == v.id).toList();

  // Aracın verisinin başladığı gün: eklenme tarihi ya da daha eski tarihli ilk kayıt.
  var dataStart = dateOnly(v.createdAt);
  for (final r in own) {
    if (r.date.isBefore(dataStart)) dataStart = dateOnly(r.date);
  }
  for (final p in v.kmLog) {
    if (p.date.isBefore(dataStart)) dataStart = dateOnly(p.date);
  }

  var start = dataStart;
  if (period == CostPeriod.year) {
    final yearAgo = end.subtract(const Duration(days: 364));
    if (yearAgo.isAfter(start)) start = yearAgo;
  }
  var days = daysBetween(start, end) + 1;
  if (days < 1) days = 1;

  final groups = _groups(v, splitLpg);
  var total = 0;
  for (final r in own) {
    if (r.date.isBefore(start) || r.date.isAfter(now)) continue;
    total += r.amountKurus;
    for (final g in groups) {
      if (g.accepts(r)) {
        g.kurus += r.amountKurus;
        break;
      }
    }
  }

  return TrueCost(
    vehicle: v,
    start: start,
    days: days,
    km: kmDrivenBetween(v, records, start, now),
    totalKurus: total,
    groups: groups,
  );
}

/// Km başı tutar: kuruş → "₺3,47"
String moneyPerKm(double kurus) {
  final lira = kurus / 100;
  final whole = lira.floor();
  final dec = ((lira - whole) * 100).round();
  if (dec == 100) return '₺${thousands(whole + 1)},00';
  return '₺${thousands(whole)},${dec.toString().padLeft(2, '0')}';
}
