// Uygulamanın veri modelleri.
//
// Para her yerde KURUŞ cinsinden tam sayı olarak tutulur (₺1.500 = 150000).
// Sabit seçenekler İngilizce anahtarla saklanır, ekranda Türkçe etiket gösterilir.
// Bu yapı Firestore şemasıyla birebir aynıdır; Firebase'e geçerken sadece
// kaydetme/okuma katmanı değişecek.

import 'dart:math';

import '../core/format.dart' show plateKey;

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
  truck('truck', 'Kamyon'),
  minibus('minibus', 'Minibüs'),
  bus('bus', 'Otobüs');

  const VehicleType(this.key, this.label);
  final String key;
  final String label;

  static VehicleType fromKey(String? k) =>
      values.firstWhere((e) => e.key == k, orElse: () => VehicleType.car);
}

enum FuelType {
  gasoline('gasoline', 'Benzin'),
  diesel('diesel', 'Dizel'),
  // Eski "LPG" seçeneği "Benzin + LPG" ile birleştirildi (LPG'li araçlar benzinle de çalışır).
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

  /// LPG'li araç mı? (Yakıt girerken Benzin / LPG seçimi çıkar.)
  bool get hasLpg => this == FuelType.gasolineLpg;

  static FuelType fromKey(String? k) {
    if (k == 'lpg') return FuelType.gasolineLpg; // eski kayıtlar
    return values.firstWhere((e) => e.key == k, orElse: () => FuelType.gasoline);
  }
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
    this.archivedAt,
    this.soldTo,
    this.receivedFrom,
    this.receivedAt,
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

  /// Devredilip arşivlendiği tarih ve alıcının e-postası (satıcı tarafı).
  DateTime? archivedAt;
  String? soldTo;

  /// Devir yoluyla geldiyse: önceki sahip (ad ya da e-posta) ve devir tarihi.
  String? receivedFrom;
  DateTime? receivedAt;
  final DateTime createdAt;

  String get title {
    final t = '$brand $model'.trim();
    return t.isEmpty ? type.label : t;
  }

  /// "34 KRC 115" -> "34KRC115" (aynı plakayı iki kez eklemeyi önlemek için).
  String get plateNormalized => plateKey(plate);

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
        'archivedAt': _iso(archivedAt),
        'soldTo': soldTo,
        'receivedFrom': receivedFrom,
        'receivedAt': _iso(receivedAt),
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
        archivedAt: _date(j['archivedAt']),
        soldTo: j['soldTo'] as String?,
        receivedFrom: j['receivedFrom'] as String?,
        receivedAt: _date(j['receivedAt']),
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
    this.insuranceKind,
    this.fromPreviousOwner = false,
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

  /// Sigorta kaydında: 'traffic' (trafik sigortası) veya 'casco' (kasko).
  String? insuranceKind;

  /// LPG alımı mı? (Yakıt kaydında Benzin / LPG seçimi.)
  bool get isLpg => category == RecordCategory.fuel && fuelKind == 'lpg';

  /// Araç devriyle önceki sahipten geldi: geçmişte görünür, harcama
  /// hesaplarına (istatistik, gerçek maliyet, ay özeti) katılmaz.
  bool fromPreviousOwner;
  final DateTime createdAt;

  /// Listede gösterilecek başlık.
  String get title {
    switch (category) {
      case RecordCategory.fuel:
        if (fuelKind == 'lpg') return 'LPG alımı';
        if (fuelKind == 'gasoline') return 'Benzin alımı';
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
        if (insuranceKind == 'traffic') return 'Trafik sigortası';
        if (insuranceKind == 'casco') return 'Kasko';
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
        'insuranceKind': insuranceKind,
        if (fromPreviousOwner) 'fromPreviousOwner': true,
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
        insuranceKind: j['insuranceKind'] as String?,
        fromPreviousOwner: j['fromPreviousOwner'] as bool? ?? false,
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
// Usta / servis değerlendirmesi (usta defterinde puan ve not)
// ---------------------------------------------------------------------------

class WorkshopReview {
  WorkshopReview({
    required this.key,
    required this.name,
    this.rating = 0,
    this.note = '',
    this.city,
    required this.updatedAt,
  });

  /// normalizeTr(servis adı): aynı usta farklı yazımlarla tek kayıt olur.
  final String key;
  String name;

  /// 1–5 yıldız, 0 = puan verilmedi.
  int rating;

  /// Kişisel not (≤ 500 karakter).
  String note;

  /// Servisin bulunduğu il (ileride firmaların ortak puanı için).
  String? city;
  DateTime updatedAt;

  bool get isEmpty => rating == 0 && note.trim().isEmpty && city == null;

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'rating': rating,
        'note': note,
        'city': city,
        'updatedAt': _iso(updatedAt),
      };

  factory WorkshopReview.fromJson(Map<String, dynamic> j) => WorkshopReview(
        key: j['key'] as String,
        name: j['name'] as String? ?? '',
        rating: ((j['rating'] as num?)?.toInt() ?? 0).clamp(0, 5),
        note: j['note'] as String? ?? '',
        city: j['city'] as String?,
        updatedAt: _date(j['updatedAt']) ?? DateTime.now(),
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
    this.splitLpg = true,
    Set<String>? seenTips,
    this.checklistDismissed = false,
  })  : leadDays = leadDays ?? [30, 7, 1],
        seenTips = seenTips ?? <String>{};

  bool onboarded;
  bool notificationsEnabled;
  int notifyHour;
  int notifyMinute;
  List<int> leadDays;
  int kmPromptDays;
  DateTime? linkCardDismissedAt;

  /// Harcamalar ve Gerçek maliyet ekranlarında LPG ile benzini ayrı göster.
  bool splitLpg;

  /// Görülen tanıtım adımları ve tamamlanan "Tekerim'i tanı" maddeleri
  /// (ör. 'tour_garage', 'tip_record_km', 'done_km'). Buluta da yedeklenir,
  /// yeni telefonda tur tekrar çıkmaz.
  Set<String> seenTips;

  /// Garajdaki "Tekerim'i tanı" kartı kapatıldı mı?
  bool checklistDismissed;

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'notificationsEnabled': notificationsEnabled,
        'notifyHour': notifyHour,
        'notifyMinute': notifyMinute,
        'leadDays': leadDays,
        'kmPromptDays': kmPromptDays,
        'linkCardDismissedAt': _iso(linkCardDismissedAt),
        'splitLpg': splitLpg,
        'seenTips': (seenTips.toList()..sort()),
        'checklistDismissed': checklistDismissed,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        onboarded: j['onboarded'] as bool? ?? false,
        notificationsEnabled: j['notificationsEnabled'] as bool? ?? true,
        notifyHour: j['notifyHour'] as int? ?? 9,
        notifyMinute: j['notifyMinute'] as int? ?? 0,
        leadDays: ((j['leadDays'] as List?) ?? [30, 7, 1]).cast<int>(),
        kmPromptDays: j['kmPromptDays'] as int? ?? 14,
        linkCardDismissedAt: _date(j['linkCardDismissedAt']),
        splitLpg: j['splitLpg'] as bool? ?? true,
        seenTips: {for (final x in (j['seenTips'] as List? ?? const [])) x.toString()},
        checklistDismissed: j['checklistDismissed'] as bool? ?? false,
      );
}
