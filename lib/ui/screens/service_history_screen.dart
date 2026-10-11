// 6 · Servis geçmişi: tüm kayıtlar, kategori filtreleri, rapor paylaşımı.

import 'package:flutter/material.dart';

import '../../core/features.dart';
import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import 'report_screen.dart';
import 'vehicle_detail_screen.dart';
import 'workshops_screen.dart';

class ServiceHistoryScreen extends StatelessWidget {
  const ServiceHistoryScreen({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ServiceHistoryBody(vehicleId: vehicleId, showBack: true),
      ),
    );
  }
}

enum _Filter {
  all('Tümü', null),
  maintenance('Bakım', {RecordCategory.maintenance}),
  energy('Yakıt / şarj', {RecordCategory.fuel, RecordCategory.charge}),
  tire('Lastik', {RecordCategory.tire}),
  insurance('Sigorta', {RecordCategory.insurance}),
  inspection('Muayene', {RecordCategory.inspection}),
  other('Vergi, ceza, diğer', {RecordCategory.tax, RecordCategory.fine, RecordCategory.other});

  const _Filter(this.label, this.cats);
  final String label;
  final Set<RecordCategory>? cats;
}

class ServiceHistoryBody extends StatefulWidget {
  const ServiceHistoryBody({super.key, required this.vehicleId, this.showBack = false, this.header});
  final String vehicleId;
  final bool showBack;

  /// Geçmiş sekmesinde araç seçici gibi ek başlık.
  final Widget? header;

  @override
  State<ServiceHistoryBody> createState() => _ServiceHistoryBodyState();
}

class _ServiceHistoryBodyState extends State<ServiceHistoryBody> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = store.vehicle(widget.vehicleId);
    if (v == null) return const SizedBox.shrink();
    final all = store.recordsFor(v.id);
    final list = _filter.cats == null ? all : all.where((r) => _filter.cats!.contains(r.category)).toList();
    final total = list.fold<int>(0, (s, r) => s + r.amountKurus);
    final serviceCount = all.where((r) => r.category.isServiceHistory).length;

    return ListView(
      padding: EdgeInsets.only(bottom: bottomSpace(context)),
      children: [
        ScreenHeader(
          title: 'Servis geçmişi',
          subtitle: '${v.plate} · ${v.title}',
          onBack: widget.showBack ? () => Navigator.of(context).maybePop() : null,
        ),
        MaxWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.header != null) ...[widget.header!, const SizedBox(height: 12)],
                if (kCloudEnabled) ...[
                  _ReportCard(
                    serviceCount: serviceCount,
                    accidentCount: store.accidentsFor(v.id).length,
                    onShare: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ReportScreen(vehicleId: v.id))),
                  ),
                  const SizedBox(height: 10),
                ],
                const WorkshopsLinkCard(),
                const SizedBox(height: 14),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _Filter.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final f = _Filter.values[i];
                      return PillChoice(
                        label: f.label,
                        selected: f == _filter,
                        onTap: () => setState(() => _filter = f),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  const EmptyState(
                    icon: Icons.description_outlined,
                    title: 'Kayıt yok',
                    text: 'Bu filtrede henüz kayıt bulunmuyor.',
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 2),
                    child: Text('${list.length} kayıt · toplam ${money(total)}',
                        style: body(13, weight: FontWeight.w600, color: AppColors.inkSoft)),
                  ),
                  for (final r in list) ...[
                    RecordTile(record: r),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.serviceCount, required this.accidentCount, required this.onShare});
  final int serviceCount;
  final int accidentCount;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -70,
            bottom: -90,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.18),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 60,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.fact_check, color: AppColors.navy, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Araç geçmişi raporu',
                            style: display(17, weight: FontWeight.w700, color: Colors.white)),
                        Text(
                          '$serviceCount servis ve $accidentCount kaza kaydı. Bağlantıyla paylaş, alıcı uygulamada açsın.',
                          style: body(13, color: AppColors.navySoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share, size: 20),
                  label: const Text('Raporu paylaş'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.ink,
                    textStyle: display(15, weight: FontWeight.w700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
