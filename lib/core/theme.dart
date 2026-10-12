// Renkler, yazı tipleri ve uygulama teması (tasarım tuvaliyle aynı).

import 'package:flutter/material.dart';

import '../data/models.dart';

class AppColors {
  AppColors._();

  static const bg = Color(0xFFF1F2F6);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFDADDE6);
  static const divider = Color(0xFFEEF0F4);
  static const ink = Color(0xFF0E1220);
  static const inkSoft = Color(0xFF5A6072);
  static const inkFaint = Color(0xFF9AA1B5);
  static const navy = Color(0xFF23295F);
  static const navySoft = Color(0xFFC3C7E6);
  static const accent = Color(0xFFFFB020);
  static const link = Color(0xFF3346C8);
  static const plateBlue = Color(0xFF1F4FD8);

  // Kategori renkleri (ikon / açık zemin)
  static const catFuel = Color(0xFFE8590C);
  static const catFuelTint = Color(0xFFFFE9D9);
  // LPG: yakıttan ayrı gösterildiğinde (açıklık farkıyla da ayırt edilir).
  static const catLpg = Color(0xFF8A5A00);
  static const catLpgTint = Color(0xFFFFF1D6);
  static const catCharge = Color(0xFF0B7FA8);
  static const catChargeTint = Color(0xFFDDF1F8);
  static const catMaint = Color(0xFF2457E6);
  static const catMaintTint = Color(0xFFE1EAFF);
  static const catTire = Color(0xFF6A3FE8);
  static const catTireTint = Color(0xFFECE5FF);
  static const catIns = Color(0xFF0E8A75);
  static const catInsTint = Color(0xFFD9F4EE);
  static const catInsp = Color(0xFF1F8A41);
  static const catInspTint = Color(0xFFDEF2E3);
  static const catTax = Color(0xFFC42A63);
  static const catTaxTint = Color(0xFFFBE1EB);
  static const catFine = Color(0xFFC92A2A);
  static const catFineTint = Color(0xFFFBE0E0);
  static const catOther = Color(0xFF3B4152);
  static const catOtherTint = Color(0xFFE7E9EF);

  // Durum renkleri
  static const okText = Color(0xFF146C34);
  static const okBg = Color(0xFFDCF5E4);
  static const soonText = Color(0xFF8A5A00);
  static const soonBg = Color(0xFFFFF1D6);
  static const lateText = Color(0xFFB42318);
  static const lateBg = Color(0xFFFBE0E0);
  static const ringOrange = Color(0xFFFF8A4C);
  static const ringGreen = Color(0xFF4ADE80);
  static const barGreen = Color(0xFF2BB39A);
}

/// Kategori görünümü: ikon + renk + açık zemin.
class CategoryStyle {
  const CategoryStyle(this.icon, this.color, this.tint);
  final IconData icon;
  final Color color;
  final Color tint;
}

CategoryStyle categoryStyle(RecordCategory c) {
  switch (c) {
    case RecordCategory.fuel:
      return const CategoryStyle(Icons.local_gas_station, AppColors.catFuel, AppColors.catFuelTint);
    case RecordCategory.charge:
      return const CategoryStyle(Icons.ev_station, AppColors.catCharge, AppColors.catChargeTint);
    case RecordCategory.maintenance:
      return const CategoryStyle(Icons.build, AppColors.catMaint, AppColors.catMaintTint);
    case RecordCategory.tire:
      return const CategoryStyle(Icons.tire_repair, AppColors.catTire, AppColors.catTireTint);
    case RecordCategory.insurance:
      return const CategoryStyle(Icons.verified_user, AppColors.catIns, AppColors.catInsTint);
    case RecordCategory.inspection:
      return const CategoryStyle(Icons.fact_check, AppColors.catInsp, AppColors.catInspTint);
    case RecordCategory.tax:
      return const CategoryStyle(Icons.receipt_long, AppColors.catTax, AppColors.catTaxTint);
    case RecordCategory.fine:
      return const CategoryStyle(Icons.gavel, AppColors.catFine, AppColors.catFineTint);
    case RecordCategory.other:
      return const CategoryStyle(Icons.more_horiz, AppColors.catOther, AppColors.catOtherTint);
  }
}

IconData vehicleIcon(VehicleType t) {
  switch (t) {
    case VehicleType.car:
      return Icons.directions_car;
    case VehicleType.motorcycle:
      return Icons.two_wheeler;
    case VehicleType.atv:
      return Icons.agriculture;
    case VehicleType.van:
      return Icons.airport_shuttle;
    case VehicleType.truck:
      return Icons.local_shipping;
    case VehicleType.minibus:
      return Icons.directions_bus;
    case VehicleType.bus:
      return Icons.directions_bus_filled;
  }
}

IconData fuelIcon(FuelType f) {
  switch (f) {
    case FuelType.gasoline:
    case FuelType.diesel:
      return Icons.local_gas_station;
    case FuelType.gasolineLpg:
      return Icons.oil_barrel;
    case FuelType.hybrid:
      return Icons.water_drop_outlined;
    case FuelType.pluginHybrid:
      return Icons.battery_charging_full;
    case FuelType.electric:
      return Icons.electric_bolt;
  }
}

/// Başlık ve rakam yazı tipi (Sora). Sora'da ₺ olmadığı için yedek font var.
TextStyle display(double size,
    {FontWeight weight = FontWeight.w700, Color color = AppColors.ink, double? letterSpacing, double? height}) {
  return TextStyle(
    fontFamily: 'Sora',
    fontFamilyFallback: const ['PlusJakartaSans'],
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing ?? (size >= 24 ? -0.6 : 0.0),
    height: height,
  );
}

/// Gövde yazı tipi (Plus Jakarta Sans).
TextStyle body(double size,
    {FontWeight weight = FontWeight.w400, Color color = AppColors.ink, double? height}) {
  return TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: AppColors.ink,
    surface: AppColors.card,
    onSurface: AppColors.ink,
    error: AppColors.lateText,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'PlusJakartaSans',
    splashFactory: InkRipple.splashFactory,
  );

  return base.copyWith(
    appBarTheme: const AppBarThemeData(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: body(15, color: AppColors.inkFaint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.navy, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.lateText, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: body(14, color: Colors.white, weight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.card,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.ink : null),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.navy : null),
    ),
  );
}
