// 2a/2b · Araç ekle (iki adım) ve araç düzenle.
// Yakıt tipi burada seçilir; sonraki kayıtlar (yakıt / şarj) buna göre şekillenir.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../data/vehicle_catalog.dart';
import '../widgets/catalog_picker.dart';
import '../widgets/common.dart';

class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key, this.editVehicleId});
  final String? editVehicleId;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  int _step = 0;
  final _plate = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _km = TextEditingController();
  final _lastServiceKm = TextEditingController();
  VehicleType _type = VehicleType.car;
  FuelType _fuel = FuelType.gasoline;
  DateTime? _inspection;
  DateTime? _traffic;
  DateTime? _casco;
  bool _tire = true;
  bool _mtv = true;
  Vehicle? _editing;
  bool _init = false;

  bool get _isEdit => _editing != null;

  final _catalog = VehicleCatalog.instance;

  @override
  void initState() {
    super.initState();
    if (!_catalog.isLoaded) {
      _catalog.load().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  List<String> get _brandItems => [for (final b in _catalog.brandsFor(_type)) b.name];
  List<String> get _modelItems => _catalog.modelsFor(_type, _brand.text);

  Future<void> _pickBrand() async {
    final picked = await showCatalogPicker(
      context,
      title: '${_type.label} markası',
      items: _brandItems,
      current: _brand.text,
      searchHint: 'Marka ara',
      icon: vehicleIcon(_type),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (_brand.text.trim().isNotEmpty && normalizeTr(picked) != normalizeTr(_brand.text)) _model.clear();
      _brand.text = picked;
    });
  }

  Future<void> _pickModel() async {
    final picked = await showCatalogPicker(
      context,
      title: '${_brand.text} modeli',
      items: _modelItems,
      current: _model.text,
      searchHint: 'Model ara',
      icon: vehicleIcon(_type),
    );
    if (picked == null || !mounted) return;
    setState(() => _model.text = picked);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    if (widget.editVehicleId != null) {
      final v = StoreScope.read(context).vehicle(widget.editVehicleId!);
      if (v != null) {
        _editing = v;
        _plate.text = v.plate;
        _brand.text = v.brand;
        _model.text = v.model;
        _year.text = v.year?.toString() ?? '';
        _km.text = thousands(v.currentKm);
        _type = v.type;
        _fuel = v.fuelType;
        _inspection = v.inspectionDueDate;
        _traffic = v.trafficInsuranceEndDate;
        _casco = v.cascoEndDate;
        _tire = v.seasonalTireReminder;
        _mtv = v.mtvReminder;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_plate, _brand, _model, _year, _km, _lastServiceKm]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateStep1() {
    final store = StoreScope.read(context);
    final plate = _plate.text.trim();
    if (plate.length < 4) return 'Plakayı yaz (ör. 34 ABC 123)';
    if (store.plateExists(plate, exceptId: _editing?.id)) return 'Bu plaka zaten garajında var';
    if (_brand.text.trim().isEmpty && _model.text.trim().isEmpty) return 'Marka veya model yaz';
    if (parseKm(_km.text) == null) return 'Güncel kilometreyi yaz';
    final y = int.tryParse(_year.text.trim());
    if (_year.text.trim().isNotEmpty && (y == null || y < 1950 || y > DateTime.now().year + 1)) {
      return 'Model yılı geçersiz';
    }
    return null;
  }

  void _next() {
    final err = _validateStep1();
    if (err != null) {
      toast(context, err);
      return;
    }
    if (_isEdit) {
      _saveEdit();
    } else {
      setState(() => _step = 1);
    }
  }

  void _saveNew() {
    final store = StoreScope.read(context);
    final v = Vehicle(
      id: newId(),
      plate: _formatPlate(_plate.text),
      type: _type,
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      year: int.tryParse(_year.text.trim()),
      fuelType: _fuel,
      currentKm: parseKm(_km.text) ?? 0,
      kmUpdatedAt: DateTime.now(),
      inspectionDueDate: _inspection,
      trafficInsuranceEndDate: _traffic,
      cascoEndDate: _casco,
      seasonalTireReminder: _tire,
      mtvReminder: _mtv,
      createdAt: DateTime.now(),
    );
    store.addVehicle(v, lastServiceKm: parseKm(_lastServiceKm.text));
    Navigator.of(context).pop();
    toast(context, '${v.title} garaja eklendi');
  }

  void _saveEdit() {
    final store = StoreScope.read(context);
    final v = _editing!;
    final newKm = parseKm(_km.text) ?? v.currentKm;
    v
      ..plate = _formatPlate(_plate.text)
      ..type = _type
      ..brand = _brand.text.trim()
      ..model = _model.text.trim()
      ..year = int.tryParse(_year.text.trim())
      ..fuelType = _fuel
      ..inspectionDueDate = _inspection
      ..trafficInsuranceEndDate = _traffic
      ..cascoEndDate = _casco
      ..seasonalTireReminder = _tire
      ..mtvReminder = _mtv;
    if (newKm != v.currentKm) {
      store.updateKm(v.id, newKm);
    } else {
      store.updateVehicle(v);
    }
    Navigator.of(context).pop();
    toast(context, 'Araç güncellendi');
  }

  Future<void> _delete() async {
    final v = _editing!;
    final ok = await confirm(context,
        title: '${v.title} silinsin mi?',
        message: 'Araçla birlikte tüm kayıtları, bakım planı ve kaza bilgileri de silinir. Bu işlem geri alınamaz.');
    if (!ok || !mounted) return;
    StoreScope.read(context).deleteVehicle(v.id);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// "34abc123" -> "34 ABC 123"
  String _formatPlate(String raw) {
    final s = raw.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final m = RegExp(r'^(\d{2})([A-ZÇĞİÖŞÜ]{1,3})(\d{2,5})$').firstMatch(s);
    if (m == null) return raw.toUpperCase().trim();
    return '${m.group(1)} ${m.group(2)} ${m.group(3)}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 1) setState(() => _step = 0);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            _TopBand(
              step: _step,
              isEdit: _isEdit,
              plate: _plate,
              onClose: () {
                if (_step == 1) {
                  setState(() => _step = 0);
                } else {
                  Navigator.of(context).maybePop();
                }
              },
              onDelete: _isEdit ? _delete : null,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                children: [
                  MaxWidth(child: _step == 0 ? _stepOne() : _stepTwo()),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: MaxWidth(
                  child: _step == 0
                      ? BigButton(
                          label: _isEdit ? 'Kaydet' : 'Devam',
                          trailingIcon: _isEdit ? null : Icons.arrow_forward,
                          icon: _isEdit ? Icons.check : null,
                          onPressed: _next,
                        )
                      : BigButton(label: 'Aracı kaydet', icon: Icons.check, onPressed: _saveNew),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Araç türü'),
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 3 * 6) / 4;
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in VehicleType.values)
                SizedBox(
                  width: w,
                  child: _ChoiceTile(
                    icon: vehicleIcon(t),
                    label: t.label,
                    selected: _type == t,
                    height: 72,
                    onTap: () => setState(() => _type = t),
                  ),
                ),
            ],
          );
        }),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _brandItems.isEmpty
                  ? LabeledField(
                      label: 'Marka',
                      controller: _brand,
                      hint: _brandHint,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                    )
                  : LabeledField(
                      label: 'Marka',
                      controller: _brand,
                      hint: 'Seç',
                      readOnly: true,
                      onTap: _pickBrand,
                      suffixIcon: Icons.expand_more,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              // Markanın modelleri listede varsa seçici, yoksa serbest yazım.
              child: _modelItems.isEmpty
                  ? LabeledField(
                      label: 'Model',
                      controller: _model,
                      hint: _modelHint,
                      textCapitalization: TextCapitalization.words,
                    )
                  : LabeledField(
                      label: 'Model',
                      controller: _model,
                      hint: 'Seç',
                      readOnly: true,
                      onTap: _pickModel,
                      suffixIcon: Icons.expand_more,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Model yılı',
                controller: _year,
                hint: '2021',
                keyboardType: TextInputType.number,
                inputFormatters: [digitsOnly, LengthLimitingTextInputFormatter(4)],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LabeledField(
                label: 'Güncel km',
                controller: _km,
                hint: '56.400',
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsFormatter()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Yakıt tipi'),
        LayoutBuilder(builder: (context, c) {
          // Telefonda 2 sütun: "Benzin + LPG", "Şarjlı hibrit" kesilmeden sığar.
          final cols = c.maxWidth >= 520 ? 3 : 2;
          final w = (c.maxWidth - (cols - 1) * 8) / cols;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in FuelType.values)
                SizedBox(
                  width: w,
                  child: _ChoiceTile(
                    icon: fuelIcon(f),
                    label: f.label,
                    selected: _fuel == f,
                    height: 52,
                    horizontal: true,
                    onTap: () => setState(() => _fuel = f),
                  ),
                ),
            ],
          );
        }),
        if (_isEdit && _editing!.fuelType != _fuel) ...[
          const SizedBox(height: 10),
          Text('Not: Yakıt tipini değiştirmek mevcut bakım planını değiştirmez; gerekirse bakım planından düzenleyebilirsin.',
              style: body(12, color: AppColors.inkSoft)),
        ],
        if (_isEdit) ...[
          const SizedBox(height: 18),
          ..._dateFields(),
        ],
      ],
    );
  }

  String get _brandHint => switch (_type) {
        VehicleType.car => 'Fiat',
        VehicleType.motorcycle => 'Yamaha',
        VehicleType.atv => 'CFMoto',
        VehicleType.van => 'Ford',
        VehicleType.truck => 'Mercedes-Benz',
        VehicleType.minibus => 'Iveco',
        VehicleType.bus => 'Otokar',
      };

  String get _modelHint => switch (_type) {
        VehicleType.car => 'Egea',
        VehicleType.motorcycle => 'MT-07',
        VehicleType.atv => 'CForce 450',
        VehicleType.van => 'Transit Custom',
        VehicleType.truck => 'Actros',
        VehicleType.minibus => 'Daily',
        VehicleType.bus => 'Kent',
      };

  List<Widget> _dateFields() => [
        DateField(
          label: 'Sonraki muayene',
          value: _inspection,
          allowClear: true,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          onChanged: (d) => setState(() => _inspection = d),
        ),
        const SizedBox(height: 12),
        DateField(
          label: 'Trafik sigortası bitişi',
          value: _traffic,
          allowClear: true,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          onChanged: (d) => setState(() => _traffic = d),
        ),
        const SizedBox(height: 12),
        DateField(
          label: 'Kasko bitişi',
          labelHint: 'varsa',
          value: _casco,
          allowClear: true,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          onChanged: (d) => setState(() => _casco = d),
        ),
        const SizedBox(height: 12),
        _SwitchRow(
          title: 'Mevsimlik lastik hatırlatması',
          subtitle: 'Kasım ve Nisan\'da hatırlat',
          value: _tire,
          onChanged: (b) => setState(() => _tire = b),
        ),
        const SizedBox(height: 8),
        _SwitchRow(
          title: 'MTV hatırlatması',
          subtitle: 'Ocak ve Temmuz taksitleri',
          value: _mtv,
          onChanged: (b) => setState(() => _mtv = b),
        ),
      ];

  Widget _stepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._dateFields(),
        const SizedBox(height: 12),
        LabeledField(
          label: _fuel == FuelType.electric ? 'Son genel kontrol km\'si' : 'Son bakım km\'si',
          labelHint: 'biliyorsan',
          controller: _lastServiceKm,
          hint: 'Ör. 50.000',
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsFormatter()],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.soonBg, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const Icon(Icons.notifications_none, color: AppColors.soonText, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bu tarihlerden önce bildirim göndereceğiz. Bilmediklerini boş bırakıp sonra araç detayından ekleyebilirsin.',
                  style: body(12, weight: FontWeight.w600, color: const Color(0xFF6B4A00)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopBand extends StatelessWidget {
  const _TopBand({
    required this.step,
    required this.isEdit,
    required this.plate,
    required this.onClose,
    this.onDelete,
  });
  final int step;
  final bool isEdit;
  final TextEditingController plate;
  final VoidCallback onClose;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SquareIconButton(
                  icon: step == 1 ? Icons.arrow_back : Icons.close,
                  tooltip: step == 1 ? 'Geri' : 'Kapat',
                  light: true,
                  onTap: onClose,
                ),
                const Spacer(),
                if (isEdit && onDelete != null)
                  SquareIconButton(icon: Icons.delete_outline, tooltip: 'Aracı sil', light: true, onTap: onDelete!)
                else ...[
                  Text('Adım ${step + 1} / 2',
                      style: body(13, weight: FontWeight.w600, color: AppColors.navySoft)),
                  const SizedBox(width: 8),
                  for (var i = 0; i < 2; i++)
                    Container(
                      width: 18,
                      height: 5,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: i <= step ? AppColors.accent : const Color(0x40FFFFFF),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              isEdit ? 'Aracı düzenle' : (step == 0 ? 'Yeni araç ekle' : 'Önemli tarihler'),
              style: display(26, weight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 12),
            if (step == 0) ...[
              Text('Plaka', style: body(13, weight: FontWeight.w600, color: AppColors.navySoft)),
              const SizedBox(height: 8),
              _PlateInput(controller: plate),
            ] else
              Text('Bu tarihlerden önce sana bildirim göndereceğiz.',
                  style: body(14, color: AppColors.navySoft)),
          ],
        ),
      ),
    );
  }
}

class _PlateInput extends StatelessWidget {
  const _PlateInput({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.ink, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-zÇĞİÖŞÜçğıöşü ]')),
                  LengthLimitingTextInputFormatter(12),
                  _UpperCase(),
                ],
                style: display(24, weight: FontWeight.w700, letterSpacing: 2),
                decoration: const InputDecoration(
                  hintText: '34 ABC 123',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
    return newValue.copyWith(text: t);
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 70,
    this.horizontal = false,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    final ic = selected ? AppColors.accent : AppColors.inkSoft;
    // Uzun adlar "..." ile kesilmez, gerekirse biraz küçülür; kutu boyu sabit kalır.
    final text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: body(horizontal ? 13 : 11, weight: FontWeight.w700, color: fg)),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.navy : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? AppColors.navy : AppColors.border, width: 2),
            ),
            child: horizontal
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18, color: ic),
                      const SizedBox(width: 6),
                      Flexible(child: text),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 24, color: ic),
                      const SizedBox(height: 4),
                      text,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: body(14, weight: FontWeight.w700)),
                Text(subtitle, style: body(12, color: AppColors.inkSoft)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
