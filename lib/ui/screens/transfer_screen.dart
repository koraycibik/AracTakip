// Aracı devret: alıcının e-postasına teklif gönder, durumunu izle.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../logic/maintenance.dart';
import '../../services/cloud_service.dart';
import '../../services/transfer_service.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _email = TextEditingController();

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    TransferService.instance.refresh();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final store = StoreScope.read(context);
    final v = store.vehicle(widget.vehicleId);
    if (v == null) return;
    final email = _email.text.trim();
    if (!_emailRe.hasMatch(email)) {
      toast(context, 'Geçerli bir e-posta adresi yaz.');
      return;
    }
    final ok = await confirm(
      context,
      title: '${v.plate} devredilsin mi?',
      message: '$email adresine teklif gönderilecek. Kabul ederse araç ve geçmişi onun garajına geçer, '
          'sende "Satılan araçlar" bölümüne taşınır. Kabul edene kadar hiçbir şey değişmez.',
      ok: 'Teklifi gönder',
      danger: false,
    );
    if (!ok || !mounted) return;
    try {
      await runWithProgress(context, 'Teklif gönderiliyor…', () => TransferService.instance.send(store, v, email));
      if (!mounted) return;
      _email.clear();
      toast(context, 'Teklif gönderildi. Alıcı uygulamayı açınca görecek.');
    } catch (e) {
      if (mounted) toast(context, transferErrorText(e));
    }
  }

  Future<void> _cancel() async {
    final ok = await confirm(context,
        title: 'Teklif geri çekilsin mi?', message: 'Alıcı artık bu teklifi göremez.', ok: 'Geri çek');
    if (!ok || !mounted) return;
    try {
      await runWithProgress(context, 'Geri çekiliyor…', () => TransferService.instance.cancel(widget.vehicleId));
    } catch (e) {
      if (mounted) toast(context, transferErrorText(e));
    }
  }

  void _copyMessage(String plate) {
    Clipboard.setData(ClipboardData(
      text: 'Merhaba, $plate plakalı aracın bakım geçmişini Tekerim uygulamasında sana devrettim. '
          'Tekerim\'i indir, bu e-posta adresinle bağlı Google hesabınla giriş yap; teklif garajında görünecek.',
    ));
    toast(context, 'Mesaj kopyalandı. WhatsApp ya da SMS ile gönderebilirsin.');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = store.vehicle(widget.vehicleId);
    if (v == null) return const Scaffold(body: Center(child: Text('Araç bulunamadı')));

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: TransferService.instance.outgoing,
          builder: (context, out, _) {
            final o = out[v.id];
            final active = o != null && o.status == TransferStatus.pending && !o.expired;
            final showForm = !active && o?.status != TransferStatus.blocked;
            return ListView(
              padding: EdgeInsets.only(bottom: bottomSpace(context)),
              children: [
                ScreenHeader(title: 'Aracı devret', subtitle: '${v.plate} · ${v.title}'),
                MaxWidth(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (o != null) ...[
                          _StatusCard(offer: o, onCancel: _cancel, onCopy: () => _copyMessage(v.plate)),
                          const SizedBox(height: 14),
                        ],
                        if (showForm) ...[
                          Text(
                            'Aracını sattığında bakım geçmişini yeni sahibinin Tekerim hesabına aktarabilirsin.',
                            style: body(14, color: AppColors.inkSoft, height: 1.45),
                          ),
                          const SizedBox(height: 14),
                          LabeledField(
                            label: 'Alıcının e-postası',
                            controller: _email,
                            hint: 'ornek@gmail.com',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const FieldNote(
                              'Alıcı Tekerim\'de bu e-postanın Google hesabıyla giriş yapmış olmalı. '
                              'Teklif 7 gün geçerli; aynı kişiye en fazla 3 kez gönderebilirsin.'),
                          const SizedBox(height: 14),
                          BigButton(label: 'Teklifi gönder', icon: Icons.send, onPressed: _send),
                          const SizedBox(height: 18),
                        ],
                        const _WhatMoves(),
                        if (!CloudService.instance.isLinked) ...[
                          const SizedBox(height: 12),
                          const FieldNote(
                              'İpucu: Kendi hesabını da Google ile bağlarsan alıcı teklifte adını görür.',
                              icon: Icons.person_outline),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.offer, required this.onCancel, required this.onCopy});
  final TransferOffer offer;
  final VoidCallback onCancel;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final (title, text, state) = switch (o.status) {
      TransferStatus.pending when o.expired => (
          'Teklifin süresi doldu',
          '${o.toEmail} 7 gün içinde cevap vermedi. Tekrar gönderebilirsin.',
          DueState.soon
        ),
      TransferStatus.pending => (
          'Teklif bekliyor',
          '${o.toEmail} · ${dateShort(o.expiresAt)} tarihine kadar geçerli. '
              'Alıcı uygulamayı açınca teklifi görecek.',
          DueState.soon
        ),
      TransferStatus.declined => (
          'Teklif reddedildi',
          '${o.toEmail} teklifi reddetti. '
              '${o.attemptsLeft > 0 ? 'Tekrar gönderebilirsin (${o.attemptsLeft} hakkın kaldı).' : 'Bu kişiye gönderme hakkın bitti.'}',
          DueState.overdue
        ),
      TransferStatus.blocked => (
          'Alıcı teklif almak istemiyor',
          '${o.toEmail} bu araç için teklif almayı kapattı.',
          DueState.overdue
        ),
      _ => ('Teklif', o.toEmail, DueState.ok),
    };
    final pending = o.status == TransferStatus.pending && !o.expired;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: display(16, weight: FontWeight.w800))),
              StatusPill(pending ? 'Bekliyor' : (state == DueState.overdue ? 'Reddedildi' : 'Süresi doldu'), state),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: body(13, color: AppColors.inkSoft, height: 1.4)),
          if (pending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Haber ver'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: AppColors.lateText),
                    child: const Text('Geri çek'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Neler geçer / neler geçmez.
class _WhatMoves extends StatelessWidget {
  const _WhatMoves();

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: body(13, height: 1.35))),
            ],
          ),
        );
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yeni sahibe geçenler', style: body(14, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          row(Icons.check_circle, AppColors.okText, 'Araç bilgileri, güncel km ve km geçmişi'),
          row(Icons.check_circle, AppColors.okText, 'Bakım, lastik ve muayene kayıtları (tutarlarıyla)'),
          row(Icons.check_circle, AppColors.okText, 'Bakım planı ve muayene tarihi'),
          row(Icons.check_circle, AppColors.okText, 'Kaza ve hasar kayıtları'),
          row(Icons.check_circle, AppColors.okText, 'Bu kayıtlardaki ustalara verdiğin puan ve notlar'),
          const SizedBox(height: 10),
          Text('Sende kalanlar', style: body(14, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          row(Icons.remove_circle_outline, AppColors.inkSoft, 'Yakıt / şarj, sigorta, vergi, ceza ve diğer giderler'),
          row(Icons.remove_circle_outline, AppColors.inkSoft, 'Trafik sigortası ve kasko tarihleri'),
          const SizedBox(height: 10),
          Text(
            'Devirden sonra araç sende "Satılan araçlar" bölümüne taşınır; harcama özetini görmeye devam edersin, yeni kayıt eklenemez.',
            style: body(12, color: AppColors.inkSoft, height: 1.4),
          ),
        ],
      ),
    );
  }
}
