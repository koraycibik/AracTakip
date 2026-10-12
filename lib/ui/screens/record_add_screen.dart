// 4 · Kayıt ekle / düzenle.
// Form, seçilen aracın yakıt tipine ve kategoriye göre şekillenir.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../data/presets.dart';
import '../../logic/true_cost.dart';
import '../../logic/workshops.dart';
import '../../services/ad_service.dart';
import '../widgets/coach.dart';
import '../widgets/common.dart';
import 'vehicle_form_screen.dart';

class RecordAddScreen extends StatefulWidget {
  const RecordAddScreen({super.key, this.vehicleId, this.editRecordId, this.initialCategory});
  final String? vehicleId;
  final String? editRecordId;
  final RecordCategory? initialCategory;

  @override
  State<RecordAddScreen> createState() => _RecordAddScreenState();
}

class _RecordAddScreenState extends State<RecordAddScreen> {
  String? _vehicleId;
  RecordCategory _cat = RecordCategory.fuel;
  final _amount = TextEditingController();
  final _km = TextEditingController();
  final _kwh = TextEditingController();
  final _service = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = today();
  DateTime? _dueDate;
  DateTime? _nextDate; // sigorta/muayene: yeni bitiş tarihi
  String _insuranceKind = 'traffic'; // traffic | casco
  String _fuelKind = 'gasoline';
  ChargeLocation? _chargeLoc;
  final Set<String> _jobs = {};
  ExpenseRecord? _editing;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final store = StoreScope.read(context);
    if (widget.editRecordId != null) {
      for (final r in store.historyRecords) {
        if (r.id == widget.editRecordId) _editing = r;
      }
    }
    final e = _editing;
    if (e != null) {
      _vehicleId = e.vehicleId;
      _cat = e.category;
      _amount.text = moneyInput(e.amountKurus);
      _km.text = e.km == null ? '' : thousands(e.km!);
      _kwh.text = e.energyKwh == null ? '' : decimalText(e.energyKwh!);
      _service.text = e.serviceName ?? '';
      _note.text = e.note ?? '';
      _date = e.date;
      _dueDate = e.dueDate;
      _fuelKind = e.fuelKind ?? 'gasoline';
      _insuranceKind = e.insuranceKind ?? 'traffic';
      _chargeLoc = e.chargeLocation;
      _jobs.addAll(e.jobs);
    } else {
      final vs = store.vehicles;
      _vehicleId = widget.vehicleId ?? (vs.isEmpty ? null : vs.first.id);
      final v = _vehicleId == null ? null : store.vehicle(_vehicleId!);
      if (v != null) {
        _km.text = thousands(v.currentKm);
        _fuelKind = store.lastFuelKind(v.id) ?? 'gasoline';
        _cat = widget.initialCategory ??
            (v.fuelType.usesFuel ? RecordCategory.fuel : RecordCategory.charge);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_amount, _km, _kwh, _service, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  List<RecordCategory> _categoriesFor(Vehicle v) => [
        if (v.fuelType.usesFuel) RecordCategory.fuel,
        if (v.fuelType.usesCharge) RecordCategory.charge,
        RecordCategory.maintenance,
        RecordCategory.tire,
        RecordCategory.insurance,
        RecordCategory.inspection,
        RecordCategory.tax,
        RecordCategory.fine,
        RecordCategory.other,
      ];

  void _selectVehicle(Vehicle v) {
    setState(() {
      _vehicleId = v.id;
      _km.text = thousands(v.currentKm);
      _fuelKind = StoreScope.read(context).lastFuelKind(v.id) ?? 'gasoline';
      final cats = _categoriesFor(v);
      if (!cats.contains(_cat)) _cat = cats.first;
      _jobs.clear();
    });
  }

  String get _amountLabel {
    switch (_cat) {
      case RecordCategory.fuel:
        return 'Yakıta ödenen tutar';
      case RecordCategory.charge:
        return 'Şarja ödenen tutar';
      default:
        return 'Toplam tutar';
    }
  }

  String? get _reminderHint {
    switch (_cat) {
      case RecordCategory.maintenance:
        return 'İşaretlenen işlemlerin sayaçları bakım planında sıfırlanır.';
      case RecordCategory.tire:
        return 'Mevsimlik lastik hatırlatması bu dönem için kapanır.';
      default:
        return null;
    }
  }

  Future<void> _save() async {
    final store = StoreScope.read(context);
    final v = _vehicleId == null ? null : store.vehicle(_vehicleId!);
    if (v == null) {
      toast(context, 'Önce bir araç seç');
      return;
    }
    final amount = parseMoney(_amount.text);
    if (amount == null) {
      toast(context, 'Tutarı yaz (ör. 1500 ya da 1500,50)');
      return;
    }
    final km = parseKm(_km.text);
    final note = _note.text.trim();
    final service = _service.text.trim();

    final isNew = _editing == null;
    final r = _editing ??
        ExpenseRecord(
          id: newId(),
          vehicleId: v.id,
          category: _cat,
          date: _date,
          amountKurus: amount,
          createdAt: DateTime.now(),
        );
    r
      ..vehicleId = v.id
      ..category = _cat
      ..date = _date
      ..km = km
      ..amountKurus = amount
      ..fuelKind = (_cat == RecordCategory.fuel && v.fuelType.hasLpg) ? _fuelKind : null
      ..energyKwh = _cat == RecordCategory.charge ? parseDecimal(_kwh.text) : null
      ..chargeLocation = _cat == RecordCategory.charge ? _chargeLoc : null
      ..jobs = _cat == RecordCategory.maintenance ? _jobs.toList() : []
      ..serviceName = (_cat.hasService && service.isNotEmpty) ? service : null
      ..note = (_cat.hasNote && note.isNotEmpty) ? note : null
      ..dueDate = _cat == RecordCategory.fine ? _dueDate : null
      ..insuranceKind = _cat == RecordCategory.insurance ? _insuranceKind : null;

    // Sigorta / muayene kaydında yeni bitiş tarihi girildiyse araca yaz.
    if (_nextDate != null) {
      if (_cat == RecordCategory.insurance) {
        if (_insuranceKind == 'traffic') {
          v.trafficInsuranceEndDate = _nextDate;
        } else {
          v.cascoEndDate = _nextDate;
        }
      } else if (_cat == RecordCategory.inspection) {
        v.inspectionDueDate = _nextDate;
      }
    }

    if (isNew) {
      store.addRecord(r);
    } else {
      store.updateRecord(r);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (isNew) {
      // Her 3 gider kaydında 1 tam ekran reklam (kayıt kaydedildikten sonra).
      await AdService.instance.onExpenseSaved();
    }
  }

  Future<void> _delete() async {
    final e = _editing;
    if (e == null) return;
    final ok = await confirm(context, title: 'Kayıt silinsin mi?', message: 'Bu işlem geri alınamaz.');
    if (!ok || !mounted) return;
    StoreScope.read(context).deleteRecord(e.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final vehicles = store.vehicles;
    final v = _vehicleId == null ? null : store.vehicle(_vehicleId!);

    if (vehicles.isEmpty || v == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Kayıt ekle', closeIcon: true),
              Expanded(
                child: Center(
                  child: EmptyState(
                    icon: Icons.directions_car,
                    title: 'Önce bir araç ekle',
                    text: 'Kayıtlar bir araca bağlı tutulur.',
                    action: BigButton(
                      label: 'Araç ekle',
                      dark: true,
                      icon: Icons.add,
                      onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const VehicleFormScreen())),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final cats = _categoriesFor(v);
    final style = categoryStyle(_cat);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: _editing == null ? 'Kayıt ekle' : 'Kaydı düzenle',
              closeIcon: true,
              trailing: _editing == null
                  ? null
                  : SquareIconButton(icon: Icons.delete_outline, tooltip: 'Sil', onTap: _delete),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  MaxWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Plakalar alt alta sarılır: sabit yükseklik yok, taşma ve yana kayma olmaz.
                        PlateSelector(
                          vehicles: vehicles,
                          selected: {v.id},
                          multi: false,
                          onChanged: (s) => _selectVehicle(vehicles.firstWhere((x) => x.id == s.first)),
                        ),
                        const SizedBox(height: 4),
                        Text('${v.title} · ${v.fuelType.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: body(12, color: AppColors.inkSoft)),
                        const SizedBox(height: 14),
                        _CategoryGrid(
                          categories: cats,
                          selected: _cat,
                          onSelect: (c) => setState(() => _cat = c),
                        ),
                        const SizedBox(height: 14),
                        // LPG'li araçta önce ne alındığı seçilir, sonra tutar girilir.
                        if (_cat == RecordCategory.fuel && v.fuelType.hasLpg) ...[
                          _Segmented(
                            options: const {'gasoline': 'Benzin', 'lpg': 'LPG'},
                            value: _fuelKind,
                            onChanged: (k) => setState(() => _fuelKind = k),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _AmountField(
                          controller: _amount,
                          label: (_cat == RecordCategory.fuel && v.fuelType.hasLpg)
                              ? (_fuelKind == 'lpg' ? "LPG'ye ödenen tutar" : 'Benzine ödenen tutar')
                              : _amountLabel,
                          color: style.color,
                        ),
                        if (_cat == RecordCategory.fuel || _cat == RecordCategory.charge)
                          _RangeHint(vehicle: v, amount: _amount),
                        if (_cat == RecordCategory.charge) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: LabeledField(
                                  label: 'Yüklenen enerji',
                                  labelHint: 'isteğe bağlı',
                                  controller: _kwh,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [moneyFormatter],
                                  suffix: 'kWh',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const FieldLabel('Şarj yeri'),
                                    _Segmented(
                                      options: {for (final c in ChargeLocation.values) c.key: c.label},
                                      value: _chargeLoc?.key ?? '',
                                      onChanged: (k) =>
                                          setState(() => _chargeLoc = ChargeLocation.fromKey(k)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DateField(
                                label: 'Tarih',
                                value: _date,
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                                onChanged: (d) => setState(() => _date = d ?? _date),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TipAnchor(
                                tipKey: 'tip_record_km',
                                title: 'Km\'yi de yaz',
                                text: 'Araç göstergesindeki km\'yi girersen 100 km\'nin sana kaça mal olduğunu '
                                    've bir sonraki bakımın ne zaman geleceğini hesaplarız.',
                                child: LabeledField(
                                  label: 'Kilometre',
                                  controller: _km,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [ThousandsFormatter()],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_cat == RecordCategory.maintenance) ...[
                          const SizedBox(height: 14),
                          FieldLabel('Yapılan işlemler', hint: 'bakım planında sıfırlanır'),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final j in jobsFor(v.type, v.fuelType))
                                _JobChip(
                                  label: jobLabel(j),
                                  selected: _jobs.contains(j),
                                  onTap: () => setState(() =>
                                      _jobs.contains(j) ? _jobs.remove(j) : _jobs.add(j)),
                                ),
                            ],
                          ),
                        ],
                        if (_cat == RecordCategory.insurance) ...[
                          const SizedBox(height: 14),
                          const FieldLabel('Hangi poliçe?'),
                          _Segmented(
                            options: const {'traffic': 'Trafik sigortası', 'casco': 'Kasko'},
                            value: _insuranceKind,
                            onChanged: (k) => setState(() => _insuranceKind = k),
                          ),
                          const SizedBox(height: 12),
                          DateField(
                            label: 'Yeni poliçe bitiş tarihi',
                            labelHint: 'hatırlatma için',
                            value: _nextDate,
                            allowClear: true,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            onChanged: (d) => setState(() => _nextDate = d),
                          ),
                        ],
                        if (_cat == RecordCategory.inspection) ...[
                          const SizedBox(height: 14),
                          DateField(
                            label: 'Sonraki muayene tarihi',
                            labelHint: 'hatırlatma için',
                            value: _nextDate,
                            allowClear: true,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            onChanged: (d) => setState(() => _nextDate = d),
                          ),
                        ],
                        if (_cat.hasService) ...[
                          const SizedBox(height: 12),
                          LabeledField(
                            label: 'Servis / usta',
                            controller: _service,
                            hint: 'Ör. Özgür Oto Sanayi',
                            textCapitalization: TextCapitalization.words,
                            maxLength: 80,
                            onChanged: (_) => setState(() {}),
                          ),
                          // Usta defterinden öneriler: aynı usta farklı yazımlarla çoğalmasın.
                          Builder(builder: (context) {
                            final tips = serviceSuggestions(StoreScope.read(context).historyRecords, _service.text);
                            if (tips.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final t in tips)
                                    ActionChip(
                                      avatar: const Icon(Icons.person_outline, size: 16, color: AppColors.catMaint),
                                      label: Text(t, style: body(13, weight: FontWeight.w600)),
                                      backgroundColor: AppColors.catMaintTint,
                                      side: BorderSide.none,
                                      shape: const StadiumBorder(),
                                      onPressed: () => setState(() {
                                        _service.text = t;
                                        _service.selection = TextSelection.collapsed(offset: t.length);
                                      }),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                        if (_cat == RecordCategory.fine) ...[
                          const SizedBox(height: 12),
                          DateField(
                            label: 'Son ödeme tarihi',
                            labelHint: '3 gün önce hatırlatırız',
                            value: _dueDate,
                            allowClear: true,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            onChanged: (d) => setState(() => _dueDate = d),
                          ),
                        ],
                        if (_cat.hasNote) ...[
                          const SizedBox(height: 12),
                          LabeledField(
                            label: (_cat == RecordCategory.maintenance || _cat == RecordCategory.tire)
                                ? 'Ek açıklama'
                                : 'Açıklama',
                            labelHint: (_cat == RecordCategory.maintenance || _cat == RecordCategory.tire)
                                ? 'listede olmayan işler, notlar'
                                : null,
                            controller: _note,
                            maxLines: 4,
                            maxLength: 1000,
                            textCapitalization: TextCapitalization.sentences,
                            hint: switch (_cat) {
                              RecordCategory.fine => 'Ör. Hız ihlali, Ankara–Eskişehir yolu',
                              RecordCategory.tax => 'Ör. MTV 2026, 2. taksit',
                              RecordCategory.other => 'Ör. İç-dış yıkama, otopark, HGS',
                              _ => 'Ör. Klima gazı dolduruldu',
                            },
                          ),
                        ],
                        if (_reminderHint != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.soonBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.notifications_none, color: AppColors.soonText, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_reminderHint!,
                                      style: body(12, weight: FontWeight.w600, color: const Color(0xFF6B4A00))),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: MaxWidth(
                child: BigButton(
                  label: _editing == null ? 'Kaydet' : 'Değişiklikleri kaydet',
                  icon: Icons.check,
                  dark: true,
                  onPressed: _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories, required this.selected, required this.onSelect});
  final List<RecordCategory> categories;
  final RecordCategory selected;
  final ValueChanged<RecordCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const cols = 4;
      final w = (c.maxWidth - (cols - 1) * 8) / cols;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final cat in categories)
            SizedBox(
              width: w,
              child: _CategoryButton(cat: cat, selected: cat == selected, onTap: () => onSelect(cat)),
            ),
        ],
      );
    });
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({required this.cat, required this.selected, required this.onTap});
  final RecordCategory cat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = categoryStyle(cat);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        elevation: selected ? 3 : 0,
        shadowColor: const Color(0x330E1220),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? s.color : Colors.transparent, width: 2.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TintIcon(s.icon, s.color, s.tint, size: 36),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(cat.label, maxLines: 1, style: body(12, weight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Yakıt/şarj tutarının altında: "Bu tutar yaklaşık 540 km'ye yeter · ₺4,85/km".
class _RangeHint extends StatelessWidget {
  const _RangeHint({required this.vehicle, required this.amount});
  final Vehicle vehicle;
  final TextEditingController amount;

  @override
  Widget build(BuildContext context) {
    final per100 = StoreScope.read(context).energyPer100(vehicle);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: amount,
      builder: (context, val, _) {
        final a = parseMoney(val.text);
        String text;
        if (per100 == null || per100 <= 0) {
          text = 'Km\'yi de yazarsan birkaç dolumdan sonra bu tutarın kaç km\'ye yeteceğini ve km başı maliyetini gösteririz.';
        } else if (a == null || a <= 0) {
          text = 'Ortalama km başı maliyetin ${moneyPerKm(per100 / 100)} (100 km ${money(per100)}).';
        } else {
          final km = (a * 100 / per100).round();
          text = 'Bu tutar yaklaşık ${thousands(km)} km\'ye yeter · ortalama ${moneyPerKm(per100 / 100)}/km';
        }
        return FieldNote(text, icon: Icons.route_outlined);
      },
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.label, required this.color});
  final TextEditingController controller;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: body(13, weight: FontWeight.w600, color: AppColors.inkSoft)),
          Row(
            children: [
              Text('₺', style: body(32, weight: FontWeight.w700, color: AppColors.inkFaint)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [moneyFormatter],
                  style: display(36, weight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: '0',
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: UnderlineInputBorder(borderSide: BorderSide(color: color, width: 2)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: color, width: 2)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: color, width: 2.5)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.options, required this.value, required this.onChanged});
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE3E5EC), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final e in options.entries)
            Expanded(
              child: Material(
                color: e.key == value ? AppColors.card : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onChanged(e.key),
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: Text(e.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(13,
                              weight: FontWeight.w700,
                              color: e.key == value ? AppColors.ink : AppColors.inkSoft)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _JobChip extends StatelessWidget {
  const _JobChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.catMaint : AppColors.card,
      shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.catMaint : AppColors.border, width: 2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? Icons.check : Icons.add,
                  size: 16, color: selected ? Colors.white : AppColors.inkSoft),
              const SizedBox(width: 4),
              Text(label,
                  style: body(13,
                      weight: FontWeight.w700, color: selected ? Colors.white : AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
