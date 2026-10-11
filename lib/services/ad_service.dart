// Reklamlar (AdMob).
//
// Kural: her 3 gider kaydında 1 tam ekran reklam, iki reklam arası en az 2 dakika.
// Araç eklerken ve kaza kaydında reklam yok. Banner yok.
// Şimdilik Google'ın TEST reklam birimleri kullanılıyor; yayından önce
// AdMob hesabındaki gerçek kimliklerle değiştirilecek (aşağıdaki _unitId).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  AdService._();
  static final instance = AdService._();

  static const _everyNRecords = 3;
  static const _minGap = Duration(minutes: 2);
  static const _kCounter = 'ad_record_counter';
  static const _kLastShown = 'ad_last_shown';

  bool _canRequest = false;
  InterstitialAd? _ad;
  bool _loading = false;

  // Gerçek reklam birimleri: AdMob > Uygulamalar > Tekerim > Reklam birimleri > Geçiş reklamı.
  // Boş kaldıkça (ve hata ayıklama sırasında her zaman) Google'ın test reklamı gösterilir.
  // Kapalı test boyunca test reklamı kalması önerilir; gerçek kimlik üretim yayınından önce yazılır.
  static const _realAndroidUnit = '';
  static const _realIosUnit = '';

  String get _unitId {
    final real = Platform.isIOS ? _realIosUnit : _realAndroidUnit;
    if (kReleaseMode && real.isNotEmpty) return real;
    // Google test reklam birimleri (gerçek gelir getirmez, güvenle denenebilir).
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/4411468910';
    return 'ca-app-pub-3940256099942544/1033173712';
  }

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Uygulama açılışında: önce onay (AB/Türkiye için UMP), sonra reklam SDK'sı.
  Future<void> init() async {
    if (!_supported) return;
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          await ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
            await _startAds();
          });
        },
        (error) async {
          debugPrint('Onay bilgisi alınamadı: ${error.message}');
          await _startAds();
        },
      );
    } catch (e) {
      debugPrint('Reklam başlatılamadı: $e');
    }
  }

  Future<void> _startAds() async {
    try {
      _canRequest = await ConsentInformation.instance.canRequestAds();
      if (!_canRequest) return;
      await MobileAds.instance.initialize();
      _preload();
    } catch (e) {
      debugPrint('Reklam SDK hatası: $e');
    }
  }

  void _preload() {
    if (!_canRequest || _loading || _ad != null) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (err) {
          _ad = null;
          _loading = false;
          debugPrint('Reklam yüklenemedi: ${err.message}');
        },
      ),
    );
  }

  /// Bir gider kaydı kaydedildikten sonra çağrılır.
  /// Sırası gelmişse ve reklam hazırsa tam ekran reklamı gösterir.
  Future<void> onExpenseSaved() async {
    if (!_supported) return;
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_kCounter) ?? 0) + 1;
    await prefs.setInt(_kCounter, count);
    if (count < _everyNRecords) {
      _preload();
      return;
    }
    final last = prefs.getInt(_kLastShown);
    if (last != null &&
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < _minGap) {
      return;
    }
    if (await _show()) {
      await prefs.setInt(_kCounter, 0);
      await prefs.setInt(_kLastShown, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Paylaşılan raporu açan kişiye rapordan önce gösterilir.
  Future<void> showBeforeReport() async {
    if (!_supported) return;
    await _show();
  }

  Future<bool> _show() async {
    final ad = _ad;
    if (ad == null) {
      _preload();
      return false;
    }
    _ad = null;
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _preload();
      },
      onAdFailedToShowFullScreenContent: (a, err) {
        a.dispose();
        _preload();
      },
    );
    try {
      await ad.show();
      return true;
    } catch (e) {
      debugPrint('Reklam gösterilemedi: $e');
      return false;
    }
  }
}
