// 17 · Usta defterim: kayıtlardaki servis adlarından otomatik oluşan liste.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../data/provinces.dart';
import '../../logic/workshops.dart';
import '../widgets/catalog_picker.dart';
import '../widgets/coach.dart';
import '../widgets/common.dart';

const _palette = [
  (AppColors.catMaint, AppColors.catMaintTint),
  (AppColors.catIns, AppColors.catInsTint),
  (AppColors.catTire, AppColors.catTireTint),
  (AppColors.catFuel, AppColors.catFuelTint),
  (AppColors.catCharge, AppColors.catChargeTint),
  (AppColors.catTax, AppColors.catTaxTint),
];

class WorkshopsScreen extends StatefulWidget {
  const WorkshopsScreen({super.key});

  @override
  State<WorkshopsScreen> createState() => _WorkshopsScreenState();
}

class _WorkshopsScreenState extends State<WorkshopsScreen> {
  /// 0 = harcama, 1 = son ziyaret, 2 = puan
  int _sort = 0;
  Set<String>? _vehicleIds; // null = tüm araçlar

  /// Seçili işlem türleri (çoklu): bakım, lastik, diğer. Varsayılan hepsi.
  Set<String> _kinds = {'maintenance', 'tire', 'other'};
  bool _onlyRated = false;

  static String _kindOf(ExpenseRecord r) => switch (r.category) {
        RecordCategory.maintenance => 'maintenance',
        RecordCategory.tire => 'tire',
        _ => 'other',
      };

