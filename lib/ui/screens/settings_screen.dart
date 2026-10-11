// 11 · Ayarlar: hesap, bildirimler, hakkında, hesap ve veri silme.

import 'package:flutter/material.dart';

import '../../core/features.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../services/cloud_service.dart';
import '../../services/notification_service.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    final time = '${s.notifyHour.toString().padLeft(2, '0')}:${s.notifyMinute.toString().padLeft(2, '0')}';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(bottom: bottomSpace(context)),
          children: [
            const ScreenHeader(title: 'Ayarlar'),
            MaxWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AccountCard(),
                    const SizedBox(height: 18),
                    _GroupTitle('BİLDİRİMLER'),
                    _Group(children: [
                      _Row(
                        title: 'Hatırlatma bildirimleri',
                        trailing: Switch(
                          value: s.notificationsEnabled,
                          onChanged: (b) async {
                            if (b) await NotificationService.instance.requestPermission();
                            store.updateSettings((x) => x.notificationsEnabled = b);
                          },
                        ),
                      ),
                      _Row(
                        title: 'Bildirim saati',
                        value: time,
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: s.notifyHour, minute: s.notifyMinute),
                            helpText: 'Bildirim saati',
                          );
                          if (t != null) {
                            store.updateSettings((x) {
                              x.notifyHour = t.hour;
                              x.notifyMinute = t.minute;
                            });
                          }
                        },
                      ),
                      _Row(
                        title: 'Kaç gün önce',
                        value: (List.of(s.leadDays)..sort((a, b) => b.compareTo(a))).join(' · '),
                        onTap: () => _editLeadDays(context),
                      ),
                      _Row(
                        title: 'Km sorma aralığı',
                        value: '${s.kmPromptDays} gün',
                        onTap: () => _editKmPrompt(context),
                        last: true,
                      ),
                    ]),
                    const SizedBox(height: 18),
                    _GroupTitle('HAKKINDA'),
                    _Group(children: [
                      _Row(
                        title: 'KVKK aydınlatma metni',
                        onTap: () => _openText(context, 'KVKK aydınlatma metni', _kvkkSummary),
                      ),
                      _Row(
                        title: 'Gizlilik politikası',
                        onTap: () => _openText(context, 'Gizlilik politikası', _privacySummary),
                      ),
                      _Row(
                        title: 'Bize ulaş',
                        onTap: () => _openText(context, 'Bize ulaş',
                            'Görüş ve önerilerin için: [DESTEK E-POSTA ADRESİ]'),
                        last: true,
                      ),
                    ]),
                    const SizedBox(height: 18),
                    ListenableBuilder(
                      listenable: CloudService.instance.user,
                      builder: (context, _) => !CloudService.instance.isLinked
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: OutlinedButton.icon(
                                onPressed: () => _signOut(context),
                                icon: const Icon(Icons.logout),
                                label: const Text('Çıkış yap'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  foregroundColor: AppColors.ink,
                                  side: const BorderSide(color: AppColors.border, width: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  textStyle: body(14, weight: FontWeight.w700),
                                ),
                              ),
                            ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _deleteAll(context),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Hesabımı ve verilerimi sil'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: AppColors.lateText,
                        side: const BorderSide(color: Color(0xFFF3C2C2), width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: body(14, weight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(child: Text('Sürüm 1.0.0', style: body(11, color: AppColors.inkSoft))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editLeadDays(BuildContext context) async {
    final store = StoreScope.read(context);
    final selected = store.settings.leadDays.toSet();
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kaç gün önce hatırlatalım?', style: display(18, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Son gün de ayrıca hatırlatılır.', style: body(13, color: AppColors.inkSoft)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in const [60, 30, 14, 7, 3, 1])
                    PillChoice(
                      label: '$d gün',
                      selected: selected.contains(d),
                      onTap: () => setS(() => selected.contains(d) ? selected.remove(d) : selected.add(d)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              BigButton(
                label: 'Kaydet',
                dark: true,
                onPressed: () {
                  store.updateSettings((x) => x.leadDays = selected.toList());
                  Navigator.pop(c);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editKmPrompt(BuildContext context) async {
    final store = StoreScope.read(context);
    final v = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in const [7, 14, 21, 30])
              ListTile(
                title: Text('$d günde bir'),
                trailing: store.settings.kmPromptDays == d ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(c, d),
              ),
          ],
        ),
      ),
    );
    if (v != null) store.updateSettings((x) => x.kmPromptDays = v);
  }

  void _openText(BuildContext context, String title, String text) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        body: SafeArea(
          child: ListView(
            children: [
              ScreenHeader(title: title),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text(text, style: body(14, height: 1.5)),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Future<void> _deleteAll(BuildContext context) async {
    final store = StoreScope.read(context);
    final ctrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: TintIcon(Icons.warning_amber_rounded, AppColors.lateText, AppColors.lateBg, size: 52),
              ),
              const SizedBox(height: 12),
              Text('Hesabın ve tüm verilerin kalıcı olarak silinsin mi?',
                  style: display(19, weight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                '${store.vehicles.length} araç, ${store.allRecords.length} kayıt, bakım planları ve kaza bilgileri silinir. Bu işlem geri alınamaz.',
                style: body(14, color: AppColors.catOther),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Onaylamak için SİL yaz'),
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setS(() {}),
                style: body(16, weight: FontWeight.w700),
                decoration: const InputDecoration(hintText: 'SİL'),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _isConfirm(ctrl.text) ? () => Navigator.pop(c, true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lateText,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: body(15, weight: FontWeight.w700),
                ),
                child: const Text('Kalıcı olarak sil'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();
    if (ok != true || !context.mounted) return;
    await NotificationService.instance.cancelAll();
    if (!context.mounted) return;
    try {
      if (kCloudEnabled) {
        await runWithProgress(context, 'Hesabın ve verilerin siliniyor…', CloudService.instance.deleteAccount);
      } else {
        await store.deleteAllData();
      }
    } catch (e) {
      debugPrint('Hesap silinemedi: $e');
      if (context.mounted) {
        toast(context, 'Silme tamamlanamadı (${cloudErrorCode(e)}). İnternet bağlantını kontrol edip tekrar dene.');
      }
      return;
    }
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Çıkış yapılsın mı?',
      message: 'Verilerin hesabında kalır; aynı Google hesabıyla tekrar giriş yaptığında geri gelir. Bu telefondaki kopya silinir.',
      ok: 'Çıkış yap',
      danger: false,
    );
    if (!ok || !context.mounted) return;
    await NotificationService.instance.cancelAll();
    if (!context.mounted) return;
    try {
      await runWithProgress(context, 'Çıkış yapılıyor…', CloudService.instance.signOut);
    } catch (e) {
      debugPrint('Çıkış yapılamadı: $e');
      if (context.mounted) toast(context, 'Çıkış yapılamadı (${cloudErrorCode(e)}).');
    }
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  static bool _isConfirm(String t) {
    final s = t.trim().toUpperCase().replaceAll('İ', 'I');
    return s == 'SIL';
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text,
          style: body(12, weight: FontWeight.w700, color: AppColors.inkSoft).copyWith(letterSpacing: 0.6)),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.value, this.trailing, this.onTap, this.last = false});
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(title, style: body(14, weight: FontWeight.w600))),
            if (value != null)
              Text(value!, style: body(14, weight: FontWeight.w700, color: AppColors.link)),
            if (trailing != null) trailing!,
            if (trailing == null && value == null && onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}

const _kvkkSummary = '''Tekerim, sana hizmet verebilmek için yalnızca senin girdiğin araç bilgilerini (plaka, marka, model, kilometre, önemli tarihler), gider kayıtlarını, bakım planını ve kaza açıklamalarını saklar.

Fotoğraf, belge, konum veya rehber gibi bilgiler istenmez ve toplanmaz.

Verilerin bu telefonda ve yedek olarak bulut veritabanında (Google Firebase, Avrupa sunucuları) senin hesabına bağlı şekilde saklanır; başka kullanıcılarla paylaşılmaz. Giriş yapmadan da kullanabilmen için arka planda isimsiz bir hesap açılır. Google hesabını bağlarsan yalnızca e-posta adresin ve hesap kimliğin bu hesaba eklenir; şifre tutulmaz.

Reklamlar Google AdMob tarafından gösterilir; reklam tercihlerini ilk açılışta çıkan onay ekranından yönetebilirsin.

Verilerini istediğin an Ayarlar > "Hesabımı ve verilerimi sil" ile kalıcı olarak silebilirsin.

[Tam KVKK aydınlatma metni, veri sorumlusu bilgileriyle birlikte yayından önce buraya eklenecek.]''';

const _privacySummary = '''Gizlilik politikası özeti

• Toplanan veriler: araç bilgileri, gider kayıtları, bakım planı, kaza açıklamaları, bildirim ayarları; hesap bağlarsan Google e-posta adresin.
• Saklama: telefonda ve Google Firebase'de (Avrupa), yalnızca sana ait hesapta.
• Toplanmayan veriler: fotoğraf, belge, konum, rehber, şifre.
• Reklam: Google AdMob, reklam kimliği ve onay tercihleri.
• Silme: Ayarlar ekranından tüm veriler kalıcı olarak silinebilir.

[Tam gizlilik politikası yayından önce web sitesinde yayımlanacak ve buraya bağlantısı eklenecek.]''';

/// Ayarların en üstündeki hesap kartı: misafir mi, Google ile bağlı mı.
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final cloud = CloudService.instance;
    return ListenableBuilder(
      listenable: cloud.user,
      builder: (context, _) {
        final linked = kCloudEnabled && cloud.isLinked;
        final title = linked ? (cloud.email ?? 'Google hesabı') : 'Misafir kullanıcı';
        final sub = !kCloudEnabled
            ? 'Veriler bu telefonda · yedekleme yakında'
            : linked
                ? 'Google ile bağlı · verilerin yedekleniyor'
                : 'Telefon değişince veriler gelsin · hesabını bağla';
        return AppCard(
          color: AppColors.navy,
          radius: 22,
          padding: const EdgeInsets.all(16),
          onTap: kCloudEnabled && !linked ? () => showLinkAccountSheet(context) : null,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(16)),
                child: Icon(linked ? Icons.verified_user_outlined : Icons.person_outline, color: AppColors.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body(15, weight: FontWeight.w700, color: Colors.white)),
                    Row(
                      children: [
                        Icon(linked ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                            size: 14, color: AppColors.navySoft),
                        const SizedBox(width: 6),
                        Expanded(child: Text(sub, style: body(12, color: AppColors.navySoft))),
                      ],
                    ),
                  ],
                ),
              ),
              if (kCloudEnabled && !linked) const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        );
      },
    );
  }
}
