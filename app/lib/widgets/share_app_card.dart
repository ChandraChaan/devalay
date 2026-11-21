import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/sharing.dart';
import 'common.dart';

/// Home-screen card asking to send Devalay to the family WhatsApp group. Shows from the second day
/// of use until the user shares or closes it ([showShareAppCard]).
class ShareAppCard extends ConsumerStatefulWidget {
  const ShareAppCard({super.key});

  @override
  ConsumerState<ShareAppCard> createState() => _ShareAppCardState();
}

class _ShareAppCardState extends ConsumerState<ShareAppCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final lang = uiLang(ref);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GradientCard(
        colors: const [Color(0xFF075E54), Color(0xFF128C7E), Color(0xFF25D366)],
        padding: 16,
        onTap: () async {
          await shareApp(lang);
          if (mounted) setState(() => _hidden = true);
        },
        child: Row(
          children: [
            const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t3(lang, 'Share with family', 'परिवार से साझा करें', 'కుటుంబంతో పంచుకోండి'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    t3(
                      lang,
                      "Send Devalay to your family WhatsApp group, so everyone has the day's Panchang and festival dates.",
                      'देवालय को परिवार के WhatsApp ग्रुप में भेजें, ताकि सबके पास आज का पंचांग और त्योहार की तिथियाँ रहें।',
                      'దేవాలయం యాప్‌ను కుటుంబ WhatsApp గ్రూప్‌కు పంపండి, అందరికీ నేటి పంచాంగం, పండుగ తేదీలు తెలుస్తాయి.',
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, height: 1.3),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () {
                closeShareAppCard();
                setState(() => _hidden = true);
              },
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