  void _toggleKind(String k) {
    final next = {..._kinds};
    if (next.contains(k)) {
      if (next.length == 1) return; // en az biri seçili kalsın
      next.remove(k);
    } else {
      next.add(k);
    }
    setState(() => _kinds = next);
  }
  String? _open;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ids = effectiveSelection(_vehicleIds, store.vehicles);
    final records = store.allRecords.where((r) => _kinds.contains(_kindOf(r))).toList();
    final list = computeWorkshops(records, vehicleIds: ids);
    if (_onlyRated) list.removeWhere((w) => (store.reviewFor(w.key)?.rating ?? 0) == 0);
    final hasAny = computeWorkshops(store.allRecords, vehicleIds: {for (final v in store.vehicles) v.id}).isNotEmpty;
    if (_sort == 1) list.sort((a, b) => b.lastDate.compareTo(a.lastDate));
    if (_sort == 2) {
      int r(Workshop w) => store.reviewFor(w.key)?.rating ?? 0;
      list.sort((a, b) {
        final c = r(b).compareTo(r(a));
        return c != 0 ? c : b.totalKurus.compareTo(a.totalKurus);
      });
    }
    _open ??= list.isEmpty ? null : list.first.key;
    final total = list.fold<int>(0, (s, w) => s + w.totalKurus);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(bottom: bottomSpace(context)),
          children: [
            const ScreenHeader(title: 'Usta defterim', subtitle: 'Servislerine puan ver, not düş'),
            MaxWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasAny) ...[
                      if (store.vehicles.length > 1) ...[
                        PlateSelector(
                          vehicles: store.vehicles,
                          selected: ids,
                          onChanged: (s) => setState(() {
                            _vehicleIds = s;
                            _open = null;
                          }),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          PillChoice(label: 'Bakım', selected: _kinds.contains('maintenance'), onTap: () => _toggleKind('maintenance')),
                          PillChoice(label: 'Lastik', selected: _kinds.contains('tire'), onTap: () => _toggleKind('tire')),
                          PillChoice(label: 'Diğer', selected: _kinds.contains('other'), onTap: () => _toggleKind('other')),
                          PillChoice(
                            label: 'Puan verdiklerim',
                            selected: _onlyRated,
                            color: AppColors.navy,
                            onTap: () => setState(() => _onlyRated = !_onlyRated),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (list.isEmpty && hasAny)
                      const AppCard(
                        child: EmptyState(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'Bu filtreye uyan servis yok',
                          text: 'Araç veya işlem seçimini değiştir.',
                        ),
                      )
                    else if (list.isEmpty)
                      const AppCard(
                        child: EmptyState(
                          icon: Icons.person_outline,
                          title: 'Henüz usta yok',
                          text: 'Bakım veya lastik kaydı girerken "Servis / usta" alanını doldur; burada kendiliğinden listelenir.',
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text('${list.length} servis · toplam ${money(total)}',
                                style: body(13, weight: FontWeight.w600, color: AppColors.inkSoft)),
                          ),
                          _SortToggle(
                            value: _sort,
                            onChanged: (b) => setState(() => _sort = b),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < list.length; i++) ...[
                        _WorkshopCard(
                          workshop: list[i],
                          colors: _palette[list[i].key.hashCode.abs() % _palette.length],
                          open: _open == list[i].key,
                          onToggle: () => setState(() => _open = _open == list[i].key ? '' : list[i].key),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.catMaintTint, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: AppColors.catMaint),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Kayıt girerken servis adını yazmaya başlayınca bu listeden öneri çıkar; aynı usta farklı yazımlarla çoğalmaz. Puanların ve notların hesabına yedeklenir.',
                              style: body(12, weight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
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
}

class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(int v, String label) {
      final sel = value == v;
      return Material(
        color: sel ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(v),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: Text(label,
                style: body(12, weight: FontWeight.w700, color: sel ? AppColors.ink : AppColors.inkSoft)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg(0, 'Harcama'), seg(1, 'Son'), seg(2, 'Puan')]),
    );
  }
}

class _WorkshopCard extends StatelessWidget {
  const _WorkshopCard({
    required this.workshop,
    required this.colors,
    required this.open,
    required this.onToggle,
  });
  final Workshop workshop;
  final (Color, Color) colors;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final w = workshop;
    final names = [
      for (final id in w.vehicleIds)
        if (store.vehicle(id) != null)
          (store.vehicle(id)!.model.isNotEmpty ? store.vehicle(id)!.model : store.vehicle(id)!.plate),
    ];
    final initial = w.name.characters.first.toUpperCase();
    final review = store.reviewFor(w.key);
    final rating = review?.rating ?? 0;
    final meta = [
      if (review?.city != null) review!.city!,
      if (names.isNotEmpty) names.join(', '),
      'son: ${dateShort(w.lastDate)}',
    ].join(' · ');
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: colors.$2, borderRadius: BorderRadius.circular(14)),
                    child: Text(initial, style: display(18, weight: FontWeight.w800, color: colors.$1)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: body(15, weight: FontWeight.w700)),
                        // Puan varsa yıldız + sayı aynı satırda: kart yüksekliği değişmez.
                        Row(
                          children: [
                            if (rating > 0) ...[
                              const Icon(Icons.star_rounded, size: 15, color: AppColors.accent),
                              const SizedBox(width: 2),
                              Text('$rating', style: body(12, weight: FontWeight.w800)),
                              if (review!.note.trim().isNotEmpty) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.sticky_note_2_outlined, size: 13, color: AppColors.inkSoft),
                              ],
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: body(12, color: AppColors.inkSoft)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(money(w.totalKurus), style: display(15, weight: FontWeight.w700)),
                      Text('${w.visits} ziyaret', style: body(12, color: AppColors.inkSoft)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (open) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ReviewBox(workshop: w, review: review),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final j in w.jobs.take(6))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: colors.$2, borderRadius: BorderRadius.circular(99)),
                          child: Text(j, style: body(12, weight: FontWeight.w700, color: colors.$1)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final r in w.records.take(10))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: dateShort(r.date), style: body(13, weight: FontWeight.w700)),
                                TextSpan(
                                  text: ' · ${r.title}${w.vehicleIds.length > 1 && store.vehicle(r.vehicleId) != null ? ' · ${store.vehicle(r.vehicleId)!.plate}' : ''}',
                                  style: body(13, color: AppColors.inkSoft),
                                ),
                              ]),
                            ),
                          ),
                          Text(money(r.amountKurus), style: body(13, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  if (w.records.length > 10)
                    Text('ve ${w.records.length - 10} kayıt daha', style: body(12, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Açılan kartta: yıldızlar (dokununca hemen kaydedilir), not ve "Not ekle" düğmesi.
class _ReviewBox extends StatelessWidget {
  const _ReviewBox({required this.workshop, required this.review});
  final Workshop workshop;
  final WorkshopReview? review;

  @override
  Widget build(BuildContext context) {
    final r = review;
    final note = r?.note.trim() ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(r == null || r.rating == 0 ? 'Puan ver' : 'Puanın',
                  style: body(13, weight: FontWeight.w700)),
              const Spacer(),
              TipAnchor(
                tipKey: 'tip_workshop_rate',
                title: 'Ustana puan ver',
                text: 'Yıldıza dokun, puanın hemen kaydedilir. "Not ve il ekle" ile kendine not düşebilirsin; notların sadece sende.',
                child: StarRating(
                value: r?.rating ?? 0,
                onChanged: (v) {
                  final store = StoreScope.read(context);
                  final x = _copy(r, workshop)..rating = v;
                  store.saveReview(x);
                },
              ),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note, style: body(13, color: AppColors.ink)),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showReviewSheet(context, workshop),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 44),
                foregroundColor: AppColors.link,
                textStyle: body(13, weight: FontWeight.w700),
              ),
              icon: Icon(note.isEmpty ? Icons.edit_note : Icons.edit_outlined, size: 18),
              label: Text(note.isEmpty
                  ? (r?.city == null ? 'Not ve il ekle' : 'Not ekle')
                  : 'Notu düzenle'),
            ),
          ),
        ],
      ),
    );
  }
}

