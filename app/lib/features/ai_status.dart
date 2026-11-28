import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/about_you.dart';
import '../core/billing.dart';
import '../core/i18n.dart';
import '../core/native.dart';
import '../core/providers.dart';
import '../core/sections.dart';
import '../core/sharing.dart';
import '../core/status_library.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import '../widgets/common.dart';
import '../widgets/premium_lock.dart';
import '../widgets/status_templates.dart';
import 'section_common.dart';
import 'status_maker.dart' show renderStatusImage, saveToGallery;
import 'whatsapp_status.dart' show artFor, statusLang, todayFestival;

/// AI Status: a personal devotional status for today, composed on the phone. It greets today's festival
/// or weekday, picks a fitting verse with its meaning, adds today's Panchang and the user's name, and
/// draws it on one of twelve designs (the five Premium ones carry a watermark until unlocked). One tap
/// sends the 1080×1920 picture to WhatsApp. No hosted model: free, instant and offline.
class StatusMakerScreen extends ConsumerStatefulWidget {
  const StatusMakerScreen({super.key, this.template, this.variant = 0});
  final String? template;
  final int variant;
  @override
  ConsumerState<StatusMakerScreen> createState() => _StatusMakerScreenState();
}

class _StatusMakerScreenState extends ConsumerState<StatusMakerScreen> {
  static const _nameKey = 'status_name';
  static const _deities = [
    'shiva',
    'venkateswara',
    'lakshmi',
    'vishnu',
    'ganesha',
    'hanuman',
    'rama',
    'krishna',
    'durga',
    'saraswati',
    'surya',
    'dattatreya',
    'shani',
    'kartikeya',
  ];

