// Uygulamanın veri modelleri.
//
// Para her yerde KURUŞ cinsinden tam sayı olarak tutulur (₺1.500 = 150000).
// Sabit seçenekler İngilizce anahtarla saklanır, ekranda Türkçe etiket gösterilir.
// Bu yapı Firestore şemasıyla birebir aynıdır; Firebase'e geçerken sadece
// kaydetme/okuma katmanı değişecek.

import 'dart:math';

/// Benzersiz kimlik üretir (Firestore belge kimliği gibi 20 karakter).
String newId() {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return List.generate(20, (_) => chars[r.nextInt(chars.length)]).join();
}

DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v as String);
String? _iso(DateTime? d) => d?.toIso8601String();

// ---------------------------------------------------------------------------
// Sabit seçenekler
// ---------------------------------------------------------------------------

enum VehicleType {
  car('car', 'Otomobil'),
  motorcycle('motorcycle', 'Motosiklet'),
  atv('atv', 'ATV'),
  van('van', 'Kamyonet'),
  truck('truck', 'Kamyon');

  const VehicleType(this.key, this.label);
  final String key;
  final String label;

  static VehicleType fromKey(String? k) =>
      values.firstWhere((e) => e.key == k, orElse: () => VehicleType.car);
}

enum FuelType {
  gasoline('gasoline', 'Benzin'),
  diesel('diesel', 'Dizel'),
  lpg('lpg', 'LPG'),
  gasolineLpg('gasoline_lpg', 'Benzin + LPG'),
  hybrid('hybrid', 'Hibrit'),
  pluginHybrid('plugin_hybrid', 'Şarjlı hibrit'),
  electric('electric', 'Elektrik');

  const FuelType(this.key, this.label);
  final String key;
  final String label;

  /// Yakıt alıyor mu? (Elektrik hariç hepsi)
  bool get usesFuel => this != FuelType.electric;

  /// Şarj ediliyor mu? (Elektrik ve şarjlı hibrit)
  bool get usesCharge =>
      this == FuelType.electric || this == FuelType.pluginHybrid;

  /// Motor yağı vb. içten yanmalı bakımı var mı?
  bool get hasEngine => this != FuelType.electric;

  static FuelType fromKey(String? k) =>
      values.firstWhere((e) => e.key == k, orElse: () => FuelType.gasoline);
}

enum RecordCategory {
  fuel('fuel', 'Yakıt'),
  charge('charge', 'Şarj'),
  maintenance('maintenance', 'Bakım'),
  tire('tire', 'Lastik'),
  insurance('insurance', 'Sigorta'),
  inspection('inspection', 'Muayene'),
  tax('tax', 'Vergi'),
  fine('fine', 'Ceza'),
  other('other', 'Diğer');

  const RecordCategory(this.key, this.label);
  final String key;
  final String label;

  /// Açıklama alanı gösterilen kategoriler.
  bool get hasNote =>
      this == RecordCategory.maintenance ||
      this == RecordCategory.tire ||
      this == RecordCategory.tax ||
      this == RecordCategory.fine ||
      this == RecordCategory.other;

  /// Servis / usta alanı gösterilen kategoriler.
  bool get hasService =>
      this == RecordCategory.maintenance || this == RecordCategory.tire;

  /// Servis geçmişinde ve paylaşılan raporda görünen kategoriler.
  bool get isServiceHistory =>
      this == RecordCategory.maintenance ||
      this == RecordCategory.tire ||
      this == RecordCategory.inspection;

  static RecordCategory fromKey(String? k) =>
      values.firstWhere((e) => e.key == k, orElse: () => RecordCategory.other);
}

enum ChargeLocation {
  home('home', 'Ev'),
  ac('ac', 'AC'),
  dc('dc', 'DC');

  const ChargeLocation(this.key, this.label);
  final String key;
  final String label;

  static ChargeLocation? fromKey(String? k) {
    for (final e in values) {
      if (e.key == k) return e;
    }
    return null;
  }
}

/// Bakımda yapılabilecek işlemler: anahtar -> Türkçe ad.
const Map<String, String> kJobLabels = {
  'engine_oil': 'Motor yağı',
  'oil_filter': 'Yağ filtresi',
  'air_filter': 'Hava filtresi',
  'cabin_filter': 'Polen filtresi',
  'fuel_filter': 'Yakıt filtresi',
  'spark_plug': 'Buji',
  'timing_belt': 'Triger seti',
  'brake_pads': 'Fren balatası',
  'coolant': 'Antifriz',
  'brake_fluid': 'Fren hidroliği',
  'battery_check': 'Akü kontrolü',
  'lpg_service': 'LPG bakımı',
  'chain': 'Zincir bakımı',
  'transmission_oil': 'Şanzıman yağı',
  'general_check': 'Genel kontrol',
  'ac_service': 'Klima bakımı',
};