WorkshopReview _copy(WorkshopReview? r, Workshop w) => WorkshopReview(
      key: w.key,
      name: w.name,
      rating: r?.rating ?? 0,
      note: r?.note ?? '',
      city: r?.city,
      updatedAt: DateTime.now(),
    );

/// 5 yıldız. Aynı yıldıza tekrar dokunmak puanı kaldırır.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, required this.onChanged, this.size = 30});
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  static const labels = ['Çok kötü', 'Kötü', 'İdare eder', 'İyi', 'Çok iyi'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: true,
            selected: i <= value,
            label: '$i yıldız, ${labels[i - 1]}',
            child: InkResponse(
              radius: 22,
              onTap: () => onChanged(i == value ? 0 : i),
              child: SizedBox(
                width: size + 6,
                height: 44,
                child: Icon(
                  i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: i <= value ? AppColors.accent : AppColors.inkFaint,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Puan, il ve not penceresi.
Future<void> showReviewSheet(BuildContext context, Workshop w) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReviewSheet(workshop: w),
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.workshop});
  final Workshop workshop;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int _rating;
  String? _city;
  final _note = TextEditingController();
  final _cityCtl = TextEditingController();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final r = StoreScope.read(context).reviewFor(widget.workshop.key);
    _rating = r?.rating ?? 0;
    _city = r?.city;
    _cityCtl.text = _city ?? '';
    _note.text = r?.note ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    _cityCtl.dispose();
    super.dispose();
  }

  Future<void> _pickCity() async {
    final c = await showCatalogPicker(
      context,
      title: 'Servis hangi ilde?',
      items: kProvinces,
      current: _city,
      searchHint: 'İl ara',
      icon: Icons.location_on_outlined,
    );
    if (c == null || !mounted) return;
    setState(() {
      final t = c.trim();
      _city = t.isEmpty ? null : (t.length > 40 ? t.substring(0, 40) : t);
      _cityCtl.text = _city ?? '';
    });
  }

  void _save() {
    final store = StoreScope.read(context);
    final w = widget.workshop;
    store.saveReview(WorkshopReview(
      key: w.key,
      name: w.name,
      rating: _rating,
      note: _note.text.trim(),
      city: _city,
      updatedAt: DateTime.now(),
    ));
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
                const TintIcon(Icons.person_outline, AppColors.catMaint, AppColors.catMaintTint, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.workshop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: display(18, weight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const FieldLabel('Puanın'),
            Row(
              children: [
                StarRating(value: _rating, size: 34, onChanged: (v) => setState(() => _rating = v)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_rating == 0 ? 'Puan yok' : StarRating.labels[_rating - 1],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(13, weight: FontWeight.w600, color: AppColors.inkSoft)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'İl',
              labelHint: 'isteğe bağlı',
              controller: _cityCtl,
              hint: 'Seç',
              readOnly: true,
              onTap: _pickCity,
              suffixIcon: Icons.expand_more,
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Not',
              labelHint: 'sadece sen görürsün',
              controller: _note,
              hint: 'Örn. işçilik temiz, fiyat uygun, randevuya sadık',
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
            BigButton(label: 'Kaydet', icon: Icons.check, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// Servis geçmişindeki "Usta defterim" bağlantı kartı.
class WorkshopsLinkCard extends StatelessWidget {
  const WorkshopsLinkCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ids = {for (final v in store.vehicles) v.id};
    final list = computeWorkshops(store.allRecords, vehicleIds: ids);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkshopsScreen())),
      child: Row(
        children: [
          const TintIcon(Icons.person_outline, AppColors.catMaint, AppColors.catMaintTint, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Usta defterim', style: body(14, weight: FontWeight.w700)),
                Text(
                  list.isEmpty ? 'Servis adı girdikçe burada toplanır' : '${list.length} servis · en çok: ${list.first.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(12, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.ink),
        ],
      ),
    );
  }
}
