// Ekran genişliğine göre düzen kararları (telefon, Fold açık, tablet).

import 'package:flutter/material.dart';

enum LayoutSize { compact, medium, expanded }

/// < 600 dp: tek sütun + alttaki yüzen menü
/// 600–840 dp (Fold açık dikey): yan menü
/// > 840 dp (Fold açık yatay, tablet): yan menü + iki bölme
LayoutSize layoutOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 840) return LayoutSize.expanded;
  if (w >= 600) return LayoutSize.medium;
  return LayoutSize.compact;
}

/// Liste altındaki boşluk (yüzen menünün arkasında kalmasın).
double bottomSpace(BuildContext context) => MediaQuery.paddingOf(context).bottom + 20;

/// İçeriği çok geniş ekranlarda ortalayıp sınırlar.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.maxWidth = 640});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// İki bölmeli düzen. Katlanabilir telefonda dikey menteşe varsa
/// bölmeleri menteşenin iki yanına yerleştirir; içerik menteşeye bölünmez.
class TwoPane extends StatelessWidget {
  const TwoPane({
    super.key,
    required this.start,
    required this.end,
    this.startWidth = 380,
    this.leftOffset = 0,
  });
  final Widget start;
  final Widget end;
  final double startWidth;

  /// Bu bölmenin ekranın sol kenarına uzaklığı (ör. yan menü genişliği).
  final double leftOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final mq = MediaQuery.of(context);
      Rect? hinge;
      for (final f in mq.displayFeatures) {
        final b = f.bounds;
        final vertical = b.height >= b.width;
        if (vertical && b.left > 0 && b.left < mq.size.width) {
          hinge = b;
          break;
        }
      }
      if (hinge != null) {
        final leftW = (hinge.left - leftOffset).clamp(240.0, constraints.maxWidth - 240.0);
        final gap = hinge.width;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: leftW, child: start),
            SizedBox(width: gap),
            Expanded(child: end),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: startWidth, child: start),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE3E5EC)),
          Expanded(child: end),
        ],
      );
    });
  }
}
