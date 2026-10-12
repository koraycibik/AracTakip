// Uygulamanın tek veri deposu.
//
// Şimdilik tüm veriler telefonda (shared_preferences içinde tek JSON) tutulur.
// Firebase'e geçerken bu sınıfın okuma/yazma kısmı Firestore'a bağlanacak;
// ekranlar aynı kalacak.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../logic/km.dart' as km_logic;
import '../logic/maintenance.dart';
import '../logic/reminders.dart';
import 'models.dart';
import 'presets.dart';
import 'vehicle_catalog.dart' show normalizeTr;

class AppStore extends ChangeNotifier {
  static const _storageKey = 'arac_takip_data_v1';

  SharedPreferences? _prefs;
  bool loaded = false;

  /// Veriler tamamen sıfırlanınca (hesap silme, çıkış) artar. Uygulama kökü bunu
  /// dinler ve bütün ekran ağacını baştan kurar; açık ekranlar boş veriyle
  /// yeniden çizilmeye çalışıp çökmez.
  final ValueNotifier<int> session = ValueNotifier(0);

  final List<Vehicle> _vehicles = [];
  final List<ExpenseRecord> _records = [];
  final List<MaintenanceItem> _items = [];
  final List<Accident> _accidents = [];
  final List<ReminderDecision> _decisions = [];
  final List<WorkshopReview> _reviews = [];
  AppSettings settings = AppSettings();

  /// Veri her değiştiğinde çağrılır (bildirimleri yeniden planlamak için).
  VoidCallback? onDataChanged;

  /// Veri telefona kaydedildikten sonra çağrılır (buluta göndermek için).
  VoidCallback? onPersisted;

