import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/app_store.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  final store = AppStore();
  await store.load();
  await NotificationService.instance.init();

  // Veri değiştikçe bildirimleri yeniden planla.
  store.onDataChanged = () => NotificationService.instance.scheduleSoon(store);
  NotificationService.instance.scheduleSoon(store);

  runApp(AracTakipApp(store: store));

  // Reklam onayı ve SDK açılışı uygulamayı bekletmesin.
  AdService.instance.init();
}
