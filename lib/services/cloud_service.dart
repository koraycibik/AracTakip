// Bulut: Firebase isimsiz hesap, Firestore senkronu, Google ile hesap bağlama, hesap silme.
//
// Nasıl çalışır?
// - Uygulama her zaman önce telefondaki veriyle açılır (AppStore, shared_preferences).
// - Arka planda Firebase başlatılır, kullanıcı yoksa isimsiz hesap açılır.
// - Senkron "fark" mantığıyla yapılır: verinin her belgesi (araç, kayıt, kalem, kaza,
//   karar, ayarlar) bir Firestore yoluna karşılık gelir. En son buluta gönderilen hâlin
//   özeti telefonda tutulur (baseline); değişen belgeler yazılır, kaybolanlar silinir.
//   Böylece AppStore'daki tek tek metotlara dokunmadan her değişiklik buluta gider.
// - İnternet yoksa Firestore yazıları kendi kuyruğunda bekletir, bağlantı gelince gönderir.
// - Açılışta buluttaki hâl çekilir (başka telefonda yapılan değişiklikler için).
// - Bu telefon bu hesapla ilk kez eşleşiyorsa (güncellemeden sonraki ilk açılış ya da
//   yeni telefonda giriş) telefondaki ve buluttaki veriler birleştirilir.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_store.dart';
import '../firebase_options.dart';

/// Google ile bağlama denemesinin sonucu.
enum LinkOutcome {
  /// Bu telefondaki hesap Google hesabına bağlandı (veri aynı kaldı).
  linked,

  /// Bu Google hesabının zaten bir Tekerim hesabı var; geçiş için onay gerekli.
  existingAccount,

  /// Kullanıcı pencereyi kapattı.
  canceled,
}

class CloudService {
  CloudService._();
  static final instance = CloudService._();

  static const _kSyncedUid = 'cloud_synced_uid';
  static const _kBaseline = 'cloud_baseline_v1';

  /// Ekranların dinlediği oturum durumu (null: henüz yok / çevrimdışı ilk açılış).
  final user = _UserNotifier();

  /// "Eşitleniyor" gibi göstergeler için.
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  AppStore? _store;
  SharedPreferences? _prefs;
  bool _ready = false;
  bool _paused = false;
  bool _bootstrapped = false;
  Timer? _debounce;
  Map<String, String> _baseline = {};
  AuthCredential? _pendingCredential;
  bool _googleReady = false;