  // -------------------------------------------------------------------------
  // Yükleme / kaydetme
  // -------------------------------------------------------------------------

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final migrated = _migrateLegacyLpg(j);
        List<Map<String, dynamic>> list(String k) => ((j[k] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _vehicles.addAll(list('vehicles').map(Vehicle.fromJson));
        _records.addAll(list('records').map(ExpenseRecord.fromJson));
        _items.addAll(list('maintenanceItems').map(MaintenanceItem.fromJson));
        _accidents.addAll(list('accidents').map(Accident.fromJson));
        _decisions.addAll(list('reminderDecisions').map(ReminderDecision.fromJson));
        _reviews.addAll(list('workshopReviews').map(WorkshopReview.fromJson));
        if (j['settings'] is Map) {
          settings = AppSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map));
        }
        if (migrated) unawaited(_save());
      } catch (e) {
        debugPrint('Veri okunamadı: $e');
      }
    }
    loaded = true;
    notifyListeners();
  }

  /// Tüm verinin JSON hâli (telefona kaydetme ve bulut senkronu aynı biçimi kullanır).
  Map<String, dynamic> exportData() => {
        'version': 1,
        'vehicles': _vehicles.map((e) => e.toJson()).toList(),
        'records': _records.map((e) => e.toJson()).toList(),
        'maintenanceItems': _items.map((e) => e.toJson()).toList(),
        'accidents': _accidents.map((e) => e.toJson()).toList(),
        'reminderDecisions': _decisions.map((e) => e.toJson()).toList(),
        'workshopReviews': _reviews.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      };

  /// Eski "LPG" yakıt tipindeki araçları "Benzin + LPG"ye çevirir; o araçların türü
  /// belirtilmemiş yakıt kayıtlarını LPG sayar. Değişiklik olduysa true döner.
  static bool _migrateLegacyLpg(Map<String, dynamic> j) {
    // Plakaları tek tip yaz ("34abc123", "34 ABC  123" → "34 ABC 123").
    var changed = false;
    for (final v in (j['vehicles'] as List? ?? const [])) {
      if (v is Map && v['plate'] is String) {
        final f = formatPlate(v['plate'] as String);
        if (f != v['plate']) {
          v['plate'] = f;
          v['plateNormalized'] = plateKey(f);
          changed = true;
        }
      }
    }
    final lpgIds = <String>{};
    for (final v in (j['vehicles'] as List? ?? const [])) {
      if (v is Map && v['fuelType'] == 'lpg') {
        v['fuelType'] = 'gasoline_lpg';
        lpgIds.add(v['id'] as String);
      }
    }
    if (lpgIds.isEmpty) return changed;
    for (final r in (j['records'] as List? ?? const [])) {
      if (r is Map && r['category'] == 'fuel' && lpgIds.contains(r['vehicleId']) && r['fuelKind'] == null) {
        r['fuelKind'] = 'lpg';
      }
    }
    return true;
  }

  /// Bellekteki tüm veriyi [j] ile değiştirir (buluttan gelen veri için).
  void replaceAll(Map<String, dynamic> j) {
    _migrateLegacyLpg(j);
    List<Map<String, dynamic>> list(String k) => ((j[k] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _vehicles
      ..clear()
      ..addAll(list('vehicles').map(Vehicle.fromJson));
    _records
      ..clear()
      ..addAll(list('records').map(ExpenseRecord.fromJson));
    _items
      ..clear()
      ..addAll(list('maintenanceItems').map(MaintenanceItem.fromJson));
    _accidents
      ..clear()
      ..addAll(list('accidents').map(Accident.fromJson));
    _decisions
      ..clear()
      ..addAll(list('reminderDecisions').map(ReminderDecision.fromJson));
    _reviews
      ..clear()
      ..addAll(list('workshopReviews').map(WorkshopReview.fromJson));
    if (j['settings'] is Map) {
      settings = AppSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map));
    }
    _changed();
  }

  Future<void> _save() async {
    await _prefs?.setString(_storageKey, jsonEncode(exportData()));
  }

  void _changed() {
    _cache.clear();
    notifyListeners();
    unawaited(_save().then((_) => onPersisted?.call()));
    onDataChanged?.call();
  }

  // Ortalama km gibi hesapları ekran yenilemelerinde tekrar tekrar yapmamak için.
  final Map<String, Object?> _cache = {};

  // -------------------------------------------------------------------------
  // Okuma
  // -------------------------------------------------------------------------

  /// Garajdaki (arşivlenmemiş) araçlar.
  List<Vehicle> get vehicles {
    final l = _vehicles.where((v) => !v.archived).toList();
    l.sort((a, b) {
      final c = a.sortOrder.compareTo(b.sortOrder);
      return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
    });
    return l;
  }

  /// Devredilip arşivlenen (satılan) araçlar; sadece özet için okunur.
  List<Vehicle> get archivedVehicles {
    final l = _vehicles.where((v) => v.archived).toList();
    l.sort((a, b) => (b.archivedAt ?? b.createdAt).compareTo(a.archivedAt ?? a.createdAt));
    return l;
  }

  /// Kullanıcının kendi giderleri (harcama hesapları bunu kullanır).
  /// Devirle önceki sahipten gelen kayıtlar dahil değil.
  List<ExpenseRecord> get allRecords =>
      List.unmodifiable(_records.where((r) => !r.fromPreviousOwner));

  /// Geçmiş, rapor ve usta defteri için: önceki sahipten gelenler dahil tüm kayıtlar.
  List<ExpenseRecord> get historyRecords => List.unmodifiable(_records);
  List<MaintenanceItem> get allItems => List.unmodifiable(_items);
  List<ReminderDecision> get decisions => List.unmodifiable(_decisions);

  Vehicle? vehicle(String id) {
    for (final v in _vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// Bir aracın kayıtları, yeniden eskiye.
  List<ExpenseRecord> recordsFor(String vehicleId) {
    final l = _records.where((r) => r.vehicleId == vehicleId).toList();
    l.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return l;
  }

  List<MaintenanceItem> itemsFor(String vehicleId) {
    final l = _items.where((i) => i.vehicleId == vehicleId).toList();
    l.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return l;
  }

  List<Accident> accidentsFor(String vehicleId) {
    final l = _accidents.where((a) => a.vehicleId == vehicleId).toList();
    l.sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  double? avgKmPerDay(Vehicle v) {
    final key = 'avg:${v.id}';
    if (_cache.containsKey(key)) return _cache[key] as double?;
    final r = km_logic.avgKmPerDay(v, _records);
    _cache[key] = r;
    return r;
  }

  List<MaintenanceStatus> maintenanceFor(Vehicle v) {
    final avg = avgKmPerDay(v);
    return itemsFor(v.id).map((i) => maintenanceStatus(i, v, avg)).toList();
  }

  List<ReminderItem> get reminders {
    const key = 'reminders';
    if (_cache.containsKey(key)) return _cache[key] as List<ReminderItem>;
    final r = computeReminders(
      vehicles: vehicles,
      records: _records,
      items: _items,
      decisions: _decisions,
      avgKm: avgKmPerDay,
    );
    _cache[key] = r;
    return r;
  }

  List<ReminderItem> remindersFor(String vehicleId) =>
      reminders.where((r) => r.vehicle.id == vehicleId).toList();

  /// Bu takvim ayındaki toplam gider (kuruş).
  int monthTotal(String vehicleId) {
    final now = DateTime.now();
    var t = 0;
    for (final r in _records) {
      if (r.vehicleId == vehicleId && !r.fromPreviousOwner && r.date.year == now.year && r.date.month == now.month) {
        t += r.amountKurus;
      }
    }
    return t;
  }

  int? energyPer100(Vehicle v) => km_logic.energyCostPer100Km(v, _records);

  /// LPG'li araçta son [days] günün yakıt harcamasında LPG payı (0..1); veri yoksa null.
  double? lpgShare(Vehicle v, {int days = 90}) {
    if (!v.fuelType.hasLpg) return null;
    final since = DateTime.now().subtract(Duration(days: days));
    var lpg = 0;
    var all = 0;
    for (final r in _records) {
      if (r.vehicleId != v.id || r.category != RecordCategory.fuel || r.date.isBefore(since)) continue;
      all += r.amountKurus;
      if (r.isLpg) lpg += r.amountKurus;
    }
    return all == 0 ? null : lpg / all;
  }

  /// Bu araçta en son girilen yakıt türü ('gasoline' / 'lpg'); yoksa null.
  String? lastFuelKind(String vehicleId) {
    for (final r in recordsFor(vehicleId)) {
      if (r.category == RecordCategory.fuel && r.fuelKind != null) return r.fuelKind;
    }
    return null;
  }

  /// Garajda LPG'li araç var mı? (Benzin / LPG ayrı-toplu düğmesi için.)
  bool get hasLpgVehicle => vehicles.any((v) => v.fuelType.hasLpg);

  // -------------------------------------------------------------------------
  // Ayarlar
  // -------------------------------------------------------------------------

  // -------------------------------------------------------------------------
  // Tanıtım: görülen ipuçları ve "Tekerim'i tanı" maddeleri
  // -------------------------------------------------------------------------

  bool seen(String key) => settings.seenTips.contains(key);

  void markSeen(String key) {
    if (settings.seenTips.add(key)) _changed();
  }

  /// Ayarlar > "Uygulama turunu tekrar izle": tur ve ipuçları yeniden gösterilir
  /// (tamamlanan "done_" maddeleri korunur).
  void resetTips() {
    settings.seenTips.removeWhere((k) => !k.startsWith('done_'));
    settings.checklistDismissed = false;
    _changed();
  }

  void updateSettings(void Function(AppSettings s) change) {
    change(settings);
    _changed();
  }

  // -------------------------------------------------------------------------
  // Araçlar
  // -------------------------------------------------------------------------

  bool plateExists(String plate, {String? exceptId}) => vehicleByPlate(plate, exceptId: exceptId) != null;

  /// Garajdaki (satılmamış) aynı plakalı araç.
  Vehicle? vehicleByPlate(String plate, {String? exceptId}) {
    final n = plateKey(plate);
    if (n.isEmpty) return null;
    for (final v in _vehicles) {
      if (v.id != exceptId && !v.archived && v.plateNormalized == n) return v;
    }
    return null;
  }

  /// Aracı ekler ve türüne/yakıtına göre bakım planını oluşturur.
  /// [lastServiceKm] verilirse periyodik bakım sayacı o km'den başlar.
  Vehicle addVehicle(Vehicle v, {int? lastServiceKm}) {
    v.sortOrder = _vehicles.isEmpty
        ? 0
        : _vehicles.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    v.kmLog = [KmPoint(DateTime.now(), v.currentKm)];
    _vehicles.add(v);
    final presets = maintenancePresetsFor(v.type, v.fuelType);
    for (var i = 0; i < presets.length; i++) {
      final p = presets[i];
      final isPeriodic = p.key == 'periodic';
      _items.add(MaintenanceItem(
        id: newId(),
        vehicleId: v.id,
        presetKey: p.key,
        name: p.name,
        intervalKm: p.km,
        intervalMonths: p.months,
        lastDoneKm: (isPeriodic && lastServiceKm != null) ? lastServiceKm : v.currentKm,
        lastDoneDate: (isPeriodic && lastServiceKm != null) ? null : DateTime.now(),
        resetJobs: List.of(p.resetJobs),
        sortOrder: i,
      ));
    }
    _changed();
    return v;
  }

  void updateVehicle(Vehicle v) {
    _changed();
  }

  // -------------------------------------------------------------------------
  // Araç devri
  // -------------------------------------------------------------------------

  /// Devirde yeni sahibe gidecek veri: araç, bakım/lastik/muayene kayıtları
  /// (tutarlarıyla), bakım planı, kaza kayıtları ve bu kayıtlardaki ustalara
  /// verilen puan/notlar. Yakıt, sigorta, vergi, ceza ve sigorta tarihleri gitmez.
  Map<String, dynamic> exportForTransfer(String vehicleId) {
    final v = vehicle(vehicleId)!;
    final vj = v.toJson()
      ..['trafficInsuranceEndDate'] = null
      ..['cascoEndDate'] = null
      ..['archived'] = false
      ..remove('archivedAt')
      ..remove('soldTo');
    final recs = _records.where((r) => r.vehicleId == vehicleId && r.category.isServiceHistory).toList();
    final shopKeys = <String>{
      for (final r in recs)
        if (r.serviceName != null && r.serviceName!.trim().isNotEmpty) normalizeTr(r.serviceName!),
    };
    return {
      'vehicle': vj,
      'records': [for (final r in recs) r.toJson()],
      'maintenanceItems': [for (final i in _items.where((i) => i.vehicleId == vehicleId)) i.toJson()],
      'accidents': [for (final a in _accidents.where((a) => a.vehicleId == vehicleId)) a.toJson()],
      'workshopReviews': [for (final w in _reviews.where((w) => shopKeys.contains(w.key))) w.toJson()],
    };
  }

  /// Devir teklifini kabul edince aracı ve geçmişini bu garaja ekler.
  /// Kimlikler yenilenir; kayıtlar "önceki sahip" olarak işaretlenir.
  Vehicle importTransfer(Map<String, dynamic> payload, {String? from}) {
    List<Map<String, dynamic>> list(String k) => ((payload[k] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final now = DateTime.now();
    final vj = Map<String, dynamic>.from(payload['vehicle'] as Map);
    vj['plate'] = formatPlate(vj['plate'] as String? ?? '');
    final incoming = Vehicle.fromJson(vj);

    // Garajda aynı plakalı araç varsa geçmiş onun üzerine eklenir.
    final existing = vehicleByPlate(incoming.plate);
    final Vehicle v;
    if (existing != null) {
      v = existing;
      if (incoming.currentKm > v.currentKm) {
        v
          ..currentKm = incoming.currentKm
          ..kmUpdatedAt = incoming.kmUpdatedAt;
      }
      final days = {for (final p in v.kmLog) '${p.date.toIso8601String()}|${p.km}'};
      v.kmLog
        ..addAll(incoming.kmLog.where((p) => !days.contains('${p.date.toIso8601String()}|${p.km}')))
        ..sort((a, b) => a.date.compareTo(b.date));
      if (v.brand.trim().isEmpty) v.brand = incoming.brand;
      if (v.model.trim().isEmpty) v.model = incoming.model;
      v.year ??= incoming.year;
      v.inspectionDueDate ??= incoming.inspectionDueDate;
      v
        ..receivedFrom = from
        ..receivedAt = now;
    } else {
      vj
        ..['id'] = newId()
        ..['archived'] = false
        ..['createdAt'] = now.toIso8601String()
        ..['receivedFrom'] = from
        ..['receivedAt'] = now.toIso8601String()
        ..['sortOrder'] = _vehicles.isEmpty
            ? 0
            : _vehicles.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
      v = Vehicle.fromJson(vj);
      _vehicles.add(v);
    }
    final vid = v.id;
    for (final r in list('records')) {
      _records.add(ExpenseRecord.fromJson(r
        ..['id'] = newId()
        ..['vehicleId'] = vid
        ..['fromPreviousOwner'] = true));
    }
    for (final i in list('maintenanceItems')) {
      final item = MaintenanceItem.fromJson(i
        ..['id'] = newId()
        ..['vehicleId'] = vid);
      // Aynı kalem varsa (ör. periyodik bakım) daha yeni "son yapıldı" bilgisi alınır.
      MaintenanceItem? same;
      for (final x in _items) {
        if (x.vehicleId != vid) continue;
        final byPreset = x.presetKey != null && x.presetKey == item.presetKey;
        final byName = x.name.trim().toLowerCase() == item.name.trim().toLowerCase();
        if (byPreset || byName) {
          same = x;
          break;
        }
      }
      if (same == null) {
        _items.add(item);
      } else if (item.lastDoneDate != null &&
          (same.lastDoneDate == null || item.lastDoneDate!.isAfter(same.lastDoneDate!))) {
        same
          ..lastDoneDate = item.lastDoneDate
          ..lastDoneKm = item.lastDoneKm;
      }
    }
    for (final a in list('accidents')) {
      _accidents.add(Accident.fromJson(a
        ..['id'] = newId()
        ..['vehicleId'] = vid));
    }
    for (final w in list('workshopReviews')) {
      final r = WorkshopReview.fromJson(w);
      // Kendi değerlendirmen varsa o kalır.
      if (reviewFor(r.key) == null && !r.isEmpty) _reviews.add(r);
    }
    _changed();
    return v;
  }

  /// Devir kabul edilince satıcıda araç "Satıldı" olarak arşivlenir;
  /// harcamaları özette kalır, yeni kayıt eklenemez.
  void archiveVehicle(String id, {String? soldTo, DateTime? at}) {
    final v = vehicle(id);
    if (v == null || v.archived) return;
    v
      ..archived = true
      ..archivedAt = at ?? DateTime.now()
      ..soldTo = soldTo;
    _decisions.removeWhere((d) => d.vehicleId == id);
    _changed();
  }

  void deleteVehicle(String id) {
    _vehicles.removeWhere((v) => v.id == id);
    _records.removeWhere((r) => r.vehicleId == id);
    _items.removeWhere((i) => i.vehicleId == id);
    _accidents.removeWhere((a) => a.vehicleId == id);
    _decisions.removeWhere((d) => d.vehicleId == id);
    _changed();
  }

  /// Kilometreyi günceller (daha küçük değer de girilebilir: düzeltme).
  void updateKm(String vehicleId, int km, {DateTime? date}) {
    final v = vehicle(vehicleId);
    if (v == null) return;
    final d = date ?? DateTime.now();
    v.currentKm = km;
    v.kmUpdatedAt = DateTime.now();
    v.kmLog.add(KmPoint(d, km));
    // Kayıt listesi şişmesin: son 200 noktayı tut.
    if (v.kmLog.length > 200) v.kmLog.removeRange(0, v.kmLog.length - 200);
    settings.seenTips.add('done_km'); // "Tekerim'i tanı" maddesi
    _changed();
  }

  // -------------------------------------------------------------------------
  // Kayıtlar
  // -------------------------------------------------------------------------

  void addRecord(ExpenseRecord r) {
    _records.add(r);
    _afterRecordSaved(r);
    _changed();
  }

  void updateRecord(ExpenseRecord r) {
    _afterRecordSaved(r);
    _changed();
  }

  void deleteRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    _changed();
  }

  void _afterRecordSaved(ExpenseRecord r) {
    final v = vehicle(r.vehicleId);
    if (v == null) return;
    // Kayıttaki km daha büyükse aracın km'sini güncelle.
    if (r.km != null && r.km! > v.currentKm) {
      v.currentKm = r.km!;
      v.kmUpdatedAt = DateTime.now();
    }
    // Bakımda işaretlenen işlemler bakım planındaki sayaçları sıfırlar.
    if (r.category == RecordCategory.maintenance && r.jobs.isNotEmpty) {
      for (final it in _items.where((i) => i.vehicleId == v.id)) {
        if (it.resetJobs.any(r.jobs.contains)) {
          it.lastDoneKm = r.km ?? v.currentKm;
          it.lastDoneDate = r.date;
        }
      }
    }
    // Lastik kaydı mevsimlik lastik hatırlatmasını kapatır (o dönem için).
    if (r.category == RecordCategory.tire) {
      for (final rem in remindersFor(v.id)) {
        if (rem.kind == ReminderKind.seasonalTire &&
            daysBetween(r.date, rem.dueDate).abs() <= 60) {
          _decide(rem, 'done');
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Bakım planı
  // -------------------------------------------------------------------------

  void addItem(MaintenanceItem i) {
    i.sortOrder = itemsFor(i.vehicleId).length;
    _items.add(i);
    _changed();
  }

  void updateItem(MaintenanceItem i) => _changed();

  void deleteItem(String id) {
    _items.removeWhere((i) => i.id == id);
    _changed();
  }

  // -------------------------------------------------------------------------
  // Kazalar
  // -------------------------------------------------------------------------

  // -------------------------------------------------------------------------
  // Usta defteri: puan ve not
  // -------------------------------------------------------------------------

  /// En az bir ustaya puan verildi mi? ("Tekerim'i tanı" maddesi)
  bool get hasRatedWorkshop => _reviews.any((r) => r.rating > 0);

  WorkshopReview? reviewFor(String workshopKey) {
    for (final r in _reviews) {
      if (r.key == workshopKey) return r;
    }
    return null;
  }

  /// Puan/not kaydeder; hepsi boşsa değerlendirmeyi kaldırır.
  void saveReview(WorkshopReview r) {
    _reviews.removeWhere((x) => x.key == r.key);
    if (!r.isEmpty) {
      r.updatedAt = DateTime.now();
      _reviews.add(r);
    }
    _changed();
  }

  void addAccident(Accident a) {
    _accidents.add(a);
    _changed();
  }

  void updateAccident(Accident a) => _changed();

  void deleteAccident(String id) {
    _accidents.removeWhere((a) => a.id == id);
    _changed();
  }

  // -------------------------------------------------------------------------
  // Hatırlatma kararları
  // -------------------------------------------------------------------------

  void _decide(ReminderItem r, String status, {DateTime? snoozedUntil}) {
    _decisions.removeWhere((d) => d.key == r.key);
    _decisions.add(ReminderDecision(
      key: r.key,
      vehicleId: r.vehicle.id,
      status: status,
      title: r.title,
      decidedAt: DateTime.now(),
      snoozedUntil: snoozedUntil,
    ));
    // Eski kararları temizle (en fazla 300).
    if (_decisions.length > 300) {
      _decisions.sort((a, b) => a.decidedAt.compareTo(b.decidedAt));
      _decisions.removeRange(0, _decisions.length - 300);
    }
  }

  /// Hatırlatmayı tamamlandı olarak işaretler.
  /// Tarihli kalemlerde (muayene/sigorta/kasko) [newDate] yeni bitiş tarihidir.
  void completeReminder(ReminderItem r, {DateTime? newDate}) {
    final v = r.vehicle;
    switch (r.kind) {
      case ReminderKind.inspection:
        v.inspectionDueDate = newDate;
        break;
      case ReminderKind.trafficInsurance:
        v.trafficInsuranceEndDate = newDate;
        break;
      case ReminderKind.casco:
        v.cascoEndDate = newDate;
        break;
      case ReminderKind.maintenance:
        for (final it in _items) {
          if (it.id == r.sourceId) {
            it.lastDoneKm = v.currentKm;
            it.lastDoneDate = DateTime.now();
          }
        }
        break;
      case ReminderKind.mtv:
      case ReminderKind.seasonalTire:
      case ReminderKind.recordDue:
        break;
    }
    _decide(r, 'done');
    _changed();
  }

  void snoozeReminder(ReminderItem r, int days) {
    _decide(r, 'snoozed', snoozedUntil: DateTime.now().add(Duration(days: days)));
    _changed();
  }

  /// Tamamlanan sekmesi için son kararlar.
  List<ReminderDecision> get completedDecisions {
    final ids = vehicles.map((v) => v.id).toSet();
    final l = _decisions.where((d) => d.status == 'done' && ids.contains(d.vehicleId)).toList();
    l.sort((a, b) => b.decidedAt.compareTo(a.decidedAt));
    return l.take(50).toList();
  }

  // -------------------------------------------------------------------------
  // Tüm verileri sil (hesap silme)
  // -------------------------------------------------------------------------

  Future<void> deleteAllData() async {
    _vehicles.clear();
    _records.clear();
    _items.clear();
    _accidents.clear();
    _decisions.clear();
    _reviews.clear();
    settings = AppSettings();
    _cache.clear();
    await _prefs?.remove(_storageKey);
    session.value++;
    notifyListeners();
    onDataChanged?.call();
  }

  /// Bu telefonda hiç araç yok mu? (Yeni telefonda giriş akışı için.)
  bool get isEmpty => _vehicles.isEmpty && _records.isEmpty;
}

/// Ekranların depoya erişimi: `StoreScope.of(context)` dinler ve yeniden çizer,
/// `StoreScope.read(context)` sadece okur (buton işlemleri için).
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
