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
      toast(context, 'Bağlantıyla paylaşma çok yakında geliyor. Rapor şimdilik sadece sende görünüyor.');
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
    final rep = computeReport(vehicle: v, records: store.allRecords, plan: store.maintenanceFor(v));
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      bottomNavigationBar: !preview
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: MaxWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        kShareEnabled
                            ? 'Paylaşınca bu raporun o anki kopyası bir bağlantıyla gönderilir, 30 gün geçerlidir.'
                            : 'Bağlantıyla paylaşma çok yakında. Rapor şimdilik sadece sende.',
                        textAlign: TextAlign.center,
                        style: body(12, color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 8),
                      BigButton(
                        label: kShareEnabled ? 'Raporu paylaş' : 'Paylaş · yakında',
                        icon: Icons.ios_share,
                        dark: !kShareEnabled,
                        onPressed: () => _share(context),
                      ),
                    ],
                  ),
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
                  const SizedBox(height: 16),
                  const SectionHeader('Bakım geçmişi'),
                  const SizedBox(height: 8),
                  if (service.isEmpty)
                    AppCard(child: Text('Kayıtlı bakım yok.', style: body(13, color: AppColors.inkSoft)))
                  else
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (var i = 0; i < service.length; i++)
                            _ReportRow(
                              record: service[i],
                              last: i == service.length - 1,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  const SectionHeader('Kaza ve hasar kayıtları'),
                  const SizedBox(height: 8),
                  if (accidents.isEmpty)
                    AppCard(
                        child: Text('Araç sahibi kaza veya hasar kaydı girmemiş.',
                            style: body(13, color: AppColors.inkSoft)))
                  else
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (var i = 0; i < accidents.length; i++)
                            _AccidentRow(accident: accidents[i], last: i == accidents.length - 1),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    'Bilgiler araç sahibi tarafından girilmiştir · Oluşturulma ${dateNumeric(DateTime.now())} · 30 gün geçerli',
                    textAlign: TextAlign.center,
                    style: body(11, color: AppColors.inkSoft),
                  ),
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

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.good = false});
  final String label;
  final String value;
  final bool good;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: good ? AppColors.okBg : AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(11, weight: FontWeight.w600, color: good ? AppColors.okText : AppColors.inkSoft)),
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

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.record, required this.last});
  final ExpenseRecord record;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final meta = [
      dateShort(r.date),
      if (r.km != null) '${thousands(r.km!)} km',
      if (r.jobs.isNotEmpty) r.jobs.map(jobLabel).join(', '),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintIcon.category(r.category, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: body(14, weight: FontWeight.w700)),
                Text(meta, style: body(12, color: AppColors.inkSoft)),
                if (r.note != null && r.note!.trim().isNotEmpty)
                  Text(r.note!.trim(), style: body(12, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccidentRow extends StatelessWidget {
  const _AccidentRow({required this.accident, required this.last});
  final Accident accident;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final a = accident;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintIcon(Icons.car_crash, a.damageKurus > 0 ? AppColors.catFine : AppColors.catOther,
              a.damageKurus > 0 ? AppColors.catFineTint : AppColors.catOtherTint,
              size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(dateShort(a.date), style: body(14, weight: FontWeight.w700))),
                    Text(money(a.damageKurus),
                        style: display(14,
                            weight: FontWeight.w700,
                            color: a.damageKurus > 0 ? AppColors.lateText : AppColors.ink)),
                  ],
                ),
                Text(a.description, style: body(12, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
