import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/billing.dart';
import '../core/favorites.dart';
import '../core/i18n.dart';
import '../core/native.dart';
import '../core/sections.dart';
import '../core/sharing.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import '../widgets/common.dart';
import '../widgets/premium_lock.dart';
import 'section_common.dart';

/// Ringtones: short cuts of licensed devotional recordings and Devalay's own sounds, trimmed to a breath,
/// loudness-normalised (−13 LUFS) and faded, each with a 3.5-second notification cut.
class RingtonesScreen extends ConsumerStatefulWidget {
  const RingtonesScreen({super.key});
  @override
  ConsumerState<RingtonesScreen> createState() => _RingtonesScreenState();
}

class _RingtonesScreenState extends ConsumerState<RingtonesScreen> {
  // A player of its own that mixes with others, so a preview never takes over the bhakti queue.
  final _player = ap.AudioPlayer(playerId: 'ringtone-preview');
  final _subs = <StreamSubscription<Object?>>[];
  String? _playing;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  String _filter = SectionFilter.all;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _player.setAudioContext(ap.AudioContextConfig(focus: ap.AudioContextConfigFocus.mixWithOthers).build());
    _subs
      ..add(_player.onPositionChanged.listen((p) => mounted ? setState(() => _position = p) : null))
      ..add(_player.onDurationChanged.listen((d) => mounted ? setState(() => _total = d) : null))
      ..add(_player.onPlayerComplete.listen((_) => mounted ? setState(() => _playing = null) : null));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(Ringtone r) async {
    if (_playing == r.id) {
      await _player.stop();
      setState(() => _playing = null);
      return;
    }
    setState(() {
      _playing = r.id;
      _position = Duration.zero;
      _total = Duration(milliseconds: (r.seconds * 1000).round());
    });
    Usage.record('ringtone_preview', item: r.id);
    // Downloaded tones play from storage, so previews work offline too.
    final local = SectionFiles.isDownloaded(r.audio) ? await SectionFiles.get(r.audio) : null;
    await _player.stop();
    await _player.play(local != null ? ap.DeviceFileSource(local.path) : ap.UrlSource(r.audio));
  }

