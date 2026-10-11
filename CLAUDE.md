# Araç Takip — Proje Bağlamı

Bu dosya, claude.ai'daki planlama sohbetinde verilen tüm kararların özetidir. Her oturumun başında oku ve bu kararlara uy. Bir karar değişirse bu dosyayı da güncelle.

## Kullanıcı hakkında

- Türkçe konuş. Kodu ve teknik terimleri gerektiği kadar açıkla.
- Mobil geliştirme tecrübesi yok. Her adımı küçük tut, ne yaptığını ve nedenini kısaca anlat, komutları tek tek ver.
- Bilgisayar: Windows. Git 2.51 kurulu. Test için gerçek bir Android telefon var (USB hata ayıklama ile).
- iOS simülatörü yok (Mac yok). iOS sürümü daha sonra bulut derleme (ör. Codemagic) ile çıkarılacak; kod iOS uyumlu yazılmalı.

## Ürün

Kişinin araç(lar)ını takip ettiği mobil uygulama: muayene, trafik sigortası, kasko, MTV, lastik, bakım, yakıt/şarj ve diğer giderler, kaza/hasar geçmişi, hatırlatma bildirimleri, istatistikler ve paylaşılabilir araç geçmişi raporu.

- Platform: Android + iOS, tek kod tabanı.
- Gelir: **sadece reklam** (AdMob). Premium/abonelik yok.
- Kullanıcıdan **hiçbir şekilde fotoğraf/dosya alınmaz** (OCR, belge kasası yok).
- Araç türleri: otomobil, motosiklet, ATV, kamyonet, kamyon, minibüs, otobüs.

## Teknoloji

- Flutter (Dart), Firebase: Authentication, Cloud Firestore, Hosting. Ayrı backend sunucusu yok.
- Cloud Functions kullanılmıyor (ücretli plan gerektirir). Her şey istemci + Firestore güvenlik kuralları.
- Şu an kullanılan paketler: `shared_preferences`, `flutter_local_notifications` (v22: tüm metotlar named parametreli), `timezone`, `google_mobile_ads` (v9), `flutter_localizations` (SDK). Fontlar `assets/fonts` içinde gömülü (statik ağırlıklar), google_fonts paketi yok.
- Durum yönetimi: paket yok. Tek `AppStore` (ChangeNotifier) + `StoreScope` (InheritedNotifier). Ekranlar `StoreScope.of(context)` ile dinler, butonlarda `StoreScope.read(context)`.
- Grafikler ve halkalar elle çizildi (fl_chart yok). Gezinme `Navigator.push` ile (go_router yok).
- Firebase aşamasında eklenecek: `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`, `sign_in_with_apple`, `app_links`, `share_plus`. Sürümleri eklerken güncelini kontrol et.

## Giriş ve hesap

- **Giriş ekranı yok.** Uygulama açılır açılmaz kullanılır; arka planda Firebase **isimsiz (anonymous) hesap** açılır, veriler yine Firestore'a yazılır.
- Garaj ekranında "Verilerini güvenceye al · Bağla" kartı: tek dokunuşla hesap bağlama (linkWithCredential). `uid` değişmez, veri taşınmaz.
  - Android: Google hesap seçici ("Koray olarak devam et").
  - iOS: Apple ile devam et (Face ID).
  - Yedek: e-posta bağlantısıyla şifresiz giriş (email link; Dynamic Links değil, Firebase Hosting üzerinden).