  // Bulut işlemleri sırayla yürür (ör. çıkıştan hemen sonra girişte iki işlem çakışmasın).
  Future<void> _lock = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() job) {
    final c = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        c.complete(await job());
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool get isReady => _ready;
  bool get isAnonymous => user.value?.isAnonymous ?? true;
  bool get isLinked => user.value != null && !user.value!.isAnonymous;
  String? get email => user.value?.email;

  // -------------------------------------------------------------------------
  // Başlatma
  // -------------------------------------------------------------------------

  /// Uygulama açılışında arka planda çağrılır; hata olsa da uygulama yerel çalışmaya devam eder.
  Future<void> start(AppStore store) async {
    _store = store;
    _prefs = await SharedPreferences.getInstance();
    _baseline = _loadBaseline();
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _ready = true;
    } catch (e) {
      debugPrint('Firebase başlatılamadı: $e');
      return;
    }
    _auth.userChanges().listen(user.set);
    store.onPersisted = scheduleSync;
    await _serial(_ensureUserAndBootstrap);
  }

  Future<void> _ensureUserAndBootstrap() async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
      user.set(_auth.currentUser);
      await _bootstrap();
    } catch (e) {
      // İnternet yoksa isimsiz hesap açılamaz; bir sonraki değişiklikte tekrar denenir.
      debugPrint('Bulut oturumu açılamadı: $e');
    }
  }

  /// Telefon ile bulutu ilk kez (ya da her açılışta) uzlaştırır.
  Future<void> _bootstrap() async {
    final u = _auth.currentUser;
    final store = _store;
    if (u == null || store == null) return;
    busy.value = true;
    try {
      final syncedUid = _prefs?.getString(_kSyncedUid);
      final cloud = await _fetchAll(u.uid);
      final cloudDocs = _docsFromData(cloud, u.uid);
      if (syncedUid != u.uid) {
        // Bu telefon bu hesapla ilk kez: telefondaki ve buluttaki verileri birleştir.
        _baseline = {for (final e in cloudDocs.entries) e.key: _hash(e.value)};
        final merged = _merge(local: store.exportData(), cloud: cloud);
        await _prefs?.setString(_kSyncedUid, u.uid);
        _saveBaseline();
        _bootstrapped = true;
        _paused = true;
        store.replaceAll(merged);
        _paused = false;
        await _push();
      } else {
        // Normal açılış: önce telefondaki bekleyen değişiklikleri gönder, sonra buluttakini al.
        _bootstrapped = true;
        await _push();
        final fresh = await _fetchAll(u.uid);
        final freshDocs = _docsFromData(fresh, u.uid);
        final localDocs = _docsFromData(store.exportData(), u.uid);
        if (!_sameDocs(freshDocs, localDocs) && fresh['_hasUserDoc'] == true) {
          _baseline = {for (final e in freshDocs.entries) e.key: _hash(e.value)};
          _saveBaseline();
          _paused = true;
          store.replaceAll(fresh);
          _paused = false;
        }
      }
    } catch (e) {
      debugPrint('Bulut eşitlenemedi: $e');
    } finally {
      _paused = false;
      busy.value = false;
    }
  }

  // -------------------------------------------------------------------------
  // Senkron (fark tabanlı)
  // -------------------------------------------------------------------------

  /// Her yerel kayıttan sonra çağrılır; 1,5 sn bekleyip tek seferde gönderir.
  void scheduleSync() {
    if (!_ready || _paused) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      _serial(() async {
        if (_paused) return;
        if (_auth.currentUser == null) {
          await _ensureUserAndBootstrap();
          return;
        }
        if (!_bootstrapped) {
          await _bootstrap();
          return;
        }
        await _push();
      });
    });
  }

  /// Bekleyen değişiklikleri hemen gönderir (çıkış/geçiş öncesi).
  Future<void> flush() {
    _debounce?.cancel();
    return _serial(_flushNow);
  }

  Future<void> _flushNow() async {
    if (_ready && _bootstrapped && _auth.currentUser != null) await _push();
  }

  Future<void> _push() async {
    final u = _auth.currentUser;
    final store = _store;
    if (u == null || store == null || _paused) return;
    final docs = _docsFromData(store.exportData(), u.uid);
    final hashes = {for (final e in docs.entries) e.key: _hash(e.value)};
    final writes = [for (final p in docs.keys) if (_baseline[p] != hashes[p]) p];
    final deletes = [for (final p in _baseline.keys) if (!docs.containsKey(p)) p];
    if (writes.isEmpty && deletes.isEmpty) return;

    final ops = <(String, Map<String, dynamic>?)>[
      for (final p in writes) (p, _toCloud(docs[p]!)),
      for (final p in deletes) (p, null),
    ];
    // Firestore toplu yazmada en fazla 500 işlem; 400'lük parçalar.
    for (var i = 0; i < ops.length; i += 400) {
      final chunk = ops.sublist(i, i + 400 > ops.length ? ops.length : i + 400);
      final batch = _db.batch();
      for (final (path, data) in chunk) {
        if (data == null) {
          batch.delete(_db.doc(path));
        } else {
          batch.set(_db.doc(path), data);
        }
      }
      // Yazılar Firestore'un kendi kuyruğuna hemen alınır (çevrimdışıyken de);
      // özet şimdiden güncellenir. Kalıcı bir hata olursa o yollar tekrar denenmek üzere geri alınır.
      for (final (path, data) in chunk) {
        if (data == null) {
          _baseline.remove(path);
        } else {
          _baseline[path] = hashes[path]!;
        }
      }
      unawaited(batch.commit().catchError((Object e) {
        debugPrint('Bulut yazısı reddedildi: $e');
        for (final (path, _) in chunk) {
          _baseline.remove(path);
        }
        _saveBaseline();
      }));
    }
    _saveBaseline();
  }

  // -------------------------------------------------------------------------
  // Veri <-> belge yolları
  // -------------------------------------------------------------------------

  /// Uygulama verisini Firestore yol → belge haritasına çevirir (tarih dönüşümü yok).
  Map<String, Map<String, dynamic>> _docsFromData(Map<String, dynamic> data, String uid) {
    final root = 'users/$uid';
    final out = <String, Map<String, dynamic>>{};
    out[root] = {
      'settings': data['settings'] ?? const {},
      'schemaVersion': 1,
    };
    final vehicleIds = <String>{};
    for (final v in (data['vehicles'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(v as Map);
      vehicleIds.add(m['id'] as String);
      out['$root/vehicles/${m['id']}'] = {...m, 'ownerUid': uid};
    }
    void sub(String key, String coll) {
      for (final x in (data[key] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(x as Map);
        final vid = m['vehicleId'] as String?;
        if (vid == null || !vehicleIds.contains(vid)) continue; // sahipsiz kayıtları gönderme
        out['$root/vehicles/$vid/$coll/${m['id']}'] = {...m, 'ownerUid': uid};
      }
    }

    sub('records', 'records');
    sub('maintenanceItems', 'maintenanceItems');
    sub('accidents', 'accidents');
    for (final d in (data['reminderDecisions'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(d as Map);
      out['$root/reminders/${_docIdFor(m['key'] as String)}'] = m;
    }
    for (final d in (data['workshopReviews'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(d as Map);
      final key = m['key'] as String? ?? '';
      if (key.isEmpty) continue;
      out['$root/workshops/w${key.length > 120 ? key.substring(0, 120) : key}'] = {...m, 'ownerUid': uid};
    }
    return out;
  }

  /// Buluttaki tüm veriyi uygulama biçiminde getirir.
  /// Sunucudan okunur (önbellekteki eksik bir kopya telefondaki veriyi ezmesin diye);
  /// telefonda bekleyen yazılar sonuca dahildir. İnternet yoksa hata verir.
  Future<Map<String, dynamic>> _fetchAll(String uid) async {
    const server = GetOptions(source: Source.server);
    final root = _db.doc('users/$uid');
    final userSnap = await root.get(server);
    final vehSnap = await root.collection('vehicles').get(server);
    final remSnap = await root.collection('reminders').get(server);
    final wsSnap = await root.collection('workshops').get(server);
    final records = <Map<String, dynamic>>[];
    final items = <Map<String, dynamic>>[];
    final accidents = <Map<String, dynamic>>[];
    await Future.wait([
      for (final v in vehSnap.docs) ...[
        v.reference.collection('records').get(server).then((q) => records.addAll(q.docs.map((d) => _fromCloud(d.data())))),
        v.reference.collection('maintenanceItems').get(server).then((q) => items.addAll(q.docs.map((d) => _fromCloud(d.data())))),
        v.reference.collection('accidents').get(server).then((q) => accidents.addAll(q.docs.map((d) => _fromCloud(d.data())))),
      ],
    ]);
    final userData = userSnap.data();
    return {
      'version': 1,
      '_hasUserDoc': userSnap.exists,
      'vehicles': [for (final d in vehSnap.docs) _fromCloud(d.data())],
      'records': records,
      'maintenanceItems': items,
      'accidents': accidents,
      'reminderDecisions': [for (final d in remSnap.docs) _fromCloud(d.data())],
      'workshopReviews': [for (final d in wsSnap.docs) _fromCloud(d.data())],
      if (userData != null && userData['settings'] is Map) 'settings': _fromCloud(Map<String, dynamic>.from(userData['settings'] as Map)),
    };
  }

  /// Telefon + bulut birleşimi: kimliğe göre birleşim; aynı kimlik varsa buluttaki kalır.
  Map<String, dynamic> _merge({required Map<String, dynamic> local, required Map<String, dynamic> cloud}) {
    List<Map<String, dynamic>> union(String key, String idKey) {
      final byId = <String, Map<String, dynamic>>{};
      for (final x in (local[key] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(x as Map);
        byId[m[idKey] as String] = m;
      }
      for (final x in (cloud[key] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(x as Map);
        byId[m[idKey] as String] = m;
      }
      return byId.values.toList();
    }

    final hasCloudSettings = cloud['settings'] is Map;
    return {
      'version': 1,
      'vehicles': union('vehicles', 'id'),
      'records': union('records', 'id'),
      'maintenanceItems': union('maintenanceItems', 'id'),
      'accidents': union('accidents', 'id'),
      'reminderDecisions': union('reminderDecisions', 'key'),
      'workshopReviews': union('workshopReviews', 'key'),
      'settings': hasCloudSettings ? cloud['settings'] : local['settings'],
    };
  }

  bool _sameDocs(Map<String, Map<String, dynamic>> a, Map<String, Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final o = b[e.key];
      if (o == null || _hash(o) != _hash(e.value)) return false;
    }
    return true;
  }

  // Tarih alanları bulutta Timestamp, telefonda ISO metin.
  static const _dateKeys = {
    'date', 'createdAt', 'kmUpdatedAt', 'inspectionDueDate', 'trafficInsuranceEndDate',
    'cascoEndDate', 'dueDate', 'lastDoneDate', 'decidedAt', 'snoozedUntil', 'linkCardDismissedAt', 'updatedAt',
  };

  static dynamic _toCloudValue(String? key, dynamic v) {
    if (v is String && key != null && _dateKeys.contains(key)) {
      final d = DateTime.tryParse(v);
      return d == null ? v : Timestamp.fromDate(d);
    }
    if (v is Map) return _toCloud(Map<String, dynamic>.from(v));
    if (v is List) return [for (final x in v) _toCloudValue(null, x)];
    return v;
  }

  static Map<String, dynamic> _toCloud(Map<String, dynamic> m) =>
      {for (final e in m.entries) e.key: _toCloudValue(e.key, e.value)};

  static dynamic _fromCloudValue(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is Map) return _fromCloud(Map<String, dynamic>.from(v));
    if (v is List) return [for (final x in v) _fromCloudValue(x)];
    return v;
  }

  static Map<String, dynamic> _fromCloud(Map<String, dynamic> m) {
    final out = {for (final e in m.entries) e.key: _fromCloudValue(e.value)};
    out.remove('ownerUid');
    return out;
  }

  /// Belge özeti (FNV-1a 64 bit): aynı içerik her zaman aynı özeti verir.
  static String _hash(Map<String, dynamic> m) {
    final bytes = utf8.encode(jsonEncode(_sorted(m)));
    var h = 0xcbf29ce484222325;
    for (final b in bytes) {
      h ^= b;
      h *= 0x100000001b3; // 64 bit taşma bilerek (Dart int'i sarar)
    }
    return h.toRadixString(16);
  }

  static dynamic _sorted(dynamic v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _sorted(v[k])};
    }
    if (v is List) return [for (final x in v) _sorted(x)];
    return v;
  }

  /// Hatırlatma anahtarından belge kimliği (anahtarda Firestore'un kabul etmediği karakterler olabilir).
  static String _docIdFor(String key) => 'r${_hash({'k': key})}';

  Map<String, String> _loadBaseline() {
    final raw = _prefs?.getString(_kBaseline);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  void _saveBaseline() {
    unawaited(_prefs?.setString(_kBaseline, jsonEncode(_baseline)));
  }

  // -------------------------------------------------------------------------
  // Google ile hesap bağlama / giriş
  // -------------------------------------------------------------------------

  Future<void> _initGoogle() async {
    if (_googleReady) return;
    // Android'de sunucu kimliği google-services.json'dan (default_web_client_id) okunur.
    await GoogleSignIn.instance.initialize();
    _googleReady = true;
  }

  Future<AuthCredential?> _googleCredential() async {
    await _initGoogle();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return null;
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return null;
      }
      rethrow;
    }
  }

  /// "Verilerini güvenceye al" ve "Hesabım var, giriş yap": Google hesabını bu telefondaki hesaba bağlar.
  /// Google hesabının zaten bir Tekerim hesabı varsa [LinkOutcome.existingAccount] döner;
  /// ardından [switchToExistingAccount] çağrılmalı.
  Future<LinkOutcome> linkWithGoogle() async {
    if (!_ready) throw StateError('Bulut hazır değil. İnternet bağlantını kontrol et.');
    final cred = await _googleCredential();
    if (cred == null) return LinkOutcome.canceled;
    return _serial(() async {
      var u = _auth.currentUser;
      if (u == null) {
        await _auth.signInAnonymously();
        u = _auth.currentUser!;
      }
      try {
        await u.linkWithCredential(cred);
        await u.reload();
        user.set(_auth.currentUser);
        await _flushNow();
        return LinkOutcome.linked;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use' ||
            e.code == 'account-exists-with-different-credential') {
          _pendingCredential = e.credential ?? cred;
          return LinkOutcome.existingAccount;
        }
        rethrow;
      }
    });
  }

  /// Var olan Tekerim hesabına geçer; bu telefondaki veriler o hesaba eklenir.
  Future<void> switchToExistingAccount() => _serial(_switchNow);

  Future<void> _switchNow() async {
    final cred = _pendingCredential;
    if (cred == null) return;
    _debounce?.cancel();
    busy.value = true;
    try {
      final old = _auth.currentUser;
      // Eski isimsiz hesabın bulut kopyasını temizle (veri telefonda duruyor, yeni hesaba eklenecek).
      if (old != null && old.isAnonymous) {
        _paused = true;
        await _deleteCloudData(old.uid);
        try {
          await old.delete();
        } catch (_) {}
      }
      await _auth.signInWithCredential(cred);
      user.set(_auth.currentUser);
      _pendingCredential = null;
      _baseline = {};
      _saveBaseline();
      await _prefs?.remove(_kSyncedUid);
      _bootstrapped = false;
      _paused = false;
      await _bootstrap();
    } finally {
      _paused = false;
      busy.value = false;
    }
  }

  /// Çıkış: bekleyenler gönderilir, telefondaki veri silinir, yeni isimsiz oturum açılır.
  Future<void> signOut() => _serial(_signOutNow);

  Future<void> _signOutNow() async {
    _debounce?.cancel();
    await _flushNow();
    _paused = true;
    try {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      await _auth.signOut();
      await _resetLocal();
    } finally {
      _paused = false;
    }
    await _ensureUserAndBootstrap();
  }

  // -------------------------------------------------------------------------
  // Hesap silme
  // -------------------------------------------------------------------------

  /// Buluttaki tüm veriyi, Auth hesabını ve telefondaki veriyi siler.
  /// Yarıda kesilirse tekrar çalıştırılabilir.
  Future<void> deleteAccount() => _serial(_deleteNow);

  Future<void> _deleteNow() async {
    _debounce?.cancel();
    _paused = true;
    busy.value = true;
    try {
      final u = _auth.currentUser;
      if (_ready && u != null) {
        await _deleteCloudData(u.uid);
        try {
          await u.delete();
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            // Google ile bağlı hesaplarda Google yeniden doğrulama ister.
            final cred = await _googleCredential();
            if (cred == null) throw StateError('Silmek için Google hesabını doğrulaman gerekiyor.');
            await u.reauthenticateWithCredential(cred);
            await u.delete();
          } else {
            rethrow;
          }
        }
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
      await _resetLocal();
    } finally {
      _paused = false;
      busy.value = false;
    }
    if (_ready) await _ensureUserAndBootstrap();
  }

  /// users/{uid} altındaki her şeyi siler (önce alt koleksiyonlar).
  Future<void> _deleteCloudData(String uid) async {
    final root = _db.doc('users/$uid');
    final refs = <DocumentReference>[];
    final vehicles = await root.collection('vehicles').get();
    for (final v in vehicles.docs) {
      for (final coll in ['records', 'maintenanceItems', 'accidents']) {
        final q = await v.reference.collection(coll).get();
        refs.addAll(q.docs.map((d) => d.reference));
      }
      refs.add(v.reference);
    }
    final rem = await root.collection('reminders').get();
    refs.addAll(rem.docs.map((d) => d.reference));
    final ws = await root.collection('workshops').get();
    refs.addAll(ws.docs.map((d) => d.reference));
    refs.add(root);
    for (var i = 0; i < refs.length; i += 450) {
      final batch = _db.batch();
      for (final r in refs.sublist(i, i + 450 > refs.length ? refs.length : i + 450)) {
        batch.delete(r);
      }
      await batch.commit();
    }
  }

  Future<void> _resetLocal() async {
    _baseline = {};
    await _prefs?.remove(_kBaseline);
    await _prefs?.remove(_kSyncedUid);
    _bootstrapped = false;
    await _store?.deleteAllData();
  }
}

/// Oturum değişikliklerini (bağlama sonrası aynı kullanıcı nesnesi dahil) ekranlara duyurur.
class _UserNotifier extends ChangeNotifier implements ValueListenable<User?> {
  User? _value;

  @override
  User? get value => _value;

  void set(User? u) {
    _value = u;
    notifyListeners();
  }
}

/// Hata mesajına eklenecek kısa kod (kullanıcı bize iletebilsin diye).
String cloudErrorCode(Object e) {
  if (e is FirebaseAuthException) return e.code;
  if (e is FirebaseException) return e.code;
  if (e is GoogleSignInException) return e.code.name;
  if (e is StateError) return e.message;
  final t = e.toString();
  return t.length > 80 ? t.substring(0, 80) : t;
}
