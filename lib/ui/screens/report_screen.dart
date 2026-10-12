// 7 · Araç geçmişi raporu (alıcının göreceği salt okunur görünüm).
//
// Bağlantıyla paylaşma Firebase kurulumundan sonra açılacak: rapor anlık
// kopya olarak shares/{id} belgesine yazılacak, alıcı bağlantıyı uygulamada
// açtığında önce tam ekran reklam, sonra bu ekran gösterilecek.

import 'package:flutter/material.dart';

import '../../core/features.dart';
import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../logic/maintenance.dart';
import '../../logic/report.dart';
import '../widgets/common.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key, required this.vehicleId, this.preview = false});
  final String vehicleId;

  /// Araç sahibinin kendi önizlemesi: altta "Paylaş" butonu çıkar.
  final bool preview;

  void _share(BuildContext context) {
    if (!kShareEnabled) {
      toast(context, 'Bağlantıyla paylaşma çok yakında geliyor.');
      return;
    }
    // Bağlantı oluşturma (shares/{id}) bu adımda eklenecek.
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = store.vehicle(vehicleId);
    if (v == null) return const Scaffold(body: Center(child: Text('Araç bulunamadı')));

    final service = store.recordsFor(v.id).where((r) => r.category.isServiceHistory).toList();
    final maint = service.where((r) => r.category == RecordCategory.maintenance).toList();
    final accidents = store.accidentsFor(v.id);
    final rep = computeReport(vehicle: v, records: store.historyRecords, plan: store.maintenanceFor(v));
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      // Bağlantıyla paylaşma açılınca alttaki sabit buton görünür.
      bottomNavigationBar: !(preview && kShareEnabled)
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Paylaşınca raporun o anki kopyası bir bağlantıyla gönderilir, 30 gün geçerlidir.',
                      textAlign: TextAlign.center,
                      style: body(12, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    BigButton(label: 'Raporu paylaş', icon: Icons.ios_share, onPressed: () => _share(context)),
                  ],
                ),
              ),
            ),
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, 22),
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: MaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SquareIconButton(
                        icon: Icons.close,
                        tooltip: 'Kapat',
                        light: true,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x1FFFFFFF),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(preview ? Icons.visibility_outlined : Icons.lock_outline,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(preview ? 'Önizleme · alıcı böyle görür' : 'Sadece görüntüleme',
                                style: body(12, weight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Araç geçmişi raporu',
                      style: body(13, weight: FontWeight.w600, color: AppColors.navySoft)),
                  const SizedBox(height: 8),
                  PlateBadge(v.plate),
                  const SizedBox(height: 8),
                  Text(
                    [v.title, if (v.year != null) '${v.year}'].join(' · '),
                    style: display(22, weight: FontWeight.w700, color: Colors.white),
                  ),
                  Text('${v.type.label} · ${v.fuelType.label} · son kayıtlı km ${thousands(v.currentKm)}',
                      style: body(13, color: AppColors.navySoft)),
                  const SizedBox(height: 4),
                  Text('Tekerim\'de takip: ${monthYear(rep.trackingSince)} itibarıyla',
                      style: body(12, weight: FontWeight.w600, color: AppColors.accent)),
                ],
              ),
            ),
          ),
          MaxWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _Stat('Bakım kaydı', '${maint.length}')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat('Son bakım',
                            maint.isEmpty ? '—' : '${kMonthsShort[maint.first.date.month - 1]} ${maint.first.date.year}'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat('Yıllık ort. km', rep.kmPerYear == null ? '—' : thousands(rep.kmPerYear!)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader('Belgeler ve süreler'),
                  const SizedBox(height: 8),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < rep.docs.length; i++)
                          _DocRow(doc: rep.docs[i], last: i == rep.docs.length - 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader('Araç geçmişi'),
                  const SizedBox(height: 4),
                  Text('Bakım, lastik, muayene ve kaza kayıtları; en yeniden eskiye.',
                      style: body(12, color: AppColors.inkSoft)),
                  const SizedBox(height: 10),
                  _Timeline(service: service, accidents: accidents, report: rep, vehicle: v),
                  if (rep.kmPoints.length >= 2) ...[
                    const SizedBox(height: 16),
                    const SectionHeader('Kilometre geçmişi'),
                    const SizedBox(height: 8),
                    _KmCard(report: rep),
                  ],
                  if (rep.keyJobs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const SectionHeader('Son yapılan işlemler'),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (var i = 0; i < rep.keyJobs.length; i++)
                            _JobRow(job: rep.keyJobs[i], last: i == rep.keyJobs.length - 1),
                        ],
                      ),
                    ),
                  ],
                  if (rep.plan.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const SectionHeader('Bakım planı durumu'),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (var i = 0; i < rep.plan.length; i++)
                            _PlanRow(status: rep.plan[i], last: i == rep.plan.length - 1),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'Bilgiler araç sahibi tarafından girilmiştir · Oluşturulma ${dateNumeric(DateTime.now())} · 30 gün geçerli',
                    textAlign: TextAlign.center,
                    style: body(11, color: AppColors.inkSoft),
                  ),
                  if (preview && !kShareEnabled) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.catMaintTint, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const Icon(Icons.ios_share, size: 18, color: AppColors.catMaint),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bağlantıyla paylaşma çok yakında.',
                              style: body(12, weight: FontWeight.w600, color: const Color(0xFF1B3FA8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satır kabı: alt çizgili, sabit iç boşluklu.
class _Line extends StatelessWidget {
  const _Line({required this.last, required this.child});
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: child,
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.last});
  final DocStatus doc;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final d = doc;
    final (text, state) = !d.known
        ? ('Bilgi yok', DueState.soon)
        : d.valid
            ? ('Geçerli · ${monthYear(d.until!)}', DueState.ok)
            : ('Süresi geçmiş', DueState.overdue);
    return _Line(
      last: last,
      child: Row(
        children: [
          Expanded(child: Text(d.label, style: body(14, weight: FontWeight.w700))),
          Flexible(child: StatusPill(text, state)),
        ],
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job, required this.last});
  final KeyJob job;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return _Line(
      last: last,
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: AppColors.okText),
          const SizedBox(width: 10),
          Expanded(child: Text(job.label, style: body(14, weight: FontWeight.w700))),
          Text(
            [monthYear(job.date), if (job.km != null) '${thousands(job.km!)} km'].join(' · '),
            style: body(12, weight: FontWeight.w600, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.status, required this.last});
  final MaintenanceStatus status;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final text = switch (s.state) {
      DueState.overdue => 'Gecikmiş',
      DueState.soon => 'Yaklaşıyor',
      DueState.ok => 'Zamanında',
    };
    return _Line(
      last: last,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.item.name, style: body(14, weight: FontWeight.w700)),
                Text(s.leftText, style: body(12, color: AppColors.inkSoft)),
              ],
            ),
          ),
          StatusPill(text, s.state),
        ],
      ),
    );
  }
}