- **Şifre hiçbir yerde yok.**
- Karşılama ekranında "Hesabım var, giriş yap" → yeni telefona geçen kullanıcı için aynı tek dokunuş pencere.
- Oturum, kullanıcı çıkış yapana / uygulamayı silene kadar açık kalır.
- **Hesap silme zorunlu** (Apple ve Google kuralı): Ayarlar > "Hesabımı ve verilerimi sil" → "SİL" yazdır → yeniden doğrulat → sırayla sil: shares → her aracın records, maintenanceItems, accidents (500'lük batch) → araç → reminders → users/{uid} → Auth hesabı → yerel veriler ve planlı bildirimler. Yarıda kesilirse tekrar çalışabilir olmalı.

## Reklam kuralları

- Tam ekran (interstitial) reklam: **her 3 gider kaydında 1 kez**, kayıt kaydedildikten sonra.
- Araç eklemede ve kaza kaydında reklam yok.
- Banner reklam yok.
- Paylaşılan raporu açan alıcıya rapor gösterilmeden önce tam ekran reklam.
- Sayaç ve son reklam zamanı telefonda (shared_preferences). İki reklam arası en az ~2 dk.
- iOS'ta ATT izni, AB/Türkiye için Google UMP onay ekranı gerekli.

## Ekranlar

0. **Karşılama:** tanıtım, "Hemen başla", "Hesabım var, giriş yap", KVKK/gizlilik bağlantıları.
1. **Garajım:** "Verilerini güvenceye al" kartı (hesap bağlı değilse), öne çıkan araç kartı (lacivert, Türk plakası, kalan süre halkaları: kasko/muayene/lastik), diğer araçlar listesi, "Yeni araç ekle". Sağ üstte ayarlar ve bildirim (rozetli) butonları.
2a. **Araç ekle, adım 1:** plaka (TR plakası görünümlü giriş), araç türü (7 seçenek), marka ve model (araç tipine göre listeden aranarak seçilir, listede yoksa "… olarak kullan" ile serbest yazılır; kasa tipi/SUV yok), yıl, güncel km, yakıt tipi (Benzin, Dizel, LPG, Benzin+LPG, Hibrit, Elektrik; şarj edilebilir hibrit eklenmesi tartışmada).
2b. **Araç ekle, adım 2:** sonraki muayene, trafik sigortası bitişi, kasko bitişi (isteğe bağlı), son bakım km'si, mevsimlik lastik hatırlatması (Kasım/Nisan). MTV (Ocak/Temmuz) otomatik. Kaydedince garaja döner, reklam yok.
3. **Araç detayı:** km (güncelle butonu), bu ay harcama, yakıt/şarj ₺/100 km, durum kutuları (kasko, trafik sig., muayene, kış lastiği, MTV, yaklaşan bakım kalemi), altta 3 kart: Bakım planı, Servis geçmişi, Kaza/hasar.
4. **Kayıt ekle** (kaydırılan form): üstte araç seçimi; kategoriler: Yakıt (elektrikli araçta **Şarj**), Bakım, Lastik, Sigorta, Muayene, Vergi, Ceza, Diğer. Büyük TL tutar alanı, tarih, km.
   - Yakıt: **sadece TL tutar** (litre yok). Benzin+LPG araçta Benzin/LPG seçimi.
   - Şarj: TL + isteğe bağlı kWh + şarj yeri (Ev / AC / DC).
   - Bakım: "Yapılan işlemler" çoklu seçim (motor yağı, yağ filtresi, hava filtresi, polen filtresi, yakıt filtresi, buji, triger seti, fren balatası, antifriz; elektrikli araçta: genel kontrol, polen filtresi, fren balatası, fren hidroliği, klima bakımı) + servis/usta + ek açıklama. İşaretlenen işlemler bakım planındaki ilgili sayaçları sıfırlar.
   - Lastik: yapılan işlem + servis/usta + açıklama.
   - Açıklama alanı olan kategoriler: Bakım, Lastik, Vergi, Ceza, Diğer.
   - Ceza: son ödeme tarihi hatırlatması.
5. **Reklam:** her 3 gider kaydında 1 tam ekran reklam.
6. **Servis geçmişi:** kategori filtreleri, renkli ikonlu liste, üstte "Raporu paylaş".
7. **Paylaşılan rapor (alıcı):** salt okunur; araç özeti, bakım kaydı sayısı, son bakım, muayene durumu, bakım geçmişi, **kaza ve hasar kayıtları**. Bakım tutarları raporda yok. Alt not: "Bilgiler araç sahibi tarafından girilmiştir · Rapor kodu · 30 gün geçerli".
8. **Kaza ve hasar geçmişi:** tarih, hasar tutarı (0 olabilir), açıklama ("SMS sonucunu yapıştır" butonu: hasar sorgusu SMS'i panodan yapıştırılır). Bu tutarlar **giderlere/istatistiğe dahil edilmez**, ama paylaşılan rapora girer.
9. **İstatistik:** dönem filtresi Hafta / Ay / 6 Ay / Yıl / Özel (başlangıç-bitiş tarihi), araç filtresi (Tüm araçlar veya tek araç), çubuk grafik, toplam, yapılan km, ₺/100 km, kategori dağılımı.
10. **Hatırlatmalar:** en yakın hatırlatma kartı, sekmeler: Yaklaşan / Geciken / Tamamlanan.
11. **Ayarlar:** hesap bilgisi, bildirimler (açık/kapalı, saat 09:00, kaç gün önce 30·7·1), KVKK, gizlilik, bize ulaş, çıkış, hesap silme.
12. **Hesabını bağla:** alttan açılan tek dokunuşluk pencere (platforma göre Google veya Apple), e-posta bağlantısı, "Şimdi değil".
13. **Bakım planı:** güncel km, ortalama km/gün, "Km güncelle"; kalemler (ad, kural "10.000 km / 12 ay", kalan km/süre, tahmini tarih, doluluk çubuğu, durum rengi); kaleme dokununca düzenleme (km aralığı, ay aralığı, son yapıldığı km ve tarih, bildirim açık/kapalı, kaldır); "Kalem ekle".
14. **Bildirimler:** km'yi bildirimden güncelleme, bakım yaklaşıyor, gecikti, poliçe bitiyor, ay sonu özeti.
15. **Yaklaşan gider tahmini:** garajda "Önümüzdeki 90 gün beklenen gider" şeridi → ekran: araç sekmeleri, aylık çubuklar, tarihi belli kalemler (poliçe, muayene, MTV, mevsimlik lastik, bakım, ceza; tutar = aynı türdeki son kayıt, yoksa "Bilinmiyor"), yakıt/şarj ortalaması (son 90 gün).
16. **Gerçek maliyet:** araç detayındaki "Gerçek maliyet ›" kutusu → günlük / km başı / aylık / toplam; Son 12 ay · Eklediğimden beri; km başına kategori dağılımı; araç karşılaştırması. Kaza tutarları dahil değil.
17. **Usta defterim:** servis geçmişinde bağlantı kartı → kayıtlardaki serviceName'den otomatik (Türkçe karakter/büyük-küçük farkı aynı usta), ziyaret, toplam, son ziyaret, işlemler, geçmiş; sıralama Harcama / Son ziyaret. Kayıt ekranında servis adı önerileri.
18. **Ay sonu özeti:** her ayın 1'inde bildirim ("Eylül özetin hazır") → ekran: toplam, önceki aya göre %, yol, kayıt, ₺/100 km, öne çıkanlar, araç bazında; önceki/sonraki ay. İstatistik ekranında da kartı var.

## Bakım ve hatırlatma mantığı

- Her aracın bakım planı: kalemler "X km **veya** Y ay, hangisi önce dolarsa". Araç eklenince **sadece periyodik bakım** yazılır (aralık türe göre öneri; elektrikli araçta "genel kontrol"). Diğer kalemleri kullanıcı bakım planında "Kalem ekle" > "Hızlı ekle" ile ekler (triger, balata, filtreler, antifriz, buji, akü, klima).
- Ortalama km/gün: son 90 günün km'li kayıtlarından ((son km − ilk km) ÷ gün). En az 2 km'li kayıt yoksa sadece süre bazlı hatırlatma.
- Kalan km ÷ ortalama km/gün → tahmini tarih; bildirim o tarihten önceye kurulur (~1.000 km kala ve süre dolmadan önce).
- 2–3 haftada bir "X'in kilometresi kaç?" bildirimi; bildirimden tek dokunuşla güncellenir, tahminler yeniden hesaplanır.
- Hatırlatmaların çoğu saklanmaz, her açılışta araç tarihlerinden ve bakım planından hesaplanır. `reminders` koleksiyonu sadece kullanıcı kararlarını (tamamlandı/ertelendi) tutar.
- Bildirimler yerel planlı bildirim (flutter_local_notifications). iOS'ta en fazla 64 planlı bildirim → sadece en yakınları kur, her açılışta yeniden planla.

## Paylaşılan rapor

- "Raporu paylaş" → Firestore `shares/{shareId}` belgesine anlık kopya (snapshot) yazılır, bağlantı paylaşılır (WhatsApp vb.).
- Bağlantı uygulama kuruluysa uygulamada açılır (app links / universal links), kurulu değilse mağaza sayfasına yönlendirir (Firebase Hosting'de küçük web sayfası).
- PDF dosyası paylaşılmaz (her uygulama açabildiği için).
- Bağlantı 30 gün geçerli, sahibi iptal edebilir. Android'de rapor ekranında ekran görüntüsü engellenebilir (FLAG_SECURE).

## Veritabanı (Firestore) özeti

Ayrıntılı şema claude.ai'daki "Araç Takip · Veritabanı Şeması" dokümanında. Özet:

- Para **kuruş cinsinden tam sayı** (`amountKurus`), km tam sayı, tarihler `Timestamp`. Sabit seçenekler İngilizce anahtar, ekranda Türkçe.
- `users/{uid}`: email?, authProviders, settings {notificationsEnabled, notifyTime "09:00", leadDays [30,7,1], kmPromptDays 14}
- `users/{uid}/vehicles/{vehicleId}`: ownerUid, plate, plateNormalized, type (car|motorcycle|atv|van|truck|minibus|bus), brand, model, year, fuelType (gasoline|diesel|lpg|gasoline_lpg|hybrid|plugin_hybrid|electric), currentKm, kmUpdatedAt, avgKmPerDay, inspectionDueDate?, trafficInsuranceEndDate?, cascoEndDate?, seasonalTireReminder, mtvReminder, sortOrder, archived
- `…/vehicles/{vehicleId}/records/{recordId}`: ownerUid, vehicleId, category (fuel|charge|maintenance|tire|insurance|inspection|tax|fine|other), date, km?, amountKurus, fuelKind?, energyKwh?, chargeLocation? (home|ac|dc), jobs?[], serviceName? (≤80), note? (≤1000), dueDate?, insuranceKind? (traffic|casco; sigorta kaydında)
- `…/vehicles/{vehicleId}/maintenanceItems/{itemId}`: presetKey?, name, intervalKm?, intervalMonths?, lastDoneKm?, lastDoneDate?, resetJobs[], notify, sortOrder
- `…/vehicles/{vehicleId}/accidents/{accidentId}`: date, damageKurus, description (≤2000)
- `users/{uid}/reminders/{reminderId}`: vehicleId, sourceType, sourceId?, dueDate, status (done|dismissed|snoozed), snoozedUntil?
- `catalog/{car|motorcycle|atv|van|truck|minibus|bus}` (kök, herkese açık okunur, sadece konsoldan yazılır): { brands: [ {brand, models: [...]} ] }. Kaynak dosya `assets/data/vehicle_catalog.json` (Türkiye pazarı, ODMD 2025 marka listesi + eski/ikinci el markalar; 188 marka, ~1.290 model). Firebase'e geçince her tip bir belge olarak yüklenir, `VehicleCatalog.load()` önce Firestore'u, olmazsa gömülü dosyayı okur.
- `shares/{shareId}` (kök, herkese açık okunur): ownerUid, vehicleId, code ("AT-7K2Q"), createdAt, expiresAt (+30 gün), revoked, snapshot
- Elle tanımlanacak birleşik indeksler: records collection group (ownerUid + date), records (category + date desc).
- Güvenlik kuralları: herkes sadece `users/{kendi uid}` dalına erişir; records/accidents yazımında tutar tam sayı ve ≥ 0, açıklama uzunluk sınırı; alt koleksiyonlar için genel `{sub}/{doc}` kuralı **kullanılmaz** (doğrulamayı boşa çıkarır); shares: `get` sadece revoked=false ve süresi dolmamışsa, `list` sadece sahibine. Kurallar Firebase Emulator testleriyle doğrulanmalı.
- Telefonda (shared_preferences): reklam sayacı, son reklam zamanı, planlı bildirim kimlikleri, son km sorusu zamanı, "hesabını bağla" kartının kapatılma zamanı.

## Ekran uyumluluğu (Samsung Fold/Flip dahil)

- Sabit telefon boyutu yok; genişliğe göre düzen:
  - < 600 dp: tek sütun, alttaki yüzen menü.
  - 600–840 dp (Fold açık dikey): yan menü (koyu, 88 dp).
  - > 840 dp (Fold açık yatay, tablet): yan menü + garajda iki bölme (solda liste, sağda seçili araç; `TwoPane` menteşeyi hesaba katar).
- Hiçbir ekranda sabit yükseklik yok; her ekran kaydırılabilir.
- Menteşe: `MediaQuery.displayFeatures` ile okunur, içerik menteşeye bölünmez.
- Katlama/açmada form durumu kaybolmaz (form durumu StatefulWidget'larda, veri AppStore'da).
- Büyük yazı ayarıyla (1,3×'e kadar) taşma olmamalı.
- Test: gerçek telefon + Android Studio emülatöründe Fold ve resizable profiller.

## Tasarım dili

- Fontlar: **Sora** (başlıklar, rakamlar, plaka), **Plus Jakarta Sans** (gövde). Google Fonts.
- Renkler:
  - Zemin `#F1F2F6`, kart `#FFFFFF`, kenarlık `#DADDE6`
  - Metin `#0E1220`, ikincil metin `#5A6072`
  - Ana koyu (araç kartı, başlık alanları) lacivert `#23295F`, açık yazı üstünde ikincil `#C3C7E6`
  - Vurgu (amber) `#FFB020`: ana butonlar, menüdeki "+" butonu, aktif sekme
  - Alt menü: yüzen koyu bar `#0E1220`, pasif ikon `#9AA1B5`, aktif ikon vurgu rengi
- Kategori renkleri (ikon / açık zemin):
  - Yakıt `#E8590C` / `#FFE9D9`
  - Şarj `#0B7FA8` / `#DDF1F8`
  - Bakım `#2457E6` / `#E1EAFF`
  - Lastik `#6A3FE8` / `#ECE5FF`
  - Sigorta `#0E8A75` / `#D9F4EE`
  - Muayene `#1F8A41` / `#DEF2E3`
  - Vergi `#C42A63` / `#FBE1EB`
  - Ceza `#C92A2A` / `#FBE0E0`
  - Diğer `#3B4152` / `#E7E9EF`
- Durum renkleri:
  - Normal: yazı `#146C34`, zemin `#DCF5E4`
  - Yaklaşıyor: yazı `#8A5A00`, zemin `#FFF1D6`
  - Gecikti: yazı `#B42318`, zemin `#FBE0E0`
- Köşe yarıçapları: büyük kartlar 22–28, kartlar 18–20, giriş alanları 14, butonlar 16–18. Dokunma alanları ≥ 44.
- Türk plakası bileşeni: beyaz zemin, siyah kenarlık, solda mavi (`#1F4FD8`) "TR" şeridi.
- Kalan süre halkaları (dairesel ilerleme), kategori ikonları renkli kare içinde, emoji yok.
- Tasarım tuvali claude.ai'da: "Araç Takip Uygulaması Tasarımları" (16 ekran).

## Mevcut durum (11 Ekim 2026)

Uygulama **yerel (cihazda saklanan) modda tamamlandı**: tüm ekranlar, bakım planı, hatırlatma hesapları, yerel bildirimler, istatistik, kaza geçmişi, rapor ön izlemesi, test reklamları, hesap/veri silme.

- Veri: `lib/data/app_store.dart` tüm veriyi shared_preferences'ta tek JSON olarak tutar. Firebase'e geçişte sadece bu sınıfın load/_save kısmı Firestore'a bağlanacak; modeller (`lib/data/models.dart`) Firestore şemasıyla birebir aynı.
- Klasörler: `lib/core` (tema, biçimler, düzen), `lib/data` (modeller, hazır bakım kalemleri, marka/model kataloğu, depo), `lib/logic` (km, bakım durumu, hatırlatmalar, istatistik, gider tahmini `forecast.dart`, gerçek maliyet `true_cost.dart`, usta defteri `workshops.dart`, ay özeti `month_summary.dart`), `lib/services` (bildirim, reklam), `lib/ui` (shell, screens, widgets).
- Testler: `test/widget_test.dart`, `test/features_test.dart` (`flutter test`).
- Henüz yapılmayanlar (Firebase aşaması): isimsiz giriş + Google/Apple/e-posta bağlantısıyla hesap bağlama, Firestore senkronu, rapor bağlantısı paylaşma (shares + app links + hosting/rapor.html), hesap silmede bulut verisinin silinmesi. Arayüzde bu yerler "bulut kurulumu tamamlanınca açılacak" notu gösteriyor (`showLinkAccountSheet`, `ReportScreen`).
- Yayın öncesi: AdMob test kimliklerini gerçekleriyle değiştir (AndroidManifest, Info.plist, `ad_service.dart`), KVKK/gizlilik metinlerini ve destek e-postasını doldur (`settings_screen.dart`), uygulama ikonu ve imza ayarı.
- Firebase dosyaları hazır: `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `hosting/rapor.html`.

## Çalışma yolu (önerilen sıra)

1. Ortam kurulumu: Flutter SDK (C:\dev), Android Studio, `flutter doctor`, telefonda USB hata ayıklama.
2. `flutter create` ile proje; klasör yapısı (feature bazlı: `lib/features/garage`, `vehicle`, `records`, `maintenance`, `stats`, `reminders`, `share`, `settings`, `auth`; `lib/core` tema, router, firebase).
3. Tema (renkler, fontlar), router, alt menü; sahte verilerle ekran iskeletleri.
4. Firebase projesi, FlutterFire CLI, anonymous auth, Firestore modelleri ve repository'ler.
5. Araç ekleme → kayıt ekleme → araç detayı → istatistik.
6. Bakım planı ve yerel bildirimler.
7. Kaza geçmişi, paylaşılan rapor (Hosting + app links).
8. Hesap bağlama (Google/Apple/e-posta link), hesap silme.
9. AdMob (test reklam birimleriyle), UMP onayı, ATT.
10. Güvenlik kuralları + emulator testleri, katlanabilir/ekran testleri, mağaza hazırlığı.

Kodlamada: önce çalışan küçük adım, sonra genişlet. Her adımdan sonra kullanıcıya telefonda nasıl deneyeceğini söyle.