String jobLabel(String key) => kJobLabels[key] ?? key;

// ---------------------------------------------------------------------------
// Araç
// ---------------------------------------------------------------------------

class KmPoint {
  KmPoint(this.date, this.km);
  final DateTime date;
  final int km;

  Map<String, dynamic> toJson() => {'date': _iso(date), 'km': km};
  factory KmPoint.fromJson(Map<String, dynamic> j) =>
      KmPoint(DateTime.parse(j['date'] as String), j['km'] as int);
}

class Vehicle {
  Vehicle({
    required this.id,
    required this.plate,
    required this.type,
    required this.brand,
    required this.model,
    this.year,
    required this.fuelType,
    required this.currentKm,
    required this.kmUpdatedAt,
    List<KmPoint>? kmLog,
    this.inspectionDueDate,
    this.trafficInsuranceEndDate,
    this.cascoEndDate,
    this.seasonalTireReminder = true,
    this.mtvReminder = true,
    this.sortOrder = 0,
    this.archived = false,
    required this.createdAt,
  }) : kmLog = kmLog ?? [];

  final String id;
  String plate;
  VehicleType type;
  String brand;
  String model;
  int? year;
  FuelType fuelType;
  int currentKm;
  DateTime kmUpdatedAt;

  /// Kullanıcının elle girdiği km güncellemeleri (ortalama km hesabı için).
  List<KmPoint> kmLog;
  DateTime? inspectionDueDate;
  DateTime? trafficInsuranceEndDate;
  DateTime? cascoEndDate;
  bool seasonalTireReminder;
  bool mtvReminder;
  int sortOrder;
  bool archived;
  final DateTime createdAt;

  String get title {
    final t = '$brand $model'.trim();
    return t.isEmpty ? type.label : t;
  }

