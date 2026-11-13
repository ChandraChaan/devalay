import 'package:flutter/material.dart';

import '../core/i18n.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  static const _sections = [
    (
      'Scriptures',
      [
        'Bhagavad Gita Sanskrit text (public domain) via the open gita/gita dataset (Unlicense).',
        'English Gita translation by Annie Besant (4th edition, 1922), public domain worldwide, via Wikisource.',
        'The Song Celestial, tr. Sir Edwin Arnold (1885); The Ramayan of Valmiki, tr. R. T. H. Griffith (1870-74); '
            'Maha-bharata, condensed by R. C. Dutt (1898); The Upanishads, tr. Swami Paramananda (1919). '
            'All public domain, from Project Gutenberg.',
        'Telugu and Carnatic recordings by M.S. Subbulakshmi, Dr. M. Balamuralikrishna and P.B. Sreenivas, '
            'published by Saregama under CC BY 3.0 (via Wikimedia Commons); audio extracted, otherwise unchanged.',
        'Hanuman Chalisa and Shri Ramchandra Kripalu by Goswami Tulsidas, traditional aartis, Vedic and Puranic mantras: '
            'public domain. Meanings are original summaries written for Devalay.',
      ],
    ),
    (
      'Art',
      [
        'Deity paintings and prints by Raja Ravi Varma (1848-1906) and the Ravi Varma Press, and other public-domain works, '
            'from Wikimedia Commons. Each wallpaper shows its own credit and links to its source.',
      ],
    ),
    (
      'Audio',
      [
        'Recordings from Wikimedia Commons under CC0, CC BY-SA 3.0/4.0 or the Free Art License, credited on each track.',
        'Temple bells, shankh, Om drone, tanpura, bansuri and ringtones are original sounds synthesised for Devalay, '
            'released under CC0.',
      ],
    ),
    (
      'Films',
      [
        'Raja Harishchandra (1913), Lanka Dahan (1917), Shree Krishna Janma (1918) and Kaliya Mardan (1919) by Dadasaheb '
            'Phalke: public domain, from Wikimedia Commons.',
      ],
    ),
    (
      'Astronomy',
      ['Panchang and festival dates computed with Skyfield (MIT) and NASA JPL DE421 ephemeris (public domain).'],
    ),
    ('Fonts', ['Mukta (Ek Type) and Tiro Devanagari Sanskrit (Tiro Typeworks), SIL Open Font License 1.1.']),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t3(appLang, 'Credits & licences', 'श्रेय और लाइसेंस', 'క్రెడిట్స్ & లైసెన్సులు'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final (title, lines) in _sections) ...[
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('• $l')),
            const SizedBox(height: 12),
          ],
          OutlinedButton(
            onPressed: () => launchUrl(
              Uri.parse('${AppConfig.sourceUrl}/blob/main/CONTENT_LICENSES.md'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              t3(appLang, 'Full content licence list', 'सभी सामग्री लाइसेंस', 'పూర్తి కంటెంట్ లైసెన్సుల జాబితా'),
            ),
          ),
          TextButton(
            onPressed: () => showLicensePage(context: context, applicationName: 'Devalay'),
            child: Text(
              t3(
                appLang,
                'Open-source software licences',
                'ओपन-सोर्स सॉफ़्टवेयर लाइसेंस',
                'ఓపెన్-సోర్స్ సాఫ్ట్‌వేర్ లైసెన్సులు',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