  late final _templates = StatusTemplate.values;
  late int _page = (() {
    final i = _templates.indexWhere((t) => t.name == widget.template);
    return i < 0 ? 0 : i;
  })();
  late final _pages = PageController(viewportFraction: 0.78, initialPage: _page);
  late final _keys = [for (final _ in _templates) GlobalKey()];
  late String _lang = statusLang(ref.read(prefsProvider).language);
  late int _variant = widget.variant;
  String? _deity;
  StatusOccasion _occasion = StatusOccasion.today;
  bool _personal = false;
  late final _to = TextEditingController();
  late final _name = TextEditingController(
    text: (Boxes.prefs.get(_nameKey) as String?) ?? ref.read(aboutYouProvider).name,
  );
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    _to.dispose();
    super.dispose();
  }

  StatusTemplate get _template => _templates[_page];

  Future<File?> _render() async {
    final boundary = _keys[_page];
    if (boundary.currentContext == null) return null;
    Usage.record('ai_status_make', item: _template.name);
    return renderStatusImage(boundary, prefix: 'devalay-status-${_template.name}');
  }

  Future<void> _act(Future<void> Function(File f) action, {String done = ''}) async {
    setState(() => _busy = true);
    try {
      final f = await _render();
      if (f == null) return;
      await action(f);
      if (mounted && done.isNotEmpty) {
        HapticFeedback.mediumImpact();
        toast(context, done);
      }
    } catch (e) {
      if (mounted) toast(context, t3(appLang, 'Could not complete: $e', 'पूरा नहीं हो सका: $e', 'పూర్తి కాలేదు: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setWallpaper() {
    final lang = uiLang(ref);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (target, label, icon) in [
              (1, t3(lang, 'Home screen', 'होम स्क्रीन', 'హోమ్ స్క్రీన్'), Icons.home_rounded),
              (2, t3(lang, 'Lock screen', 'लॉक स्क्रीन', 'లాక్ స్క్రీన్'), Icons.lock_rounded),
              (3, t3(lang, 'Both', 'दोनों', 'రెండూ'), Icons.phone_android_rounded),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  Navigator.pop(ctx);
                  _act(
                    (f) => NativeBridge.setWallpaper(f.path, target),
                    done: t3(lang, 'Wallpaper set 🙏', 'वॉलपेपर लग गया 🙏', 'వాల్‌పేపర్ పెట్టాం 🙏'),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = uiLang(ref);
    final premium = ref.watch(premiumProvider);
    final home = ref.watch(homeProvider).value;
    final walls = ref.watch(sectionsProvider).value?.wallpapers ?? const <HdWallpaper>[];
    final panchang = home?['panchang'] as Map?;
    final personal = _personal && premium
        ? personalBlessing(
            birthStar: ref.watch(prefsProvider).birthStar,
            todayStar: (panchang?['nakshatra'] as Map?)?['index'] as int?,
            lang: _lang,
            name: _occasion == StatusOccasion.today ? '' : _to.text,
          )
        : null;
    final content = composeStatus(
      lang: _lang,
      day: DateTime.now(),
      deity: _deity,
      festival: _deity == null && _occasion == StatusOccasion.today ? todayFestival(home) : null,
      panchang: panchang,
      name: _name.text,
      variant: _variant,
      occasion: _occasion,
      to: _to.text,
      personal: personal,
    );
    final locked = _template.isPremium && !premium;
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'ai_status'))),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _templates.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final t = _templates[i];
                final tLocked = t.isPremium && !premium;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 6))],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: PremiumWatermark(
                                enabled: tLocked,
                                child: RepaintBoundary(
                                  key: _keys[i],
                                  child: StatusCard(
                                    content: content,
                                    template: t,
                                    artUrl: artFor(walls, content.deity, premium, photo: t.prefersPhoto),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (t.isPremium) Positioned(top: 8, right: 8, child: LockBadge(locked: tLocked)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Text(
            '${_template.label(ui)}  ·  ${_page + 1}/${_templates.length}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    maxLength: 30,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (v) {
                      Boxes.prefs.put(_nameKey, v.trim());
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      prefixIcon: const Icon(Icons.edit_rounded, size: 18),
                      hintText: t3(ui, 'Your name on the status', 'स्टेटस पर आपका नाम', 'స్టేటస్‌పై మీ పేరు'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: t3(ui, 'Another verse', 'दूसरा श्लोक', 'మరో శ్లోకం'),
                  onPressed: () => setState(() => _variant++),
                  icon: const Icon(Icons.shuffle_rounded),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final o in StatusOccasion.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(o.label(ui)),
                      selected: _occasion == o,
                      onSelected: (_) => setState(() {
                        _occasion = o;
                        _variant = 0;
                      }),
                    ),
                  ),
                const VerticalDivider(width: 16),
                FilterChip(
                  avatar: Icon(premium ? Icons.auto_awesome_rounded : Icons.lock_rounded, size: 16),
                  label: Text(t3(ui, 'Personal blessing', 'व्यक्तिगत आशीर्वाद', 'వ్యక్తిగత ఆశీర్వాదం')),
                  selected: _personal && premium,
                  onSelected: (v) {
                    if (!premium) {
                      openPremiumFor(context, StatusTemplateItem.personal());
                      return;
                    }
                    if (v && ref.read(prefsProvider).birthStar == null) {
                      toast(
                        context,
                        t3(
                          ui,
                          'Add your birth star in Settings > About you first.',
                          'पहले सेटिंग्स > आपके बारे में में अपना जन्म नक्षत्र जोड़ें।',
                          'ముందు సెట్టింగ్స్ > మీ గురించిలో మీ జన్మ నక్షత్రం చేర్చండి.',
                        ),
                      );
                    }
                    setState(() => _personal = v);
                  },
                ),
              ],
            ),
          ),
          if (_occasion == StatusOccasion.birthday || _occasion == StatusOccasion.anniversary)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: TextField(
                controller: _to,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  prefixIcon: const Icon(Icons.card_giftcard_rounded, size: 18),
                  hintText: t3(ui, 'For whom? (e.g. Amma)', 'किसके लिए? (जैसे माँ)', 'ఎవరి కోసం? (ఉదా. అమ్మ)'),
                ),
              ),
            ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final (value, label) in [('te', 'తెలుగు'), ('hi', 'हिन्दी'), ('en', 'English')])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _lang == value,
                      onSelected: (_) => setState(() => _lang = value),
                    ),
                  ),
                const VerticalDivider(width: 16),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: const Icon(Icons.wb_sunny_rounded, size: 16),
                    label: Text(t3(ui, "Today's deity", 'आज के देवता', 'ఈ రోజు దైవం')),
                    selected: _deity == null,
                    onSelected: (_) => setState(() => _deity = null),
                  ),
                ),
                for (final d in _deities)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(deityName(d, ui)),
                      selected: _deity == d,
                      onSelected: (_) => setState(() {
                        _deity = d;
                        _variant = 0;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          if (!premium)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                t3(
                  ui,
                  'Swipe for ${StatusTemplate.values.length} designs · the first 5 are Premium',
                  '${StatusTemplate.values.length} डिज़ाइन के लिए स्वाइप करें · पहले 5 प्रीमियम',
                  '${StatusTemplate.values.length} డిజైన్ల కోసం స్వైప్ చేయండి · మొదటి 5 ప్రీమియం',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Palette.marigold),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12).withSystemInsets(context),
            child: locked
                ? UnlockButton(item: StatusTemplateItem(_template))
                : Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _busy
                              ? null
                              : () => _act(
                                  (f) => shareFileToWhatsApp(
                                    f,
                                    mime: 'image/png',
                                    text: shareFooter('status'),
                                    what: 'status_template:${_template.name}',
                                  ),
                                ),
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            t3(ui, 'WhatsApp', 'व्हाट्सऐप', 'వాట్సాప్'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: t3(ui, 'Save', 'सेव', 'సేవ్'),
                        onPressed: _busy
                            ? null
                            : () => _act(
                                saveToGallery,
                                done: t3(
                                  ui,
                                  'Saved to Pictures/Devalay',
                                  'Pictures/Devalay में सहेजा',
                                  'Pictures/Devalayలో సేవ్ అయింది',
                                ),
                              ),
                        icon: const Icon(Icons.download_rounded),
                      ),
                      IconButton.filledTonal(
                        tooltip: t3(ui, 'Set as wallpaper', 'वॉलपेपर लगाएँ', 'వాల్‌పేపర్‌గా పెట్టండి'),
                        onPressed: _busy ? null : _setWallpaper,
                        icon: const Icon(Icons.wallpaper_rounded),
                      ),
                      IconButton.filledTonal(
                        tooltip: t3(ui, 'More apps', 'अन्य ऐप', 'ఇతర యాప్‌లు'),
                        onPressed: _busy
                            ? null
                            : () => _act(
                                (f) => shareContent(
                                  shareFooter('status'),
                                  files: [XFile(f.path, mimeType: 'image/png')],
                                  what: 'status_template:${_template.name}',
                                ),
                              ),
                        icon: const Icon(Icons.share_rounded),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
