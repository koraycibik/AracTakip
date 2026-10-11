import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/app_store.dart';
import 'data/vehicle_catalog.dart';
import 'services/ad_service.dart';
import 'services/cloud_service.dart';
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

  // Bulut: Firebase, isimsiz hesap ve senkron arka planda başlar; uygulamayı bekletmez.
  CloudService.instance.start(store);

  // Marka/model listesini arka planda hazırla.
  VehicleCatalog.instance.load();

  // Reklam onayı ve SDK açılışı uygulamayı bekletmesin.
  AdService.instance.init();
}
