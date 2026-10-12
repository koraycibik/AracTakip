import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/app_store.dart';
import 'data/vehicle_catalog.dart';
import 'services/ad_service.dart';
import 'services/cloud_service.dart';
import 'services/notification_service.dart';
import 'services/transfer_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Uygulama ekranın en üstüne kadar uzanır; durum çubuğu (saat, pil) ve alttaki
  // gezinme çubuğu şeffaf olur, arkada uygulamanın kendi rengi görünür.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
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

  // Araç devir teklifleri (gelen / gönderilen) oturum açılınca kontrol edilir.
  TransferService.instance.start(store);

  // Marka/model listesini arka planda hazırla.
  VehicleCatalog.instance.load();

  // Reklam onayı ve SDK açılışı uygulamayı bekletmesin.
  AdService.instance.init();
}
