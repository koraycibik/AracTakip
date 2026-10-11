// Marka / model kataloğu.
//
// Veri: assets/data/vehicle_catalog.json (Türkiye pazarı, araç tipine göre).
// Yapı Firestore'a aynen taşınabilir: her araç tipi bir belge olur
// (ör. catalog/car → { brands: [ {brand, models: [...]}, ... ] }).
// Firebase aşamasında sadece `load()` içi değişir; ekranlar aynı kalır.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

class CatalogBrand {
  const CatalogBrand(this.name, this.models);
  final String name;
  final List<String> models;
}

class VehicleCatalog {
  VehicleCatalog._();
  static final VehicleCatalog instance = VehicleCatalog._();

  static const assetPath = 'assets/data/vehicle_catalog.json';

  Map<VehicleType, List<CatalogBrand>> _byType = const {};
  Future<void>? _loading;
  bool get isLoaded => _byType.isNotEmpty;

  /// İlk çağrıda dosyayı okur; sonraki çağrılar aynı sonucu bekler.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      _byType = parse(raw);
    } catch (_) {
      _byType = const {};
      _loading = null; // bir dahaki sefere tekrar dene
    }
  }

  /// JSON → tip bazlı marka listesi (markalar Türkçe alfabeye göre sıralı).
  static Map<VehicleType, List<CatalogBrand>> parse(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final types = data['types'] as Map<String, dynamic>;
    final out = <VehicleType, List<CatalogBrand>>{};
    for (final t in VehicleType.values) {
      final list = (types[t.key] as List?) ?? const [];
      final brands = [
        for (final b in list)
          CatalogBrand(
            (b as Map<String, dynamic>)['brand'] as String,
            List<String>.unmodifiable((b['models'] as List).cast<String>()),
          ),
      ]..sort((a, b) => compareTr(a.name, b.name));
      out[t] = List.unmodifiable(brands);
    }
    return out;
  }

  List<CatalogBrand> brandsFor(VehicleType type) => _byType[type] ?? const [];

  /// Marka adını büyük/küçük harf ve Türkçe karakter farkı gözetmeden bulur.
  CatalogBrand? findBrand(VehicleType type, String name) {
    final key = normalizeTr(name);
    if (key.isEmpty) return null;
    for (final b in brandsFor(type)) {
      if (normalizeTr(b.name) == key) return b;
    }
    return null;
  }

  List<String> modelsFor(VehicleType type, String brand) => findBrand(type, brand)?.models ?? const [];
}

/// Arama için sadeleştirme: küçük harf, Türkçe karakterler Latin karşılığına,
/// boşluk/tire/nokta yok sayılır ("Mercedes Benz" = "mercedes-benz", "C-Elysée" = "celysee").
String normalizeTr(String s) {
  const map = {
    'ç': 'c', 'Ç': 'c', 'ğ': 'g', 'Ğ': 'g', 'ı': 'i', 'I': 'i', 'İ': 'i',
    'ö': 'o', 'Ö': 'o', 'ş': 's', 'Ş': 's', 'ü': 'u', 'Ü': 'u',
    'é': 'e', 'ë': 'e', 'è': 'e', 'á': 'a', 'à': 'a', 'â': 'a', 'î': 'i', 'û': 'u', 'ô': 'o',
  };
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final m = map[ch] ?? ch.toLowerCase();
    if (_keep.hasMatch(m)) b.write(m);
  }
  return b.toString();
}

final _keep = RegExp(r'^[a-z0-9+#]$');

/// Türkçe alfabeye yakın sıralama (Ç, Ğ, İ, Ö, Ş, Ü kendi harflerinin hemen ardından).
int compareTr(String a, String b) {
  const order = 'aâbcçdefgğhıiîjklmnoöpqrsştuüûvwxyz';
  int rank(String ch) {
    final l = ch.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
    final i = order.indexOf(l);
    return i < 0 ? 1000 + l.codeUnitAt(0) : i;
  }

  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final d = rank(a[i]) - rank(b[i]);
    if (d != 0) return d;
  }
  return a.length - b.length;
}

/// Basit arama: başlangıç eşleşmeleri önce, sonra içinde geçenler.
List<T> searchTr<T>(List<T> items, String query, String Function(T) nameOf) {
  final q = normalizeTr(query);
  if (q.isEmpty) return items;
  final starts = <T>[];
  final contains = <T>[];
  for (final it in items) {
    final n = normalizeTr(nameOf(it));
    if (n.startsWith(q)) {
      starts.add(it);
    } else if (n.contains(q)) {
      contains.add(it);
    }
  }
  return [...starts, ...contains];
}
