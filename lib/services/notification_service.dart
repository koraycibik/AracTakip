// Yerel planlı bildirimler (sunucu gerekmez).
//
// Uygulama her açıldığında ve veri her değiştiğinde en yakın hatırlatmalar
// yeniden planlanır. iPhone aynı anda en fazla 64 planlı bildirime izin
// verdiği için en yakın 60 tanesi kurulur.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/format.dart';
import '../data/app_store.dart';
import '../logic/maintenance.dart';
import '../logic/reminders.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Timer? _debounce;

  /// Bildirime dokunulunca gelen yük: 'reminders' veya 'km:<aracId>'.
  final tappedPayload = ValueNotifier<String?>(null);

  static const _channel = AndroidNotificationDetails(
    'hatirlatmalar',
    'Hatırlatmalar',
    channelDescription: 'Muayene, sigorta, bakım ve kilometre hatırlatmaları',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _details = NotificationDetails(
    android: _channel,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => tappedPayload.value = r.payload,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        tappedPayload.value = launch!.notificationResponse?.payload;
      }
      _ready = true;
    } catch (e) {
      debugPrint('Bildirimler başlatılamadı: $e');
    }
  }

  /// Bildirim izni ister (Android 13+ ve iOS). Kullanıcı reddederse uygulama yine çalışır.
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Bildirim izni istenemedi: $e');
    }
  }

  /// Veri değişikliklerinde art arda çağrılabilir; 2 sn bekleyip bir kez planlar.
  void scheduleSoon(AppStore store) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => reschedule(store));
  }

  Future<void> reschedule(AppStore store) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final s = store.settings;
      if (!s.notificationsEnabled) return;

      final now = tz.TZDateTime.now(tz.local);
      final plans = <_Plan>[];

      tz.TZDateTime at(DateTime day, {int extraMinutes = 0}) => tz.TZDateTime(
          tz.local, day.year, day.month, day.day, s.notifyHour, s.notifyMinute + extraMinutes);

      // 1) Hatırlatmalar: X gün kala ve son gün
      for (final r in store.reminders) {
        if (r.isOverdue) continue;
        final leads = {...s.leadDays, 0}.toList()..sort((a, b) => b.compareTo(a));
        for (final lead in leads) {
          final day = r.dueDate.subtract(Duration(days: lead));
          final when = at(day);
          if (!when.isAfter(now)) continue;
          plans.add(_Plan(when, _title(r, lead), _body(r, lead), 'reminders'));
        }
      }

      // 2) Geciken hatırlatmalar için yarın sabah tek bir özet
      final overdue = store.reminders.where((r) => r.isOverdue).toList();
      if (overdue.isNotEmpty) {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        plans.add(_Plan(
          at(tomorrow, extraMinutes: 1),
          overdue.length == 1 ? '${overdue.first.title} gecikti' : '${overdue.length} hatırlatma gecikti',
          overdue.length == 1
              ? '${overdue.first.vehicle.title} · ${overdue.first.badgeText}'
              : overdue.take(3).map((r) => r.title).join(', '),
          'reminders',
        ));
      }

      // 3) Kilometre sorusu: son güncellemeden X gün sonra
      var i = 0;
      for (final v in store.vehicles) {
        var day = v.kmUpdatedAt.add(Duration(days: s.kmPromptDays));
        var when = at(day, extraMinutes: 2 + i);
        if (!when.isAfter(now)) {
          day = DateTime.now().add(const Duration(days: 1));
          when = at(day, extraMinutes: 2 + i);
        }
        plans.add(_Plan(
          when,
          '${v.title} kilometresi kaç?',
          'Bakım tahminlerini doğru tutmak için güncelle.',
          'km:${v.id}',
        ));
        i++;
      }

      plans.sort((a, b) => a.when.compareTo(b.when));
      var id = 1;
      for (final p in plans.take(60)) {
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: p.when,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: p.title,
          body: p.body,
          payload: p.payload,
        );
      }
    } catch (e) {
      debugPrint('Bildirimler planlanamadı: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  String _title(ReminderItem r, int lead) {
    if (r.kind == ReminderKind.maintenance) {
      return lead == 0 ? '${r.title} zamanı geldi' : '${r.title} yaklaşıyor';
    }
    if (lead == 0) return '${r.title} bugün';
    return '${r.title} · $lead gün kaldı';
  }

  String _body(ReminderItem r, int lead) {
    final v = r.vehicle;
    if (r.kind == ReminderKind.maintenance && r.kmRemaining != null && r.state != DueState.overdue) {
      return '${v.title} · tahminen ${dateLong(r.dueDate)}. Servis randevunu planla.';
    }
    return '${v.plate} · ${dateLong(r.dueDate)}';
  }
}

class _Plan {
  _Plan(this.when, this.title, this.body, this.payload);
  final tz.TZDateTime when;
  final String title;
  final String body;
  final String payload;
}
