import 'dart:ui';

import 'storage.dart';

/// Premium looks for the virtual Mandir. [classic] is free; the rest come with Premium. Each sets
/// the garland flowers, the backdrop and the diya.
enum MandirDecor {
  classic(
    'Classic',
    'पारंपरिक',
    'సంప్రదాయ',
    false,
    [Color(0xFFFF9800), Color(0xFFFFC107), Color(0xFFE65100)],
    Color(0xFF2E7D32),
    [Color(0xFF2A0F06), Color(0xFF120603)],
    [Color(0xFFBF5B04), Color(0xFF8D3B00)],
  ),
  swarna(
    'Swarna (gold)',
    'स्वर्ण',
    'స్వర్ణ',
    true,
    [Color(0xFFFFD54F), Color(0xFFFFB300), Color(0xFFFFF176)],
    Color(0xFFB8860B),
    [Color(0xFF3A2400), Color(0xFF140B00)],
    [Color(0xFFFFD54F), Color(0xFFB8860B)],
  ),
  mallige(
    'Jasmine and rose',
    'चमेली और गुलाब',
    'మల్లెలు, గులాబీలు',
    true,
    [Color(0xFFFFFFFF), Color(0xFFF8BBD0), Color(0xFFFFFDE7)],
    Color(0xFF388E3C),
    [Color(0xFF1A1033), Color(0xFF0A0614)],
    [Color(0xFFE0E0E0), Color(0xFF9E9E9E)],
  ),
  tulasi(
    'Tulasi',
    'तुलसी',
    'తులసి',
    true,
    [Color(0xFF66BB6A), Color(0xFFAED581), Color(0xFF7E57C2)],
    Color(0xFF1B5E20),
    [Color(0xFF0D2410), Color(0xFF050F06)],
    [Color(0xFF8D6E63), Color(0xFF4E342E)],
  ),
  deepotsava(
    'Deepotsava',
    'दीपोत्सव',
    'దీపోత్సవం',
    true,
    [Color(0xFFFF6F00), Color(0xFFFFCA28), Color(0xFFD84315)],
    Color(0xFF2E7D32),
    [Color(0xFF331000), Color(0xFF0F0500)],
    [Color(0xFFD84315), Color(0xFF7F2704)],
  );

  const MandirDecor(this.en, this.hi, this.te, this.premium, this.flowers, this.leaf, this.backdrop, this.bowl);
  final String en, hi, te;
  final bool premium;

  /// Garland flower colours, the leaf between swags, the backdrop's outer colours and the diya bowl.
  final List<Color> flowers, backdrop, bowl;
  final Color leaf;

  /// A row of small lamps along the floor.
  bool get lamps => this == deepotsava;

  static MandirDecor byName(Object? name) => values.where((d) => d.name == name).firstOrNull ?? classic;
}

/// Japa mala beads. Rudraksha is free; the rest come with Premium.
enum MalaStyle {
  rudraksha('Rudraksha', 'रुद्राक्ष', 'రుద్రాక్ష', false, Color(0xFF6D4C41), Color(0xFFFF8F00)),
  tulsi('Tulsi', 'तुलसी', 'తులసి', true, Color(0xFFBCAAA4), Color(0xFF9CCC65)),
  sphatik('Sphatik (crystal)', 'स्फटिक', 'స్ఫటికం', true, Color(0x66E1F5FE), Color(0xFFE1F5FE)),
  chandan('Sandalwood', 'चंदन', 'చందనం', true, Color(0xFF8D6E63), Color(0xFFFFCC80));

  const MalaStyle(this.en, this.hi, this.te, this.premium, this.bead, this.done);
  final String en, hi, te;
  final bool premium;
  final Color bead, done;

  static MalaStyle byName(Object? name) => values.where((m) => m.name == name).firstOrNull ?? rudraksha;
}

/// Beads per japa round: the full 108 is free; the quarter and half malas come with Premium.
const malaSizes = [108, 54, 27];
bool malaSizePremium(int size) => size != 108;

/// What a Premium choice resolves to: itself with Premium, otherwise the free default, so a lapsed
/// subscription quietly goes back to the free look and nothing breaks.
T unlocked<T>(T chosen, {required bool isPremiumItem, required bool premium, required T free}) =>
    !isPremiumItem || premium ? chosen : free;

class Perks {
  Perks._();
  static MandirDecor get decor => MandirDecor.byName(Boxes.prefs.get('mandir_decor'));
  static Future<void> setDecor(MandirDecor d) => Boxes.prefs.put('mandir_decor', d.name);

  static MalaStyle get mala => MalaStyle.byName(Boxes.prefs.get('japa_mala'));
  static Future<void> setMala(MalaStyle m) => Boxes.prefs.put('japa_mala', m.name);

  static int get malaSize {
    final v = Boxes.prefs.get('japa_size');
    return v is int && malaSizes.contains(v) ? v : 108;
  }

  static Future<void> setMalaSize(int size) => Boxes.prefs.put('japa_size', size);
}