/// Km okumalarının küçük çizgi grafiği + tutarlılık durumu.
class _KmCard extends StatelessWidget {
  const _KmCard({required this.report});
  final VehicleReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final first = r.kmPoints.first;
    final lastP = r.kmPoints.last;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${r.kmPoints.length} km kaydı',
                    style: body(13, weight: FontWeight.w700, color: AppColors.inkSoft)),
              ),
              StatusPill(r.kmConsistent ? 'Km düzenli artıyor' : 'Km kayıtlarında düşüş var',
                  r.kmConsistent ? DueState.ok : DueState.overdue),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: CustomPaint(painter: _KmPainter(r.kmPoints)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('${thousands(first.km)} km\n${monthYear(first.date)}',
                    style: body(12, weight: FontWeight.w600, color: AppColors.inkSoft)),
              ),
              Expanded(
                child: Text('${thousands(lastP.km)} km\n${monthYear(lastP.date)}',
                    textAlign: TextAlign.right,
                    style: body(12, weight: FontWeight.w700, color: AppColors.ink)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KmPainter extends CustomPainter {
  _KmPainter(this.points);
  final List<KmPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final t0 = points.first.date.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.date.millisecondsSinceEpoch.toDouble();
    var minKm = points.first.km.toDouble();
    var maxKm = minKm;
    for (final p in points) {
      if (p.km < minKm) minKm = p.km.toDouble();
      if (p.km > maxKm) maxKm = p.km.toDouble();
    }
    final spanT = (t1 - t0) == 0 ? 1.0 : (t1 - t0);
    final spanK = (maxKm - minKm) == 0 ? 1.0 : (maxKm - minKm);
    Offset at(KmPoint p) => Offset(
          4 + (p.date.millisecondsSinceEpoch - t0) / spanT * (size.width - 8),
          size.height - 4 - (p.km - minKm) / spanK * (size.height - 8),
        );

    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = 4 + i * (size.height - 8) / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final p in points.skip(1)) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = AppColors.accent;
    for (final p in points) {
      canvas.drawCircle(at(p), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_KmPainter old) => old.points != points;
}

class _Ev {
  _Ev({
    required this.date,
    required this.icon,
    required this.color,
    required this.tint,
    required this.title,
    this.meta,
    this.note,
    this.chips = const [],
    this.badge,
  });
  final DateTime date;
  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String? meta;
  final String? note;
  final List<String> chips;
  final String? badge;
}

/// Araç geçmişi zaman çizelgesi: yıllara bölünmüş, en yeni üstte.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.service, required this.accidents, required this.report, required this.vehicle});
  final List<ExpenseRecord> service;
  final List<Accident> accidents;
  final VehicleReport report;
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final evs = <_Ev>[
      for (final r in service)
        _Ev(
          date: r.date,
          icon: categoryStyle(r.category).icon,
          color: categoryStyle(r.category).color,
          tint: categoryStyle(r.category).tint,
          title: r.title,
          meta: [
            if (r.km != null) '${thousands(r.km!)} km',
            if (r.serviceName != null && r.serviceName!.trim().isNotEmpty) r.serviceName!.trim(),
          ].join(' · '),
          chips: [for (final j in r.jobs) jobLabel(j)],
          note: r.note,
        ),
      for (final a in accidents)
        _Ev(
          date: a.date,
          icon: Icons.car_crash,
          color: AppColors.lateText,
          tint: AppColors.lateBg,
          title: 'Kaza / hasar kaydı',
          note: a.description,
          badge: a.damageKurus > 0 ? money(a.damageKurus) : 'Hasarsız',
        ),
      _Ev(
        date: report.trackingSince,
        icon: Icons.flag_outlined,
        color: AppColors.navy,
        tint: AppColors.catMaintTint,
        title: 'Tekerim\'de takip başladı',
        meta: report.firstKm == null ? null : '${thousands(report.firstKm!)} km',
      ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final children = <Widget>[];
    int? year;
    for (var i = 0; i < evs.length; i++) {
      final e = evs[i];
      if (e.date.year != year) {
        year = e.date.year;
        children.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 6, bottom: 8, left: 2),
          child: Text('$year', style: display(15, weight: FontWeight.w800, color: AppColors.inkSoft)),
        ));
      }
      children.add(_TimelineItem(ev: e, first: i == 0, last: i == evs.length - 1));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.ev, required this.first, required this.last});
  final _Ev ev;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final e = ev;
    const lineColor = AppColors.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarih
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Text('${e.date.day}', style: display(17, weight: FontWeight.w800)),
                  Text(kMonthsShort[e.date.month - 1],
                      style: body(11, weight: FontWeight.w700, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ),
          // Çizgi ve nokta
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(width: 2, height: 16, color: first ? Colors.transparent : lineColor),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: e.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: e.color.withValues(alpha: 0.35), blurRadius: 4)],
                  ),
                ),
                Expanded(child: Container(width: 2, color: last ? Colors.transparent : lineColor)),
              ],
            ),
          ),
          // Kart
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TintIcon(e.icon, e.color, e.tint, size: 28),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e.title, style: body(14, weight: FontWeight.w700))),
                        if (e.badge != null)
                          Text(e.badge!, style: display(13, weight: FontWeight.w800, color: e.color)),
                      ],
                    ),
                    if (e.meta != null && e.meta!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(e.meta!, style: body(12, weight: FontWeight.w600, color: AppColors.inkSoft)),
                    ],
                    if (e.chips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in e.chips)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: e.tint, borderRadius: BorderRadius.circular(99)),
                              child: Text(c, style: body(11, weight: FontWeight.w700, color: e.color)),
                            ),
                        ],
                      ),
                    ],
                    if (e.note != null && e.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(e.note!.trim(), style: body(12, color: AppColors.inkSoft)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(11, weight: FontWeight.w600, color: AppColors.inkSoft)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: display(17, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
