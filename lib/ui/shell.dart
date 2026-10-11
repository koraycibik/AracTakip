// Ana iskelet: telefonda alttaki yüzen menü, geniş ekranda (Fold açık,
// tablet) soldaki yan menü.

import 'package:flutter/material.dart';

import '../core/layout.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import '../services/notification_service.dart';
import 'screens/garage_screen.dart';
import 'screens/history_tab.dart';
import 'screens/record_add_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/stats_screen.dart';
import 'widgets/dialogs.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0; // 0 garaj, 1 hatırlatma, 2 istatistik, 3 geçmiş

  @override
  void initState() {
    super.initState();
    NotificationService.instance.tappedPayload.addListener(_onNotificationTap);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onNotificationTap());
  }

  @override
  void dispose() {
    NotificationService.instance.tappedPayload.removeListener(_onNotificationTap);
    super.dispose();
  }

  /// Bildirime dokunulunca ilgili yere git.
  void _onNotificationTap() {
    final p = NotificationService.instance.tappedPayload.value;
    if (p == null || !mounted) return;
    NotificationService.instance.tappedPayload.value = null;
    if (p.startsWith('km:')) {
      final v = StoreScope.read(context).vehicle(p.substring(3));
      if (v != null) showKmDialog(context, v);
    } else {
      setState(() => _tab = 1);
    }
  }

  void _openAdd() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecordAddScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final size = layoutOf(context);
    final pages = [
      GarageScreen(twoPane: size == LayoutSize.expanded),
      RemindersScreen(onOpenGarage: () => setState(() => _tab = 0)),
      const StatsScreen(),
      const HistoryTab(),
    ];
    final content = IndexedStack(index: _tab, children: pages);

    if (size == LayoutSize.compact) {
      final mq = MediaQuery.of(context);
      return Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            // Liste içeriği yüzen menünün arkasında kalmasın diye alt boşluğu büyüt.
            MediaQuery(
              data: mq.copyWith(padding: mq.padding.copyWith(bottom: mq.padding.bottom + 96)),
              child: SafeArea(bottom: false, child: content),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: mq.padding.bottom + 14,
              child: _FloatingNav(
                index: _tab,
                onSelect: (i) => setState(() => _tab = i),
                onAdd: _openAdd,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _SideRail(
              index: _tab,
              onSelect: (i) => setState(() => _tab = i),
              onAdd: _openAdd,
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

const _navItems = [
  (Icons.home_outlined, 'Garaj'),
  (Icons.notifications_none, 'Hatırlatma'),
  (Icons.bar_chart, 'İstatistik'),
  (Icons.description_outlined, 'Geçmiş'),
];

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.index, required this.onSelect, required this.onAdd});
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final overdue = StoreScope.of(context).reminders.where((r) => r.isOverdue).length;
    Widget item(int i) {
      final selected = index == i;
      final color = selected ? AppColors.accent : AppColors.inkFaint;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: _navItems[i].$2,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelect(i),
            child: SizedBox(
              height: 68,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Badge(
                    isLabelVisible: i == 1 && overdue > 0,
                    label: Text('$overdue'),
                    child: Icon(_navItems[i].$1, color: color, size: 23),
                  ),
                  const SizedBox(height: 3),
                  Text(_navItems[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: body(11,
                          weight: selected ? FontWeight.w700 : FontWeight.w500, color: color)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: AppColors.ink,
      elevation: 12,
      shadowColor: const Color(0x660E1220),
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            item(0),
            item(1),
            Expanded(
              child: Center(
                child: Tooltip(
                  message: 'Kayıt ekle',
                  child: Material(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: onAdd,
                      child: const SizedBox(
                        width: 54,
                        height: 54,
                        child: Icon(Icons.add, color: AppColors.ink, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            item(2),
            item(3),
          ],
        ),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.index, required this.onSelect, required this.onAdd});
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      color: AppColors.ink,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Tooltip(
            message: 'Kayıt ekle',
            child: Material(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onAdd,
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.add, color: AppColors.ink, size: 28),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < _navItems.length; i++)
            InkWell(
              onTap: () => onSelect(i),
              child: SizedBox(
                height: 72,
                width: 88,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 32,
                      decoration: BoxDecoration(
                        color: index == i ? const Color(0x33FFB020) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(_navItems[i].$1,
                          color: index == i ? AppColors.accent : AppColors.inkFaint),
                    ),
                    const SizedBox(height: 4),
                    Text(_navItems[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: body(11,
                            weight: index == i ? FontWeight.w700 : FontWeight.w500,
                            color: index == i ? AppColors.accent : AppColors.inkFaint)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
