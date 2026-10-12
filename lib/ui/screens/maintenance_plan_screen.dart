// 13 · Bakım planı: kalemler "X km veya Y ay, hangisi önce dolarsa".
// Kalan km ortalama günlük kullanımla tarihe çevrilir.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../logic/maintenance.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class MaintenancePlanScreen extends StatelessWidget {
  const MaintenancePlanScreen({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = store.vehicle(vehicleId);
    if (v == null) return const Scaffold(body: Center(child: Text('Araç bulunamadı')));
    if (!store.seen('done_plan')) {
      // "Tekerim'i tanı" maddesi: bakım planı açıldı.
      WidgetsBinding.instance.addPostFrameCallback((_) => store.markSeen('done_plan'));
    }
    final avg = store.avgKmPerDay(v);
    final statuses = store.maintenanceFor(v);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(bottom: bottomSpace(context)),
          children: [
            ScreenHeader(title: 'Bakım planı', subtitle: '${v.plate} · ${v.title} · ${v.fuelType.label}'),
            MaxWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(24)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: _HeadStat('Güncel km', thousands(v.currentKm))),
                              Expanded(
                                child: _HeadStat('Ortalama kullanım',
                                    avg == null ? '—' : '${thousands(avg)} km/gün'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  avg == null
                                      ? 'Ortalama için en az iki farklı günde km gerekli. Kayıtlara km yazmayı unutma.'
                                      : 'Km son güncelleme: ${_ago(v.kmUpdatedAt)}. Tahminler kayıtlarındaki km\'lerden hesaplanır.',
                                  style: body(12, color: AppColors.navySoft),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: () => showKmDialog(context, v),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: AppColors.ink,
                                  textStyle: body(13, weight: FontWeight.w700),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Km güncelle'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionHeader(
                      'Bakım kalemleri',
                      trailing: Text('Hangisi önce dolarsa', style: body(12, color: AppColors.inkSoft)),
                    ),
                    const SizedBox(height: 8),
                    for (final s in statuses) ...[
                      _ItemTile(status: s, onTap: () => _edit(context, v, s.item)),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () => _edit(context, v, null),
                      icon: const Icon(Icons.add),
                      label: const Text('Kalem ekle'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: AppColors.catOther,
                        side: const BorderSide(color: Color(0xFFB7BCCB), width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: body(14, weight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aralıklar genel önerilerdir. Aracının kullanım kılavuzundaki değerlere göre düzenleyebilirsin.',
                      style: body(12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime d) {
    final days = daysBetween(d, DateTime.now());
    if (days <= 0) return 'bugün';
    if (days == 1) return 'dün';
    return '$days gün önce';
  }

  Future<void> _edit(BuildContext context, Vehicle v, MaintenanceItem? item) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ItemForm(vehicle: v, item: item),
    );
  }
}

class _HeadStat extends StatelessWidget {
  const _HeadStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: body(12, color: AppColors.navySoft)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: display(24, weight: FontWeight.w800, color: Colors.white)),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.status, required this.onTap});
  final MaintenanceStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final (fg, _) = stateColors(s.state);
    final bar = switch (s.state) {
      DueState.overdue => const Color(0xFFE5484D),
      DueState.soon => AppColors.accent,
      DueState.ok => AppColors.barGreen,
    };
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              const TintIcon(Icons.build, AppColors.catMaint, AppColors.catMaintTint, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.item.name, style: body(14, weight: FontWeight.w700)),
                    Text(s.item.ruleText.isEmpty ? 'Kural yok' : s.item.ruleText,
                        style: body(12, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(s.leftText,
                      style: display(14, weight: FontWeight.w700,
                          color: s.state == DueState.ok ? AppColors.okText : fg)),
                  Text(s.whenText, style: body(11, color: AppColors.inkSoft)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: s.used,
              minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(bar),
            ),
          ),
          if (!s.item.notify)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.notifications_none, size: 14, color: AppColors.inkFaint),
                  const SizedBox(width: 4),
                  Text('Bildirim kapalı', style: body(11, color: AppColors.inkFaint)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemForm extends StatefulWidget {
  const _ItemForm({required this.vehicle, this.item});
  final Vehicle vehicle;
  final MaintenanceItem? item;

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  final _name = TextEditingController();
  final _km = TextEditingController();
  final _months = TextEditingController();
  final _lastKm = TextEditingController();
  DateTime? _lastDate;
  bool _notify = true;
  List<String> _resetJobs = [];

  /// Yeni kalem eklerken tek dokunuşla doldurulan hazır kalemler.
  static const _quick = <(String, int?, int?, List<String>)>[
    ('Triger seti', 90000, 60, ['timing_belt']),
    ('Fren balatası', 40000, null, ['brake_pads']),
    ('Hava filtresi', 20000, 24, ['air_filter']),
    ('Polen filtresi', 15000, 12, ['cabin_filter']),
    ('Antifriz ve fren hidroliği', null, 24, ['coolant', 'brake_fluid']),
    ('Buji', 40000, 48, ['spark_plug']),
    ('Akü kontrolü', null, 12, ['battery_check']),
    ('Klima bakımı', null, 24, ['ac_service']),
  ];

  void _applyQuick((String, int?, int?, List<String>) q) {
    setState(() {
      _name.text = q.$1;
      _km.text = q.$2 == null ? '' : thousands(q.$2!);
      _months.text = q.$3?.toString() ?? '';
      _resetJobs = List.of(q.$4);
    });
  }

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    if (i != null) {
      _name.text = i.name;
      _km.text = i.intervalKm == null ? '' : thousands(i.intervalKm!);
      _months.text = i.intervalMonths?.toString() ?? '';
      _lastKm.text = i.lastDoneKm == null ? '' : thousands(i.lastDoneKm!);
      _lastDate = i.lastDoneDate;
      _notify = i.notify;
      _resetJobs = List.of(i.resetJobs);
    } else {
      _lastKm.text = thousands(widget.vehicle.currentKm);
      _lastDate = today();
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _km, _months, _lastKm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final store = StoreScope.read(context);
    final name = _name.text.trim();
    final km = parseKm(_km.text);
    final months = int.tryParse(_months.text.trim());
    if (name.isEmpty) {
      toast(context, 'Kalemin adını yaz');
      return;
    }
    if ((km == null || km <= 0) && (months == null || months <= 0)) {
      toast(context, 'Km aralığı veya ay aralığından en az birini yaz');
      return;
    }
    final i = widget.item ??
        MaintenanceItem(id: newId(), vehicleId: widget.vehicle.id, name: name);
    i
      ..name = name
      ..intervalKm = (km != null && km > 0) ? km : null
      ..intervalMonths = (months != null && months > 0) ? months : null
      ..lastDoneKm = parseKm(_lastKm.text)
      ..lastDoneDate = _lastDate
      ..notify = _notify
      ..resetJobs = _resetJobs;
    if (widget.item == null) {
      store.addItem(i);
    } else {
      store.updateItem(i);
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await confirm(context,
        title: 'Kalem kaldırılsın mı?', message: '"${widget.item!.name}" bakım planından çıkarılacak.');
    if (!ok || !mounted) return;
    StoreScope.read(context).deleteItem(widget.item!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.item == null ? 'Yeni bakım kalemi' : widget.item!.name,
                style: display(20, weight: FontWeight.w800)),
            if (widget.item == null) ...[
              const SizedBox(height: 12),
              const FieldLabel('Hızlı ekle'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final q in _quick)
                    PillChoice(
                      label: q.$1,
                      selected: _name.text == q.$1,
                      onTap: () => _applyQuick(q),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            LabeledField(
              label: 'Adı',
              controller: _name,
              hint: 'Ör. Klima bakımı',
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Her kaç km\'de',
                    controller: _km,
                    hint: '10.000',
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsFormatter()],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LabeledField(
                    label: 'veya kaç ayda',
                    controller: _months,
                    hint: '12',
                    keyboardType: TextInputType.number,
                    inputFormatters: [digitsOnly],
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
                    label: 'Son yapıldığı km',
                    controller: _lastKm,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsFormatter()],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DateField(
                    label: 'Son yapıldığı tarih',
                    value: _lastDate,
                    lastDate: DateTime.now(),
                    allowClear: true,
                    onChanged: (d) => setState(() => _lastDate = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Expanded(child: Text('Yaklaşınca bildirim gönder', style: body(14, weight: FontWeight.w600))),
                  Switch(value: _notify, onChanged: (b) => setState(() => _notify = b)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BigButton(label: 'Kaydet', icon: Icons.check, dark: true, onPressed: _save),
            if (widget.item != null)
              TextButton(
                onPressed: _delete,
                child: Text('Bu kalemi kaldır',
                    style: body(14, weight: FontWeight.w700, color: AppColors.lateText)),
              ),
          ],
        ),
      ),
    );
  }
}
