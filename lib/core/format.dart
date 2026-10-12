// Türkçe sayı, para ve tarih biçimleri.
// (intl paketine gerek kalmadan, küçük ve öngörülebilir yardımcılar.)

const kMonthsShort = [
  'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
];
const kMonthsLong = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];
/// "Ekim'de", "Kasım'da", "Aralık'ta"
const kMonthsLocative = [
  "Ocak'ta", "Şubat'ta", "Mart'ta", "Nisan'da", "Mayıs'ta", "Haziran'da",
  "Temmuz'da", "Ağustos'ta", "Eylül'de", "Ekim'de", "Kasım'da", "Aralık'ta",
];

/// "Eylül'e", "Ağustos'a"
const kMonthsDative = [
  "Ocak'a", "Şubat'a", "Mart'a", "Nisan'a", "Mayıs'a", "Haziran'a",
  "Temmuz'a", "Ağustos'a", "Eylül'e", "Ekim'e", "Kasım'a", "Aralık'a",
];
const kWeekdaysShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const kWeekdaysLong = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];

/// 84250 -> "84.250"
String thousands(num n) {
  final neg = n < 0;
  final s = n.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return neg ? '-$b' : b.toString();
}

/// Kuruş -> "₺1.844" veya "₺1.844,15"
String money(int kurus, {bool decimals = false}) {
  final neg = kurus < 0;
  final abs = kurus.abs();
  final lira = abs ~/ 100;
  final rest = abs % 100;
  final showDec = decimals || rest != 0;
  final txt = showDec
      ? '${thousands(lira)},${rest.toString().padLeft(2, '0')}'
      : thousands(lira);
  return '${neg ? '-' : ''}₺$txt';
}

/// Kuruş -> giriş kutusunda düzenlenecek metin: 150050 -> "1500,50", 150000 -> "1500"
String moneyInput(int kurus) {
  final lira = kurus ~/ 100;
  final rest = kurus % 100;
  return rest == 0 ? '$lira' : '$lira,${rest.toString().padLeft(2, '0')}';
}

/// Kullanıcının yazdığı tutarı kuruşa çevirir.
/// "1.500" , "1500", "1.500,50", "1500,5", "1500.50" -> kuruş. Geçersizse null.
int? parseMoney(String input) {
  var s = input.trim().replaceAll('₺', '').replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    // Türkçe biçim: nokta binlik, virgül ondalık
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else {
    // Sadece nokta varsa: son noktadan sonra 1-2 hane ise ondalık, değilse binlik
    final parts = s.split('.');
    if (parts.length > 1 && parts.last.length <= 2 && parts.length == 2) {
      // 1500.5 gibi
    } else {
      s = s.replaceAll('.', '');
    }
  }
  final v = double.tryParse(s);
  if (v == null || v < 0) return null;
  return (v * 100).round();
}

/// "84.250" veya "84250" -> 84250
int? parseKm(String input) {
  final s = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

/// "12,5" -> 12.5
double? parseDecimal(String input) {
  final s = input.trim().replaceAll(',', '.');
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

String decimalText(double v) {
  final t = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return t.replaceAll('.', ',');
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => dateOnly(DateTime.now());

/// Takvim ayı ekler (31 Ocak + 1 ay = 28/29 Şubat).
DateTime addMonths(DateTime d, int months) {
  final y = d.year + ((d.month - 1 + months) ~/ 12);
  final m = ((d.month - 1 + months) % 12) + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > lastDay ? lastDay : d.day);
}

int daysBetween(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inDays;

/// "11 Eki 2026"
String dateShort(DateTime d) => '${d.day} ${kMonthsShort[d.month - 1]} ${d.year}';

/// "11 Ekim 2026"
String dateLong(DateTime d) => '${d.day} ${kMonthsLong[d.month - 1]} ${d.year}';

/// "11 Eki"
String dayMonth(DateTime d) => '${d.day} ${kMonthsShort[d.month - 1]}';

/// "11.10.2026"
String dateNumeric(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// "Pazar, 11 Ekim"
String dateHeader(DateTime d) =>
    '${kWeekdaysLong[d.weekday - 1]}, ${d.day} ${kMonthsLong[d.month - 1]}';

/// Kalan süre: "9 gün", "5 ay", "1 yıl", "bugün", "3 gün geçti"
String timeLeft(DateTime due, {DateTime? from}) {
  final days = daysBetween(from ?? DateTime.now(), due);
  if (days == 0) return 'bugün';
  if (days < 0) {
    final p = -days;
    if (p < 60) return '$p gün geçti';
    return '${(p / 30).round()} ay geçti';
  }
  if (days < 60) return '$days gün';
  if (days < 730) return '${(days / 30.4).round()} ay';
  return '${(days / 365).floor()} yıl';
}

/// Halka içi: sayı ve birim ayrı ("9", "gün"), ("14", "ay"), ("2", "yıl"); bugün ("0", "gün"); geçmiş ("!", "gecikti").
(String, String) timeLeftParts(DateTime due) {
  final days = daysBetween(DateTime.now(), due);
  if (days < 0) return ('!', 'gecikti');
  if (days < 60) return ('$days', 'gün');
  if (days < 730) return ('${(days / 30.4).round()}', 'ay');
  return ('${(days / 365).floor()}', 'yıl');
}

/// Halka içinde kısa gösterim: "9g", "14a", "2y"
String timeLeftShort(DateTime due) {
  final days = daysBetween(DateTime.now(), due);
  if (days < 0) return '!';
  if (days < 60) return '${days}g';
  if (days < 730) return '${(days / 30.4).round()}a';
  return '${(days / 365).floor()}y';
}

/// Selamlama
String greeting() {
  final h = DateTime.now().hour;
  if (h < 6) return 'İyi geceler';
  if (h < 12) return 'Günaydın';
  if (h < 18) return 'İyi günler';
  return 'İyi akşamlar';
}

// ---------------------------------------------------------------------------
// Plaka: tek tip yazım. Kullanıcı boşluk giremez; boşlukları biz koyarız.
// ---------------------------------------------------------------------------

/// Sadece harf ve rakam, büyük harf ("34 abc 123" → "34ABC123"). Türkçe ı/i → I.
String plateKey(String raw) {
  final b = StringBuffer();
  for (final ch in raw.split('')) {
    final c = (ch == 'i' || ch == 'ı' || ch == 'İ') ? 'I' : ch.toUpperCase();
    if (RegExp(r'[A-Z0-9]').hasMatch(c)) b.write(c);
  }
  return b.toString();
}

/// Görünen plaka: "34ABC123" → "34 ABC 123". Yazarken kısmi girişleri de böler
/// ("34A" → "34 A"). Kalıba uymayan plakalar boşluksuz bırakılır.
String formatPlate(String raw) {
  final s = plateKey(raw);
  final m = RegExp(r'^(\d{1,2})([A-Z]{0,3})(\d{0,5})$').firstMatch(s);
  if (m == null) return s;
  return [m.group(1)!, m.group(2)!, m.group(3)!].where((p) => p.isNotEmpty).join(' ');
}
