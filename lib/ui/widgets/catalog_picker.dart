// Marka / model seçimi için aranabilir alt pencere.
// Listede olmayan bir değer yazılırsa "… olarak kullan" satırıyla aynen kabul edilir.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/vehicle_catalog.dart';

/// Seçilen metni döndürür; kullanıcı kapatırsa null.
Future<String?> showCatalogPicker(
  BuildContext context, {
  required String title,
  required List<String> items,
  String? current,
  String searchHint = 'Ara',
  IconData icon = Icons.directions_car,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PickerSheet(
      title: title,
      items: items,
      current: current,
      searchHint: searchHint,
      icon: icon,
    ),
  );
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.current,
    required this.searchHint,
    required this.icon,
  });
  final String title;
  final List<String> items;
  final String? current;
  final String searchHint;
  final IconData icon;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _useTyped() {
    final t = _query.text.trim();
    if (t.isEmpty) {
      _focus.requestFocus();
      return;
    }
    Navigator.of(context).pop(_capitalize(t));
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim();
    final results = searchTr<String>(widget.items, q, (s) => s);
    final exact = q.isNotEmpty && widget.items.any((s) => normalizeTr(s) == normalizeTr(q));
    final curKey = normalizeTr(widget.current ?? '');
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        // Klavye açıkken pencere ekrandan taşmasın.
        height: math.max(220, math.min(h * 0.8, h - viewInsets - 120)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(widget.title, style: display(20, weight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: _query,
                focusNode: _focus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (results.length == 1) {
                    Navigator.of(context).pop(results.first);
                  } else {
                    _useTyped();
                  }
                },
                style: body(16, weight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search, color: AppColors.inkSoft),
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Temizle',
                          icon: const Icon(Icons.close, color: AppColors.inkSoft),
                          onPressed: () => setState(() => _query.clear()),
                        ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  if (q.isNotEmpty && !exact)
                    _Row(
                      icon: Icons.edit_outlined,
                      label: '"${_capitalize(q)}" olarak kullan',
                      accent: true,
                      onTap: _useTyped,
                    ),
                  for (final s in results)
                    _Row(
                      icon: widget.icon,
                      label: s,
                      selected: normalizeTr(s) == curKey && curKey.isNotEmpty,
                      onTap: () => Navigator.of(context).pop(s),
                    ),
                  if (q.isEmpty)
                    _Row(
                      icon: Icons.edit_outlined,
                      label: 'Listede yok, kendim yazayım',
                      accent: true,
                      onTap: _useTyped,
                    ),
                  if (q.isNotEmpty && results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                      child: Text('Listede bulunamadı. Yukarıdaki satırla yazdığını aynen kullanabilirsin.',
                          style: body(13, color: AppColors.inkSoft)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.accent = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.navy : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: selected
                        ? AppColors.accent
                        : (accent ? AppColors.link : AppColors.inkFaint)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: body(15,
                        weight: FontWeight.w600,
                        color: selected ? Colors.white : (accent ? AppColors.link : AppColors.ink)),
                  ),
                ),
                if (selected) const Icon(Icons.check, size: 20, color: AppColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
