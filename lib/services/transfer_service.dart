// Araç devri: satıcı alıcının e-postasına teklif gönderir, alıcı kabul edince
// araç ve geçmişi alıcının garajına geçer, satıcıda araç "Satıldı" olarak arşivlenir.
//
// Sunucu (Cloud Functions) yok: teklif Firestore'da transfers/{satıcıUid_araçId}
// belgesinde durur. Alıcı ve satıcı uygulamayı açtığında (ve uygulamaya geri
// döndüğünde) teklifler kontrol edilir; yeni bir şey varsa telefon bildirimi gösterilir.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../core/features.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import 'cloud_service.dart';
import 'notification_service.dart';

/// Bir teklifin durumu.
enum TransferStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  blocked('blocked'),
  cancelled('cancelled');

  const TransferStatus(this.key);
  final String key;

  static TransferStatus fromKey(String? k) =>
      TransferStatus.values.firstWhere((s) => s.key == k, orElse: () => TransferStatus.cancelled);
}

class TransferOffer {
  TransferOffer({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toEmail,
    required this.vehicleId,
    required this.plate,
    required this.title,
    required this.status,
    required this.attempts,
    required this.createdAt,
    required this.expiresAt,
    this.payload,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final String toEmail;
  final String vehicleId;
  final String plate;
  final String title;
  final TransferStatus status;
  final int attempts;
  final DateTime createdAt;
  final DateTime expiresAt;
  final Map<String, dynamic>? payload;

  bool get expired => status == TransferStatus.pending && DateTime.now().isAfter(expiresAt);
  int get attemptsLeft => (TransferService.maxAttempts - attempts).clamp(0, TransferService.maxAttempts);

  factory TransferOffer.fromDoc(String id, Map<String, dynamic> d) {
    DateTime t(Object? v) => v is Timestamp ? v.toDate() : DateTime.now();
    final raw = d['payload'];
    Map<String, dynamic>? payload;
    if (raw is String) {
      try {
        payload = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    return TransferOffer(
      id: id,
      fromUid: d['fromUid'] as String? ?? '',
      fromName: d['fromName'] as String? ?? 'Bir Tekerim kullanıcısı',
      toEmail: d['toEmail'] as String? ?? '',
      vehicleId: d['vehicleId'] as String? ?? '',
      plate: d['plate'] as String? ?? '',
      title: d['title'] as String? ?? '',
      status: TransferStatus.fromKey(d['status'] as String?),
      attempts: (d['attempts'] as num?)?.toInt() ?? 1,
      createdAt: t(d['createdAt']),
      expiresAt: t(d['expiresAt']),
      payload: payload,
    );
  }
}

class TransferService {
  TransferService._();
  static final instance = TransferService._();

  static const maxAttempts = 3;
  static const validDays = 7;

  /// Bana gelen, bekleyen teklifler (garajda kart olarak görünür).
  final incoming = ValueNotifier<List<TransferOffer>>(const []);

  /// Gönderdiğim teklifler, araç kimliğine göre.
  final outgoing = ValueNotifier<Map<String, TransferOffer>>(const {});

  AppStore? _store;
  // ignore: unused_field
  AppLifecycleListener? _life;
  bool _started = false;
  bool _refreshing = false;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('transfers');

  /// Oturum değiştikçe ve uygulamaya dönüldükçe teklifleri kontrol eder.
  void start(AppStore store) {
    if (!kCloudEnabled || _started) return;
    _started = true;
    _store = store;
    CloudService.instance.user.addListener(_onUser);
    _life = AppLifecycleListener(onResume: () => unawaited(refresh()));
    _onUser();
  }

  void _onUser() {
    if (CloudService.instance.user.value == null) {
      incoming.value = const [];
      outgoing.value = const {};
      return;
    }
    // Giriş/birleştirme bitsin diye biraz bekle.
    Future<void>.delayed(const Duration(seconds: 3), refresh);
  }

  User? get _user => FirebaseAuth.instance.currentUser;

  /// Alıcı olabilmek için Google ile doğrulanmış e-posta gerekir.
  String? get myEmail {
    final u = _user;
    if (u == null || u.isAnonymous || !u.emailVerified) return null;
    return u.email?.trim().toLowerCase();
  }

  Future<void> refresh() async {
    final store = _store;
    final u = _user;
    if (store == null || u == null || _refreshing || !CloudService.instance.isReady) return;
    _refreshing = true;
    try {
      await _refreshOutgoing(store, u.uid);
      await _refreshIncoming(store);
    } catch (e) {
      debugPrint('Devir teklifleri okunamadı: $e');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshOutgoing(AppStore store, String uid) async {
    final q = await _col.where('fromUid', isEqualTo: uid).get(const GetOptions(source: Source.server));
    final map = <String, TransferOffer>{};
    for (final d in q.docs) {
      final o = TransferOffer.fromDoc(d.id, d.data());
      if (o.status == TransferStatus.accepted) {
        // Alıcı kabul etti: aracı arşivle, teklifi sil (veri bulutta kalmasın).
        final v = store.vehicle(o.vehicleId);
        if (v != null && !v.archived) {
          store.archiveVehicle(o.vehicleId, soldTo: o.toEmail);
          await NotificationService.instance.showNow(
            id: 900,
            title: '${o.plate} devredildi',
            body: '${o.toEmail} devri kabul etti. Aracın "Satılan araçlar" bölümüne taşındı.',
          );
        }
        try {
          await d.reference.delete();
        } catch (_) {}
        continue;
      }
      if (store.vehicle(o.vehicleId) == null) continue; // araç silinmiş
      map[o.vehicleId] = o;
      final seenKey = 'xfer_out_${o.id}_${o.status.key}_${o.attempts}';
      if ((o.status == TransferStatus.declined || o.status == TransferStatus.blocked) && !store.seen(seenKey)) {
        store.markSeen(seenKey);
        await NotificationService.instance.showNow(
          id: 901,
          title: '${o.plate} devri reddedildi',
          body: o.status == TransferStatus.blocked
              ? '${o.toEmail} teklif almak istemiyor.'
              : '${o.toEmail} teklifi reddetti. İstersen tekrar gönderebilirsin.',
        );
      }
    }
    outgoing.value = map;
  }

  Future<void> _refreshIncoming(AppStore store) async {
    final email = myEmail;
    if (email == null) {
      incoming.value = const [];
      return;
    }
    final q = await _col.where('toEmail', isEqualTo: email).get(const GetOptions(source: Source.server));
    final list = <TransferOffer>[];
    for (final d in q.docs) {
      final o = TransferOffer.fromDoc(d.id, d.data());
      if (o.status != TransferStatus.pending || o.expired) continue;
      if (store.seen('xfer_in_done_${o.id}_${o.attempts}')) continue;
      list.add(o);
      final seenKey = 'xfer_in_${o.id}_${o.attempts}';
      if (!store.seen(seenKey)) {
        store.markSeen(seenKey);
        await NotificationService.instance.showNow(
          id: 902,
          title: 'Araç devir teklifi: ${o.plate}',
          body: '${o.fromName} sana ${o.title} aracını ve geçmişini devretmek istiyor.',
        );
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    incoming.value = list;
  }

  /// Teklif gönderir (ya da reddedilen/iptal edilen teklifi tekrar gönderir).
  Future<void> send(AppStore store, Vehicle v, String toEmail) async {
    final u = _user;
    if (u == null) throw StateError('not-signed-in');
    final email = toEmail.trim().toLowerCase();
    if (email == myEmail) throw StateError('self-transfer');
    final existing = outgoing.value[v.id];
    if (existing?.status == TransferStatus.blocked) throw StateError('blocked');
    var attempts = 1;
    if (existing != null && existing.toEmail == email) {
      attempts = existing.attempts + 1;
      if (attempts > maxAttempts) throw StateError('too-many-attempts');
    }
    final payload = jsonEncode(store.exportForTransfer(v.id));
    if (payload.length > 900 * 1024) throw StateError('too-large');
    final now = DateTime.now();
    final fromName = (u.displayName?.trim().isNotEmpty ?? false)
        ? u.displayName!.trim()
        : (u.email ?? 'Bir Tekerim kullanıcısı');
    final ref = _col.doc('${u.uid}_${v.id}');
    await ref.set({
      'fromUid': u.uid,
      'fromName': fromName,
      'toEmail': email,
      'vehicleId': v.id,
      'plate': v.plate,
      'title': v.title,
      'status': TransferStatus.pending.key,
      'attempts': attempts,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(days: validDays))),
      'respondedAt': null,
      'payload': payload,
    });
    outgoing.value = {
      ...outgoing.value,
      v.id: TransferOffer.fromDoc(ref.id, {
        'fromUid': u.uid,
        'fromName': fromName,
        'toEmail': email,
        'vehicleId': v.id,
        'plate': v.plate,
        'title': v.title,
        'status': 'pending',
        'attempts': attempts,
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: validDays))),
      }),
    };
  }

  /// Bekleyen teklifi geri çeker (veriyi de siler).
  Future<void> cancel(String vehicleId) async {
    final o = outgoing.value[vehicleId];
    if (o == null) return;
    await _col.doc(o.id).delete();
    outgoing.value = {...outgoing.value}..remove(vehicleId);
  }

  /// Kabul: önce araç bu telefona eklenir, sonra teklif "kabul edildi" yapılır.
  Future<Vehicle> accept(AppStore store, TransferOffer o) async {
    final snap = await _col.doc(o.id).get(const GetOptions(source: Source.server));
    final fresh = TransferOffer.fromDoc(snap.id, snap.data() ?? const {});
    if (fresh.status != TransferStatus.pending || fresh.payload == null) {
      throw StateError('offer-not-available');
    }
    final doneKey = 'xfer_in_done_${o.id}_${fresh.attempts}';
    Vehicle? v;
    if (!store.seen(doneKey)) {
      v = store.importTransfer(fresh.payload!, from: fresh.fromName);
      store.markSeen(doneKey);
    }
    await _col.doc(o.id).update({'status': TransferStatus.accepted.key, 'respondedAt': FieldValue.serverTimestamp()});
    incoming.value = incoming.value.where((x) => x.id != o.id).toList();
    return v ?? store.vehicles.last;
  }

  /// Ret (block: bu kişiden bu araç için bir daha teklif gelmez). Satıcının verisi silinir.
  Future<void> decline(AppStore store, TransferOffer o, {bool block = false}) async {
    await _col.doc(o.id).update({
      'status': block ? TransferStatus.blocked.key : TransferStatus.declined.key,
      'respondedAt': FieldValue.serverTimestamp(),
      'payload': null,
    });
    store.markSeen('xfer_in_done_${o.id}_${o.attempts}');
    incoming.value = incoming.value.where((x) => x.id != o.id).toList();
  }
}

/// Kısa hata metni (devir ekranları için).
String transferErrorText(Object e) {
  final s = e.toString();
  if (s.contains('self-transfer')) return 'Kendi e-postana devredemezsin.';
  if (s.contains('blocked')) return 'Alıcı bu araç için teklif almak istemiyor.';
  if (s.contains('too-many-attempts')) return 'Aynı kişiye en fazla ${TransferService.maxAttempts} kez gönderebilirsin.';
  if (s.contains('too-large')) return 'Bu aracın geçmişi çok büyük, devredilemiyor.';
  if (s.contains('offer-not-available')) return 'Teklif artık geçerli değil (geri çekilmiş ya da süresi dolmuş).';
  if (s.contains('not-signed-in')) return 'Hesap bağlantısı kurulamadı. İnternetini kontrol et.';
  return 'İşlem tamamlanamadı (${cloudErrorCode(e)}). İnternetini kontrol edip tekrar dene.';
}