  /// "34 KRC 115" -> "34KRC115" (aynı plakayı iki kez eklemeyi önlemek için).
  String get plateNormalized =>
      plate.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9ÇĞİÖŞÜ]'), '');

  Map<String, dynamic> toJson() => {
        'id': id,
        'plate': plate,
        'plateNormalized': plateNormalized,
        'type': type.key,
        'brand': brand,
        'model': model,
        'year': year,
        'fuelType': fuelType.key,
        'currentKm': currentKm,
        'kmUpdatedAt': _iso(kmUpdatedAt),
        'kmLog': kmLog.map((e) => e.toJson()).toList(),
        'inspectionDueDate': _iso(inspectionDueDate),
        'trafficInsuranceEndDate': _iso(trafficInsuranceEndDate),
        'cascoEndDate': _iso(cascoEndDate),
        'seasonalTireReminder': seasonalTireReminder,
        'mtvReminder': mtvReminder,
        'sortOrder': sortOrder,
        'archived': archived,
        'createdAt': _iso(createdAt),
      };

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as String,
        plate: j['plate'] as String? ?? '',
        type: VehicleType.fromKey(j['type'] as String?),
        brand: j['brand'] as String? ?? '',
        model: j['model'] as String? ?? '',
        year: j['year'] as int?,
        fuelType: FuelType.fromKey(j['fuelType'] as String?),
        currentKm: j['currentKm'] as int? ?? 0,
        kmUpdatedAt: _date(j['kmUpdatedAt']) ?? DateTime.now(),
        kmLog: ((j['kmLog'] as List?) ?? [])
            .map((e) => KmPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        inspectionDueDate: _date(j['inspectionDueDate']),
        trafficInsuranceEndDate: _date(j['trafficInsuranceEndDate']),
        cascoEndDate: _date(j['cascoEndDate']),
        seasonalTireReminder: j['seasonalTireReminder'] as bool? ?? true,
        mtvReminder: j['mtvReminder'] as bool? ?? true,
        sortOrder: j['sortOrder'] as int? ?? 0,
        archived: j['archived'] as bool? ?? false,
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// Gider kaydı (yakıt, şarj, bakım, lastik, sigorta, muayene, vergi, ceza, diğer)
// ---------------------------------------------------------------------------

class ExpenseRecord {
  ExpenseRecord({
    required this.id,
    required this.vehicleId,
    required this.category,
    required this.date,
    this.km,
    required this.amountKurus,
    this.fuelKind,
    this.energyKwh,
    this.chargeLocation,
    List<String>? jobs,
    this.serviceName,
    this.note,
    this.dueDate,
    required this.createdAt,
  }) : jobs = jobs ?? [];

  final String id;
  String vehicleId;
  RecordCategory category;
  DateTime date;
  int? km;
  int amountKurus;

  /// Benzin + LPG araçta: 'gasoline' veya 'lpg'.
  String? fuelKind;
  double? energyKwh;
  ChargeLocation? chargeLocation;
  List<String> jobs;
  String? serviceName;
  String? note;

  /// Ceza son ödeme tarihi gibi hatırlatma tarihi.
  DateTime? dueDate;
  final DateTime createdAt;

  /// Listede gösterilecek başlık.
  String get title {
    switch (category) {
      case RecordCategory.fuel:
        if (fuelKind == 'lpg') return 'LPG alımı';
        return 'Yakıt alımı';
      case RecordCategory.charge:
        return chargeLocation == null
            ? 'Şarj'
            : 'Şarj · ${chargeLocation!.label}';
      case RecordCategory.maintenance:
        if (jobs.isEmpty) return 'Bakım';
        if (jobs.contains('engine_oil')) return 'Periyodik bakım';
        return jobs.map(jobLabel).take(2).join(', ');
      case RecordCategory.tire:
        return 'Lastik';
      case RecordCategory.insurance:
        return 'Sigorta / kasko';
      case RecordCategory.inspection:
        return 'Araç muayenesi';
      case RecordCategory.tax:
        return 'Vergi';
      case RecordCategory.fine:
        return 'Trafik cezası';
      case RecordCategory.other:
        return (note != null && note!.trim().isNotEmpty)
            ? note!.trim().split('\n').first
            : 'Diğer gider';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'category': category.key,
        'date': _iso(date),
        'km': km,
        'amountKurus': amountKurus,
        'fuelKind': fuelKind,
        'energyKwh': energyKwh,
        'chargeLocation': chargeLocation?.key,
        'jobs': jobs,
        'serviceName': serviceName,
        'note': note,
        'dueDate': _iso(dueDate),
        'createdAt': _iso(createdAt),
      };

  factory ExpenseRecord.fromJson(Map<String, dynamic> j) => ExpenseRecord(
        id: j['id'] as String,
        vehicleId: j['vehicleId'] as String,
        category: RecordCategory.fromKey(j['category'] as String?),
        date: DateTime.parse(j['date'] as String),
        km: j['km'] as int?,
        amountKurus: j['amountKurus'] as int? ?? 0,
        fuelKind: j['fuelKind'] as String?,
        energyKwh: (j['energyKwh'] as num?)?.toDouble(),
        chargeLocation: ChargeLocation.fromKey(j['chargeLocation'] as String?),
        jobs: ((j['jobs'] as List?) ?? []).cast<String>(),
        serviceName: j['serviceName'] as String?,
        note: j['note'] as String?,
        dueDate: _date(j['dueDate']),
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// Bakım planı kalemi
// ---------------------------------------------------------------------------

class MaintenanceItem {
  MaintenanceItem({
    required this.id,
    required this.vehicleId,
    this.presetKey,
    required this.name,
    this.intervalKm,
    this.intervalMonths,
    this.lastDoneKm,
    this.lastDoneDate,
    List<String>? resetJobs,
    this.notify = true,
    this.sortOrder = 0,
  }) : resetJobs = resetJobs ?? [];

  final String id;
  final String vehicleId;
  String? presetKey;
  String name;
  int? intervalKm;
  int? intervalMonths;
  int? lastDoneKm;
  DateTime? lastDoneDate;

  /// Bu işlemlerden biri bakım kaydında işaretlenirse sayaç sıfırlanır.
  List<String> resetJobs;
  bool notify;
  int sortOrder;

  String get ruleText {
    final parts = <String>[];
    if (intervalKm != null) parts.add('${_thousands(intervalKm!)} km');
    if (intervalMonths != null) parts.add('$intervalMonths ay');
    return parts.join(' / ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'presetKey': presetKey,
        'name': name,
        'intervalKm': intervalKm,
        'intervalMonths': intervalMonths,
        'lastDoneKm': lastDoneKm,
        'lastDoneDate': _iso(lastDoneDate),
        'resetJobs': resetJobs,
        'notify': notify,
        'sortOrder': sortOrder,
      };

  factory MaintenanceItem.fromJson(Map<String, dynamic> j) => MaintenanceItem(
        id: j['id'] as String,
        vehicleId: j['vehicleId'] as String,
        presetKey: j['presetKey'] as String?,
        name: j['name'] as String? ?? '',
        intervalKm: j['intervalKm'] as int?,
        intervalMonths: j['intervalMonths'] as int?,
        lastDoneKm: j['lastDoneKm'] as int?,
        lastDoneDate: _date(j['lastDoneDate']),
        resetJobs: ((j['resetJobs'] as List?) ?? []).cast<String>(),
        notify: j['notify'] as bool? ?? true,
        sortOrder: j['sortOrder'] as int? ?? 0,
      );
}

String _thousands(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

// ---------------------------------------------------------------------------
// Kaza / hasar kaydı (giderlere eklenmez, paylaşılan rapora girer)
// ---------------------------------------------------------------------------

class Accident {
  Accident({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.damageKurus,
    required this.description,
  });

  final String id;
  final String vehicleId;
  DateTime date;
  int damageKurus;
  String description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'date': _iso(date),
        'damageKurus': damageKurus,
        'description': description,
      };

  factory Accident.fromJson(Map<String, dynamic> j) => Accident(
        id: j['id'] as String,
        vehicleId: j['vehicleId'] as String,
        date: DateTime.parse(j['date'] as String),
        damageKurus: j['damageKurus'] as int? ?? 0,
        description: j['description'] as String? ?? '',
      );
}

// ---------------------------------------------------------------------------
// Hatırlatma kararı (tamamlandı / ertelendi) — "Tamamlanan" sekmesi de buradan
// ---------------------------------------------------------------------------

class ReminderDecision {
  ReminderDecision({
    required this.key,
    required this.vehicleId,
    required this.status,
    required this.title,
    required this.decidedAt,
    this.snoozedUntil,
  });

  final String key;
  final String vehicleId;

  /// 'done' | 'dismissed' | 'snoozed'
  final String status;
  final String title;
  final DateTime decidedAt;
  final DateTime? snoozedUntil;

  Map<String, dynamic> toJson() => {
        'key': key,
        'vehicleId': vehicleId,
        'status': status,
        'title': title,
        'decidedAt': _iso(decidedAt),
        'snoozedUntil': _iso(snoozedUntil),
      };

  factory ReminderDecision.fromJson(Map<String, dynamic> j) => ReminderDecision(
        key: j['key'] as String,
        vehicleId: j['vehicleId'] as String? ?? '',
        status: j['status'] as String? ?? 'done',
        title: j['title'] as String? ?? '',
        decidedAt: _date(j['decidedAt']) ?? DateTime.now(),
        snoozedUntil: _date(j['snoozedUntil']),
      );
}

// ---------------------------------------------------------------------------
// Ayarlar
// ---------------------------------------------------------------------------

class AppSettings {
  AppSettings({
    this.onboarded = false,
    this.notificationsEnabled = true,
    this.notifyHour = 9,
    this.notifyMinute = 0,
    List<int>? leadDays,
    this.kmPromptDays = 14,
    this.linkCardDismissedAt,
  }) : leadDays = leadDays ?? [30, 7, 1];

  bool onboarded;
  bool notificationsEnabled;
  int notifyHour;
  int notifyMinute;
  List<int> leadDays;
  int kmPromptDays;
  DateTime? linkCardDismissedAt;

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'notificationsEnabled': notificationsEnabled,
        'notifyHour': notifyHour,
        'notifyMinute': notifyMinute,
        'leadDays': leadDays,
        'kmPromptDays': kmPromptDays,
        'linkCardDismissedAt': _iso(linkCardDismissedAt),
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        onboarded: j['onboarded'] as bool? ?? false,
        notificationsEnabled: j['notificationsEnabled'] as bool? ?? true,
        notifyHour: j['notifyHour'] as int? ?? 9,
        notifyMinute: j['notifyMinute'] as int? ?? 0,
        leadDays: ((j['leadDays'] as List?) ?? [30, 7, 1]).cast<int>(),
        kmPromptDays: j['kmPromptDays'] as int? ?? 14,
        linkCardDismissedAt: _date(j['linkCardDismissedAt']),
      );
}