  Future<File> _download(Ringtone r, String url) async {
    setState(() => _busy = r.id);
    try {
      final f = await SectionFiles.get(url);
      ref.read(sectionDownloadsTick.notifier).bump();
      return f;
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _set(Ringtone r) async {
    final lang = uiLang(ref);
    if (isLocked(r, premium: ref.read(premiumProvider))) {
      openPremiumFor(context, r);
      return;
    }
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label, icon) in [
              ('ringtone', t3(lang, 'Phone ringtone', 'फ़ोन रिंगटोन', 'ఫోన్ రింగ్‌టోన్'), Icons.phone_in_talk_rounded),
              (
                'notification',
                t3(lang, 'Notification sound (short)', 'सूचना ध्वनि (छोटी)', 'నోటిఫికేషన్ శబ్దం (చిన్నది)'),
                Icons.notifications_rounded,
              ),
              ('alarm', t3(lang, 'Alarm', 'अलार्म', 'అలారం'), Icons.alarm_rounded),
            ])
              ListTile(leading: Icon(icon), title: Text(label), onTap: () => Navigator.pop(ctx, value)),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    if (!await NativeBridge.canWriteSettings()) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t3(lang, 'One-time permission', 'एक बार की अनुमति', 'ఒక్కసారి అనుమతి')),
          content: Text(
            t3(
              lang,
              'Android needs the "Modify system settings" permission for Devalay to change your ringtone. Turn it on, then come back and tap Set again.',
              'रिंगटोन बदलने के लिए Android को "सिस्टम सेटिंग बदलें" अनुमति चाहिए। इसे चालू करें, फिर लौटकर दोबारा लगाएँ दबाएँ।',
              'రింగ్‌టోన్ మార్చడానికి Androidకి "సిస్టమ్ సెట్టింగ్‌లను మార్చు" అనుమతి కావాలి. దాన్ని ఆన్ చేసి, తిరిగి వచ్చి మళ్ళీ పెట్టండి నొక్కండి.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t3(lang, 'Cancel', 'रद्द करें', 'రద్దు')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t3(lang, 'Open settings', 'सेटिंग्स खोलें', 'సెట్టింగ్స్ తెరవండి')),
            ),
          ],
        ),
      );
      if (ok == true) await NativeBridge.openWriteSettings();
      return;
    }
    try {
      final f = await _download(r, type == 'notification' ? r.notification : r.audio);
      await NativeBridge.setRingtone(f.path, 'Devalay - ${r.title.en}', type);
      Usage.record('ringtone_set', item: '${r.id}:$type');
      HapticFeedback.mediumImpact();
      if (mounted) toast(context, t3(lang, 'Set 🙏', 'लग गया 🙏', 'పెట్టాం 🙏'));
    } catch (e) {
      if (mounted) {
        toast(context, t3(lang, 'Could not set: $e', 'सेट नहीं हो सका: $e', 'పెట్టలేకపోయాం: $e'));
      }
    }
  }

  Future<void> _share(Ringtone r) async {
    final lang = uiLang(ref);
    if (isLocked(r, premium: ref.read(premiumProvider))) {
      openPremiumFor(context, r);
      return;
    }
    try {
      final f = await _download(r, r.audio);
      await shareFileToWhatsApp(
        f,
        mime: 'audio/mp4',
        text: '🔔 ${r.title.of(lang)}\n\n${shareFooter('ringtone')}',
        what: itemRef(r),
      );
    } catch (e) {
      if (mounted) toast(context, t3(lang, 'Could not share: $e', 'शेयर नहीं हो सका: $e', 'షేర్ కాలేదు: $e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final premium = ref.watch(premiumProvider);
    ref.watch(sectionDownloadsTick);
    final favs = ref.watch(favoritesProvider);
    final tags = ref.watch(sectionTodayTagsProvider);
    final catalog = ref.watch(sectionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'ringtones')),
        bottom: catalog.value == null
            ? null
            : SectionChips(
                deities: deitiesOf(catalog.value!.ringtones),
                selected: _filter,
                onSelected: (f) => setState(() => _filter = f),
              ),
      ),
      body: catalog.when(
        loading: () => const LoadingList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(sectionsProvider)),
        data: (c) {
          final all = c.ringtones;
          final todayDeity = tags.contains('saturday')
              ? 'venkateswara'
              : const {
                  'monday': 'shiva',
                  'tuesday': 'hanuman',
                  'wednesday': 'ganesha',
                  'thursday': 'vishnu',
                  'friday': 'lakshmi',
                  'sunday': 'surya',
                }.entries.where((e) => tags.contains(e.key)).firstOrNull?.value;
          final shown = _filter == SectionFilter.today
              ? all.where((r) => r.deity == todayDeity || forToday([r], tags).isNotEmpty).toList()
              : SectionFilter.apply(
                  all,
                  _filter,
                  todayTags: tags,
                  isFavourite: (r) => favs.containsKey('${favouriteType(r)}:${r.id}'),
                  isDownloaded: (r) => SectionFiles.isDownloaded(r.audio) || SectionFiles.isDownloaded(r.notification),
                );
          final top = _filter == SectionFilter.all;
          final featured = top ? all.where((r) => r.isPremium).toList() : const <Ringtone>[];
          final rest = top ? shown.where((r) => !r.isPremium).toList() : shown;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24).withSystemInsets(context),
            children: [
              if (top)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: GradientCard(
                    colors: Palette.dusk,
                    child: Row(
                      children: [
                        const Text('🔔', style: TextStyle(fontSize: 34)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t3(
                              lang,
                              'Studio-clean devotional tones, trimmed on a breath and evened out in loudness. Each has a short notification cut.',
                              'साफ़ भक्ति धुनें, साँस पर कटी और एक जैसी आवाज़ में। हर एक की छोटी सूचना धुन भी है।',
                              'శుభ్రమైన భక్తి రింగ్‌టోన్లు, శ్వాస దగ్గర కత్తిరించి, ఒకే స్థాయి శబ్దంతో. ప్రతి దానికీ చిన్న నోటిఫికేషన్ టోన్ కూడా ఉంది.',
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (featured.isNotEmpty) ...[
                PremiumCollectionHeader(premium: premium),
                for (final r in featured) _tile(r, premium, lang, gold: true),
                SectionHeader(t3(lang, 'Free ringtones', 'मुफ़्त रिंगटोन', 'ఉచిత రింగ్‌టోన్లు')),
              ],
              if (rest.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: EmptyState(
                    icon: Icons.music_off_rounded,
                    title: t3(lang, 'Nothing here yet', 'अभी कुछ नहीं', 'ఇక్కడ ఇంకా ఏమీ లేవు'),
                  ),
                ),
              for (final r in rest) _tile(r, premium, lang),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(Ringtone r, bool premium, String lang, {bool gold = false}) {
    final locked = isLocked(r, premium: premium);
    final playing = _playing == r.id;
    final progress = playing && _total.inMilliseconds > 0
        ? (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final downloaded = SectionFiles.isDownloaded(r.audio);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Card(
        shape: gold
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFFC857), width: 1.4),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(value: playing ? progress : 0, strokeWidth: 3),
                        IconButton(
                          tooltip: playing ? t3(lang, 'Stop', 'रोकें', 'ఆపు') : t3(lang, 'Play', 'चलाएँ', 'వినండి'),
                          onPressed: () => _toggle(r),
                          icon: Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                r.title.of(lang),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ),
                            if (r.isPremium) ...[const SizedBox(width: 6), LockBadge(locked: locked, compact: true)],
                            if (downloaded) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.download_done_rounded, size: 16),
                            ],
                          ],
                        ),
                        Text(
                          '${r.seconds.round()}s · ${deityName(r.deity, lang)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (_busy == r.id)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else
                    FilledButton(
                      onPressed: () => _set(r),
                      style: locked ? FilledButton.styleFrom(backgroundColor: const Color(0xFFFFB300)) : null,
                      child: locked
                          ? const Icon(Icons.lock_rounded, size: 18, color: Color(0xFF3E1500))
                          : Text(t3(lang, 'Set', 'लगाएँ', 'పెట్టండి')),
                    ),
                ],
              ),
              Row(
                children: [
                  const SizedBox(width: 56),
                  Expanded(child: CreditLine(r.credit)),
                  FavoriteButton(item: favouriteFor(r, lang)),
                  IconButton(
                    tooltip: 'WhatsApp',
                    onPressed: _busy == null ? () => _share(r) : null,
                    icon: const Icon(Icons.share_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
