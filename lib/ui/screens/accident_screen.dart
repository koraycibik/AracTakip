// 8 · Kaza ve hasar geçmişi.
// Tutarlar giderlere ve istatistiğe eklenmez, ama paylaşılan rapora girer.
// Reklam gösterilmez.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../widgets/common.dart';

class AccidentScreen extends StatelessWidget {
  const AccidentScreen({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = store.vehicle(vehicleId);
    if (v == null) return const Scaffold(body: Center(child: Text('Araç bulunamadı')));
    final list = store.accidentsFor(v.id);
    final total = list.fold<int>(0, (s, a) => s + a.damageKurus);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(bottom: bottomSpace(context)),
          children: [
            ScreenHeader(title: 'Kaza ve hasar', subtitle: '${v.plate} · ${v.title}'),
            MaxWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.catMaintTint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.catMaint, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bu kayıtlar masraflarına eklenmez. Araç raporunu paylaştığında alıcı bu kayıtları da görür.',
                              style: body(12, weight: FontWeight.w600, color: const Color(0xFF1B3FA8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    BigButton(
                      label: 'Kaza / hasar kaydı ekle',
                      icon: Icons.add,
                      dark: true,
                      onPressed: () => showAccidentForm(context, v.id),
                    ),
                    const SizedBox(height: 18),
                    SectionHeader(
                      'Kayıtlar',
                      trailing: list.isEmpty
                          ? null
                          : Text('Toplam hasar ${money(total)}',
                              style: body(13, color: AppColors.inkSoft)),
                    ),
                    const SizedBox(height: 8),
                    if (list.isEmpty)
                      const EmptyState(
                        icon: Icons.car_crash,
                        title: 'Kayıt yok',
                        text: 'Hasar sorgusu SMS sonucunu yapıştırıp tutarına 0 da yazabilirsin.',
                      )
                    else
                      for (final a in list) ...[
                        AppCard(
                          radius: 18,
                          onTap: () => showAccidentForm(context, v.id, editing: a),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TintIcon(
                                Icons.car_crash,
                                a.damageKurus > 0 ? AppColors.catFine : AppColors.catOther,
                                a.damageKurus > 0 ? AppColors.catFineTint : AppColors.catOtherTint,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(dateLong(a.date),
                                              style: body(14, weight: FontWeight.w700)),
                                        ),
                                        Text(money(a.damageKurus),
                                            style: display(14,
                                                weight: FontWeight.w700,
                                                color: a.damageKurus > 0
                                                    ? AppColors.lateText
                                                    : AppColors.catOther)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(a.description,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: body(12, color: AppColors.inkSoft)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kaza kaydı ekleme / düzenleme penceresi.
Future<void> showAccidentForm(BuildContext context, String vehicleId, {Accident? editing}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => _AccidentForm(vehicleId: vehicleId, editing: editing),
  );
}

class _AccidentForm extends StatefulWidget {
  const _AccidentForm({required this.vehicleId, this.editing});
  final String vehicleId;
  final Accident? editing;

  @override
  State<_AccidentForm> createState() => _AccidentFormState();
}

class _AccidentFormState extends State<_AccidentForm> {
  late DateTime _date;
  final _amount = TextEditingController();
  final _desc = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _date = e?.date ?? today();
    if (e != null) {
      _amount.text = moneyInput(e.damageKurus);
      _desc.text = e.description;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text?.trim();
    if (t == null || t.isEmpty) {
      if (mounted) toast(context, 'Panoda metin yok. Önce SMS\'i kopyala.');
      return;
    }
    setState(() {
      _desc.text = _desc.text.trim().isEmpty ? t : '${_desc.text.trim()}\n$t';
    });
  }

  void _save() {
    final store = StoreScope.read(context);
    final amount = _amount.text.trim().isEmpty ? 0 : parseMoney(_amount.text);
    if (amount == null) {
      toast(context, 'Tutar geçersiz');
      return;
    }
    final desc = _desc.text.trim();
    if (desc.isEmpty) {
      toast(context, 'Kısa bir açıklama yaz');
      return;
    }
    final e = widget.editing;
    if (e == null) {
      store.addAccident(Accident(
        id: newId(),
        vehicleId: widget.vehicleId,
        date: _date,
        damageKurus: amount,
        description: desc,
      ));
    } else {
      e
        ..date = _date
        ..damageKurus = amount
        ..description = desc;
      store.updateAccident(e);
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.editing!;
    final ok = await confirm(context, title: 'Kayıt silinsin mi?', message: 'Bu işlem geri alınamaz.');
    if (!ok || !mounted) return;
    StoreScope.read(context).deleteAccident(e.id);
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
            Row(
              children: [
                const TintIcon(Icons.car_crash, AppColors.catFine, AppColors.catFineTint, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.editing == null ? 'Yeni kayıt' : 'Kaydı düzenle',
                      style: display(18, weight: FontWeight.w700)),
                ),
                if (widget.editing != null)
                  IconButton(
                    tooltip: 'Sil',
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline, color: AppColors.lateText),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DateField(
                    label: 'Kaza tarihi',
                    value: _date,
                    lastDate: DateTime.now(),
                    onChanged: (d) => setState(() => _date = d ?? _date),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LabeledField(
                    label: 'Hasar tutarı',
                    controller: _amount,
                    hint: '0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [moneyFormatter],
                    suffix: '₺',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Açıklama',
              controller: _desc,
              hint: 'Ör. Arka tampon, karşı taraf kusurlu, sigortadan karşılandı',
              maxLines: 6,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _paste,
                      icon: const Icon(Icons.content_paste, size: 18),
                      label: const Text('SMS sonucunu yapıştır'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: body(13, weight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            BigButton(label: 'Kaydet', icon: Icons.check, dark: true, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
