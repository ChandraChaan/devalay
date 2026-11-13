#!/bin/sh
# Shrinks the bundled fonts in place. Safe to run again: a font that is already slim stays the same.
#
#  - Drops TrueType hinting. Flutter on Android renders with light (auto) hinting and never runs it.
#  - Drops glyph names and the DSIG table, which only font tools read.
#  - Keeps every OpenType layout feature, so conjuncts, matras and reph still shape.
#  - NotoSansTelugu and TiroTelugu are fallbacks behind Mukta and Tiro Devanagari (see lib/core/theme.dart),
#    so they only keep the Telugu block, the dandas, the Vedic tone marks, ZWJ/ZWNJ and the dotted circle.
#
# Needs fontTools: pip install fonttools
# Run from app/: sh tool/slim_fonts.sh
set -e
cd "$(dirname "$0")/../assets/fonts"

COMMON="--layout-features=* --no-hinting --drop-tables+=DSIG --no-glyph-names --notdef-outline
  --name-IDs=* --name-legacy --name-languages=*"
TELUGU="U+0020,U+00A0,U+0951-0952,U+0964-0965,U+0C00-0C7F,U+200B-200D,U+25CC"

slim() {
  font=$1
  unicodes=$2
  # shellcheck disable=SC2086
  pyftsubset "$font" --unicodes="$unicodes" $COMMON --output-file="$font.slim"
  mv "$font.slim" "$font"
}

for font in Mukta-*.ttf TiroDevanagariSanskrit-*.ttf; do slim "$font" '*'; done
for font in NotoSansTelugu-*.ttf TiroTelugu-*.ttf; do slim "$font" "$TELUGU"; done
ls -l ./*.ttf
