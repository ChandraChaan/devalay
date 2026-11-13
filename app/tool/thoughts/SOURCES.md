# Thought of the day: sources

Notes written when each language's verses were collected for assets/data/thoughts.json. Every verse was extracted by script from the page in its `source` field and is re-checked by `python3 -I tool/thoughts/verify.py`. Meanings are original writing for Devalay.

## Sanskrit (sa): subhashitas, sources

All 60 verse texts were extracted by script from three pages on Sanskrit Wikisource (the checker fetches each with `?action=raw`):

1. **नीतिशतकम्** (Nitishatakam) of Bhartrihari: https://sa.wikisource.org/wiki/नीतिशतकम्. 18 verses. `ref` = the verse number on that page; this page's numbering differs slightly from some printed editions.
2. **हितोपदेशः०१** (Hitopadesha of Narayana Pandita, opening section: मङ्गलाचरणम्, विद्याप्रशंसा and कथामुखम्): https://sa.wikisource.org/wiki/हितोपदेशः०१. 12 verses. `ref` = the verse number on that page.
3. **चाणक्यनीतिदर्पणः** (Chanakya Niti Darpana): https://sa.wikisource.org/wiki/चाणक्यनीतिदर्पणः. 30 verses. `ref` = chapter.verse, using the chapter markers "(२)", "(३)" and so on and the verse numbers on that page.

No edition or editor is named on these pages; they are plain Wikisource transcriptions.

**Public domain:** Bhartrihari (c. 5th century CE), the Chanakya Niti compilation (attributed to Chanakya, c. 4th century BCE, compiled much later) and Narayana Pandita's Hitopadesha (c. 12th century CE) are all centuries old and PD. Wikisource texts are PD; the page formatting is CC BY-SA. English meanings are newly written. For this file "meaning" = "meaning_en".

**Editing done:** removed `<br>`/`<poem>` markup, the leading ":" indents and the ॥N॥ numbers; each verse ends with " ॥". In Nitishataka 79 I joined a word that the page split across two lines with a hyphen ("पुण्यपीयूषपूर्णा- स्त्रि..." became "...पूर्णास्त्रि..."). The Hitopadesha page writes sandhi split, e.g. "विनयाद् याति", and that spelling is kept as is.

**Not used:** the सुभाषितानि page (https://sa.wikisource.org/wiki/सुभाषितानि). It has many typing errors, for example ॆ/ॊ (short e/o vowel signs) where े/ो should be, plus stray ZWJs. Also left out: Nitishataka 78, where this page reads "प्रख्यापय स्वान्गुणान्" against the usual "प्रच्छादय"; Chanakya verses whose final halant is dropped on this page (e.g. "चिन्तयेत।"); and the many Chanakya verses that disparage women or castes.

## Hindi (hi): Kabir sakhis, sources

All 60 verse texts were extracted by script from the proofread Page-namespace transcriptions of one book on Hindi Wikisource:

- **Book:** कविता-कौमुदी, पहला भाग (Kavita Kaumudi, Part 1, Hindi), compiled by रामनरेश त्रिपाठी (Ramnaresh Tripathi), साहित्य भवन, प्रयाग (Allahabad), 1918. Section "३ कबीर साहब", subsection "साखी" (sakhis numbered 1 to 174).
- **Index:** https://hi.wikisource.org/wiki/विषयसूची:कविता-कौमुदी_1.pdf
- **Chapter page:** https://hi.wikisource.org/wiki/कविता-कौमुदी_१/३_कबीर_साहब (it only transcludes the pages, so each entry's `source` is the individual page)
- **Pages used** (the `source` URLs are these, percent-encoded): `https://hi.wikisource.org/wiki/पृष्ठ:कविता-कौमुदी_1.pdf/N`, with N = ८५, ८६, ८७, ८८, ८९, ९०, ९१, ९२, ९३, ९४, ९५, ९६, ९७, ९८ (page numbers in Devanagari digits, as titled on the wiki).
- `ref` = the sakhi number printed in this book.

**Public domain:** Kabir (c. 1398 to c. 1518) died more than 500 years ago. The 1918 compilation is also PD: Ramnaresh Tripathi died in 1962, so under India's author's life + 60 years rule it became PD in 2023, and the wiki marks it {{PD-1996}}. Wikisource transcriptions of PD texts are PD; the page formatting is CC BY-SA. Meanings are newly written.

**Editing done:** removed wiki markup, the leading ":" indents and the ॥N॥ verse numbers; joined the two lines with "\n". In #25 and #162 the source has "॥" at the end of line 1, which I changed to "।" (punctuation only; the checker ignores it). I also removed one zero-width non-joiner (#57). The spelling is otherwise exactly as in the source.

**Skipped on purpose:** sakhis with clear OCR or transcription errors on the page (e.g. #58 "समाहित", #100 "कुडल", #113 "चन्ड्न", #122 "कबार", #170 "पोथी पदि"), #7 (the reading "सतमान" is uncertain), and sakhis that mock religious practice or disparage women (#108, #155 to 157, #166, #168, #169).

**Not used:** हिन्दी विकिस्रोत "कबीर ग्रंथावली" (Shyamsundar Das text). This transcription is a later Lucknow edition with commentary by Savitri Shukla and others, which may not be PD. Its archaic forms are also less familiar to readers.

## Bengali (bn) sources: Rabindranath Tagore, Kanika (কণিকা, 1899)

All 61 entries are complete short poems (2 or 4 lines) from Tagore's collection কণিকা. The text was copied by script
from the proofread scan pages of the first edition on Bengali Wikisource:

- Index: https://bn.wikisource.org/wiki/নির্ঘণ্ট:কণিকা_(১৮৯৯)_রবীন্দ্রনাথ_ঠাকুর.djvu
- Work page: https://bn.wikisource.org/wiki/কণিকা_(রবীন্দ্রনাথ_ঠাকুর) (subpages transclude the scan pages)
- Each entry's `source` is the exact scan page, `https://bn.wikisource.org/wiki/পাতা:কণিকা_(১৮৯৯)_রবীন্দ্রনাথ_ঠাকুর.djvu/<page>`;
  one poem per page, proofread level 4 (validated). `ref` holds the poem's title as printed.

Edition: Kanika, first edition, 1899 (1306 Bengali era).
Only wiki markup was removed. Stray ASCII apostrophes that the transcription has next to curly quote marks
(‘' and '’, transcription artifacts, not in the printed text) were dropped; spelling is unchanged.

Public domain: Tagore died in 1941; his works entered the public domain in India in 2002 (and the 1899 edition is PD
everywhere). Wikisource transcriptions of PD texts are PD; Wikisource page formatting is CC BY-SA.

## Marathi (mr): Tukaram abhang excerpts, sources

All 59 verse texts were extracted by script (`work/build_mr.py`) from the raw wikitext (`?action=raw`) of the Tukaram Gatha on Marathi Wikisource:

- **Index:** https://mr.wikisource.org/wiki/तुकाराम_गाथा. The complete Gatha is split into 15 pages of about 300 abhangs each, numbered 1 to 4583. Every page carries the {{प्रताधिकार मुक्त साहित्य}} (copyright-free) template. The pages do not name the printed edition they were typed from.
- **Pages used** (the `source` URLs are these, percent-encoded): `https://mr.wikisource.org/wiki/तुकाराम_गाथा/गाथा_<from>_ते_<to>` for 1–300, 301–600, 601–900, 901–1200, 1201–1500, 1501–1800, 1801–2100, 2101–2400, 2401–2700, 3001–3300, 3301–3600, 3601–3900, 3901–4200 and 4201–4583.
- `ref` = the abhang number in this Gatha. The numbers used are 2, 3, 81, 88, 263, 264, 266, 291, 298, 326, 347, 364, 478, 504, 580, 712, 759, 857, 987, 996, 1021, 1208, 1230, 1277, 1427, 1451, 1505, 1519, 1548, 1553, 1716, 1775, 1884, 1989, 2296, 2317, 2387, 2429, 2446, 2471, 2517, 2561, 2606, 3019, 3117, 3241, 3385, 3731, 3823, 3874, 3900, 3976, 4092, 4276, 4288, 4293, 4295, 4414, 4430.

**Public domain:** Sant Tukaram (c. 1608 to 1649/1650) died more than 370 years ago. Wikisource transcriptions of PD texts are PD; the page formatting is CC BY-SA. All meanings are newly written.

**Excerpts:** each entry is one or two consecutive stanzas of an abhang, not the whole abhang. Usually this is the opening stanza plus the refrain (ध्रु.), which are the best-known lines. Each printed stanza "A । B ॥n॥" is shown as two lines, A and B, split at the "।". Abhang 291 is in a longer metre, so its stanza gives four lines. I removed the stanza numbers (॥१॥ / ॥1॥), the refrain mark ॥ध्रु.॥ and the dandas. Spelling is otherwise exactly as in the source, including older forms such as "ह्मणे", "आह्मां" and "तुह्मी" on the later pages, "चि" written separately, and "सासुर्‍यासि" with a ZWJ.

**Skipped on purpose:**
- Pages 601 to 4583 were typed from a legacy-font conversion and have OCR damage: "भH"/"भिH" for भक्त/भक्ति, "मुिH", "शुिद्ध", "काइऩ", "होइऩन", "Yाान", "किळकाळ" and similar. I checked every selected stanza with a script and by eye, and used only clean ones. Well-known abhangs whose key stanza is damaged were left out or cut to their clean stanza, e.g. 759 "नाहीं निर्मळ जीवन" (opening line only) and 2296 "हें चि दान देगा देवा" (opening line only). 2867 "ठेविलें अनंतें…" was dropped because the source has a broken "राह वें".
- **The page "गाथा २७०१ ते ३०००" cannot be used.** Its wikitext begins with a stray unclosed "<Noob" tag. The checker strips `<...>` spans, so it deletes almost the whole page and no verse from it can be verified. I replaced the three abhangs I had picked from that page (2765, 2783, 2864) with 1230, 1451 and 2561. Fixing that page on Wikisource, by removing "<Noob", would make abhangs 2701–3000 usable.
- Abhang numbers that occur twice in the source were avoided as `ref`. 3668 appears both on the 3301–3600 page and on the 3601–3900 page, and was dropped. For abhang 2 I used the text on the 1–300 page.
- Abhangs that disparage people or need long commentary, e.g. 1622, 2027 and the caste lists in 4276 (only its first two stanzas are used).

## Telugu (te) sources

All verse texts were extracted by script from the wikitext (`?action=raw`) of Telugu Wikisource pages.
Only wiki markup and verse numbers (for example a trailing `[85]`) were removed; the source spelling is kept.
The meanings (Telugu and English) are newly written for Devalay.

### Vemana Shatakam (వేమన పద్యాలు), 30 verses

- Index: https://te.wikisource.org/wiki/వేమన_పద్యాలు
- Pages used (split by first letter): వేమన_పద్యాలు/అ, /ఆ, /ఇ, /ఉ, /క, /గ, /చ, /త, /ద, /ధ, /న, /ప, /బ, /మ, /వ, /స
  (each entry's `source` gives the exact percent-encoded URL).
- Edition: the index page says the text was taken from the alphabetical index on andhrabharati.com, which in turn
  appears to derive from the 1910 Vavilla reprint of C. P. Brown's second edition of Vemana's verses
  (archive.org in.ernet.dli.2015.492165). No verse numbers are given on Wikisource, so `ref` is empty.
- Public domain: Vemana lived around the 17th century (Wikisource header: "17 వ శతాబ్దం"); C. P. Brown died 1884.
  The text is public domain; Wikisource page formatting is CC BY-SA.

### Sumathi Satakam (సుమతీ శతకము) by Baddena, 30 verses

- https://te.wikisource.org/wiki/సుమతీ_శతకము (verses 1-50)
- https://te.wikisource.org/wiki/సుమతీ_శతకము_-_రెండవభాగం (verses 51-110)
- `ref` is the verse number as numbered on these pages (001-110).
- Public domain: Baddena (Bhadra Bhupala) lived in the 13th century; the pages carry the {{PD-old}} tag.
  Wikisource page formatting is CC BY-SA.

### Notes

- The Sumathi page carries a "Migrate to సూచిక:Sumati Shatakamu.pdf" banner, so it may later be moved to a
  scanned-index edition; if the URL stops resolving, re-point `source` to the new page.
- Vemana's Wikisource text is a mixed compilation (1362 verses, some variants and duplicates); spelling varies
  between verses (e.g. "వినర వేమ" vs "వినురవేమ"), kept as in the source.

## Tamil (ta) sources: Thirukkural

**Text:** Thirukkural by Thiruvalluvar (classical Tamil, roughly 1st–5th century CE). The author died many centuries ago, so the text is public domain everywhere.

**Edition:** Tamil Wikisource, "திருக்குறள், மூலம்" (the plain text without commentary; the index page header says 1997). Proofread at quality level 3.
- Index/work page: https://ta.wikisource.org/wiki/திருக்குறள்,_மூலம்
- Each verse's `source` is the proofread Page-namespace scan page that holds it, e.g.
  https://ta.wikisource.org/wiki/பக்கம்:திருக்குறள்,_மூலம்.pdf/9 (kurals 1–10). Pages /15 to /114 were used.
  (The main work page only transcludes these pages, so its `?action=raw` contains no verse text.)

**Licence:** the verse text is public domain. Wikisource's page formatting is CC BY-SA.

**Method:** pages 9–118 were downloaded with `?action=raw`. Couplets were split at the `{{Pline|N|r}}` markers and numbered by their order in the text. That order matches the printed kural numbers everywhere except one label typo in the source: kural 72 is printed as "71". The selection has 30 kurals from Aram (Virtue) and 30 from Porul (Wealth): God, love, kind speech, gratitude, self-control, truth, non-harm, learning, listening, effort, friendship and noble character. Kurals with visible typos in this transcription (for example 784 "மேற்செனறு" and 858) were left out. So was 666, because the source reads "எய்துவர்" where most editions read "எய்துப".

Cross-check consulted, not cited: "திருக்குறள் பரிமேலழகர் உரை" on ta.wikisource, which gives the old sandhi form and a word-split form of each couplet.

## Gujarati (gu) sources: Narsinh Mehta (c. 1414–1481)

All 61 excerpts are padas/prabhatiyas by Narsinh Mehta. The text was copied by script from proofreading pages
(Page namespace, `પૃષ્ઠ:`) of scanned books on Gujarati Wikisource, reached through the poem pages in
https://gu.wikisource.org/wiki/શ્રેણી:નરસિંહ_મહેતા . Each entry's `source` is the exact scan page (`.../પૃષ્ઠ:<book>.pdf/<page>`).
Only wiki markup (`{{gap}}`, `{{r|…}}`, section tags) and trailing refrain/stanza markers (e.g. "ટેક.", "જે.", "અ૦.",
"— વૈષ્ણવ ૧.") were removed. Each excerpt is one contiguous stanza (2 printed lines; one is 4 short lines).

| Book (Wikisource index) | Editor / year | Proofread level of pages used | Entries |
|---|---|---|---|
| બૃહત્ કાવ્યદોહન – ગ્રંથ ૧ (`Bruhad Kavyadohan Granth 1.pdf`) | ed. Ichchharam Suryaram Desai, 1908 | mostly 3 (proofread); pp. 36, 38, 42–45 are level 1 | 33 |
| ભજન સાર સિંધુ (`Bhajan Sar Sindhu.pdf`) | not stated on the index | 1 (not proofread) | 11 |
| નરસિંહ લેખન (`Narasinh lekhan 2.pdf`) | not stated on the index | 3 | 14 |
| મીરાં અને નરસિંહ (`Mira Ane Narsinh.pdf`) | ed. Harsiddhbhai V. Divetia | 1 | 3 |

Public domain: Narsinh Mehta died in the 15th century, so the poems are public domain everywhere. The 1908 Kavyadohan
edition is itself out of copyright. For the other three books Wikisource gives no year, but they only reproduce
the 15th-century text, and the verses we use are the poet's words, not editorial matter. Wikisource transcriptions of PD
texts are PD; Wikisource page formatting is CC BY-SA.

## Kannada (kn): Sarvajna tripadis, sources

All 59 verse texts were extracted by script (`work/build_kn.py`) from the raw wikitext (`?action=raw`) of these Kannada Wikisource pages:

- **Main collection:** https://kn.wikisource.org/wiki/ಸರ್ವಜ್ಞನ_ವಚನಗಳು. It holds about 780 numbered tripadis (numbers 1 to 1421, with gaps) arranged under topic headings. 37 entries come from here, and `ref` is the number printed on the page: 200, 215, 231, 272, 289, 412, 986, 987, 988, 990, 995, 1001, 1029, 1031, 1048, 1049, 1056, 1057, 1082, 1085, 1104, 1109, 1110, 1118, 1119, 1123, 1126, 1128, 1214, 1215, 1218, 1252, 1259, 1268, 1273, 1274, 1281. The page does not name the printed edition it was typed from.
- **Topic pages:** these are short, unnumbered pages linked from https://kn.wikisource.org/wiki/ಸರ್ವಜ್ಞ. 22 entries come from them, and `ref` is "" for these.
  - https://kn.wikisource.org/wiki/ದೇವರು-ಗುರು-ಜ್ಞಾನಿ (6)
  - https://kn.wikisource.org/wiki/ದಾನ-ತ್ಯಾಗಬುದ್ಧಿ (5)
  - https://kn.wikisource.org/wiki/ಸಜ್ಜನ-ದುರ್ಜನ (4)
  - https://kn.wikisource.org/wiki/ವರ್ಣ-ಜಾತಿ-ಮತ (3)
  - https://kn.wikisource.org/wiki/ಅನ್ನಾಹಾರ-ವೈದ್ಯ (2)
  - https://kn.wikisource.org/wiki/ಸರ್ವಜ್ಞನೆಂಬುವವನು (1)
  - https://kn.wikisource.org/wiki/ಡಂಭಾಚಾರ-ಪೊಳ್ಳು_ಭಕ್ತಿ (1)

The `source` URLs in kn.json are these addresses, percent-encoded.

**Public domain:** Sarvajna was a 16th-century Kannada poet (traditionally dated to around 1600), so his verses are long out of copyright. Wikisource transcriptions of PD texts are PD; the page formatting is CC BY-SA. All meanings are newly written.

**Editing done:** I removed the wiki/HTML markup (`<poem>`, `<BR>`), the verse numbers (e.g. "೯೮೬.") and the end-of-line verse marks ("।", "॥", "||"). Leading tabs are gone and runs of spaces are now single spaces. The three lines of each tripadi are joined with "\n". The mid-line caesura mark "।" in line 1 of the numbered verses is kept as it appears in the source. Spelling is otherwise exactly as in the source. The traditional line breaks fall mid-word in places (e.g. "ಹೊ / ನ್ನಾಗದೇ") and are kept. Verse 986 contains a ZWJ ("ಮಾಡಿರ್‍ದಕೆಲ್ಲ"), copied as in the source.

**Skipped on purpose:**
- Numbered verses with visible typing errors, e.g. 1030 ("ಎಅರಗಿದರೆ \"), 1046 ("ಕ್ನಿವಂಗೆ", "ಮನ್ಸಿಜಾರಿ"), 1108 ("ಆಭ್ವಾನ"), 1112 ("ಕ್ಲಸಲಂಬಲಿ").
- Verses whose meaning I could not pin down confidently, e.g. "ಧ್ಯಾನದಾ ಹೊಸಬತ್ತಿ…", "ಸೊಡರೆಣ್ಣೆ ತೀರಿದರೆ…" and 1203.
- Verses that mock castes, sects or women, use caste slurs, or are crude. This covers the ಜಾತಿ/ಮತ sections, the occupational-caste sections, the "ಸ್ತ್ರೀ" sections, "ಸತ್ತದನು ತಿಂಬಾತ…", "ಕೊಲುವ ಧರ್ಮವನೊಯ್ದು…" and most of the ಡಂಭಾಚಾರ page.
- Near-duplicates of verses already chosen, e.g. 228, which is the same as "ಮನದಲ್ಲಿ ನೆನೆವಂಗೆ", 856, which is the same as "ಎಲವಿಲ್ಲ ನಾಲಗೆಗೆ", and 1220, which is close to "ಆಡದೇ ಕೊಡುವವನು".

**Caveats:** The main page looks like a typed or OCR'd text with some non-standard spellings (e.g. "ಸರ್ವಜ್ನ್ಯ" in 412, "ಮರೆದಿಹುದು" for ಮೆರೆದಿಹುದು in 988). They are kept because the brief says to keep source spelling. The topic pages read more cleanly. Readings of Sarvajna differ widely between editions, so a reader may know a slightly different version of a verse.

## Malayalam (ml) sources

All texts come from Malayalam Wikisource. The verse texts are public domain; Wikisource's page formatting is CC BY-SA.

| Work | Author (death) | URL | Used |
|---|---|---|---|
| ജ്ഞാനപ്പാന (Jnanappana) | Poonthanam Nambudiri (16th c., d. c. 1640) | https://ml.wikisource.org/wiki/ജ്ഞാനപ്പാന | 29 passages of 2–4 lines |
| ദൈവദശകം (Daiva Dasakam, 1914) | Sree Narayana Guru (d. 1928) | https://ml.wikisource.org/wiki/ദൈവദശകം | all 10 verses |
| അനുകമ്പാദശകം (Anukampa Dasakam, 1914) | Sree Narayana Guru | https://ml.wikisource.org/wiki/അനുകമ്പാദശകം | verses 1, 2, 3, 5 and the phalashruti |
| ആത്മോപദേശശതകം (Atmopadesa Satakam, 1897) | Sree Narayana Guru | https://ml.wikisource.org/wiki/ആത്മോപദേശശതകം | verses 22, 23, 24, 25, 44, 46, 49 |
| ജീവകാരുണ്യപഞ്ചകം (Jeevakarunya Panchakam) | Sree Narayana Guru | https://ml.wikisource.org/wiki/ജീവകാരുണ്യപഞ്ചകം | verses 1, 2 |
| അഹിംസ (Ahimsa) | Sree Narayana Guru | https://ml.wikisource.org/wiki/അഹിംസ | verses 2, 3 |
| സദാചാരം (Sadacharam) | Sree Narayana Guru | https://ml.wikisource.org/wiki/സദാചാരം | verses 1, 2, 5, 7 |
| ജാതിനിർണ്ണയം (Jati Nirnayam) | Sree Narayana Guru | https://ml.wikisource.org/wiki/ജാതിനിർണ്ണയം | verse 2 ("ഒരു ജാതി ഒരു മതം ഒരു ദൈവം") |

**Public domain:** Poonthanam lived in the 16th–17th century. Sree Narayana Guru died in 1928, more than 60 years ago, which is India's term (life + 60 years). Wikisource's notes give no named editor; the texts are the standard ones.

**Method:** each page's wikitext was fetched with `?action=raw`, and the verses were cut out by script. Removed: wiki markup, `{{ശ്ലോ|N}}` verse numbers, `{{Ref}}` variant-reading marks, the repeat mark "(2)" and one stray trailing ZWJ. The source's line-end hyphens (e.g. "കൊ-" / "രാവിവൻ") were kept. The Jnanappana page gives no verse numbers, so `ref` is empty for those entries. The Guru's works use the source's verse numbers. The Anukampa Dasakam closing verse has `ref` "Phalashruti".

**Left out:** philosophically dense Atmopadesa verses, and Jnanappana lines on rebirth into particular castes or animals (lines like "ചണ്ഡാലകുലത്തിങ്കൽപ്പിറക്കുന്നു") and on wives and women.

## Odia (or) sources

Work: Odia Bhagabata (ଓଡ଼ିଆ ଭାଗବତ) by Jagannath Das (ଜଗନ୍ନାଥ ଦାସ), c. 1490s–1550s (16th century).
Public domain: the author died in the 16th century. Wikisource text is public domain; the page formatting is CC BY-SA.

Pages used (the checker fetches each with `?action=raw`):
- https://or.wikisource.org/wiki/ଓଡ଼ିଆ_ଭାଗବତ/୧୧ (Ekadasa Skandha, Book 11): 58 excerpts
  (percent-encoded in the JSON: https://or.wikisource.org/wiki/%E0%AC%93%E0%AC%A1%E0%AC%BC%E0%AC%BF%E0%AC%86_%E0%AC%AD%E0%AC%BE%E0%AC%97%E0%AC%AC%E0%AC%A4/%E0%AD%A7%E0%AD%A7)
- https://or.wikisource.org/wiki/ଓଡ଼ିଆ_ଭାଗବତ/୧ (Book 1, opening invocation): 1 excerpt
- https://or.wikisource.org/wiki/ଓଡ଼ିଆ_ଭାଗବତ/୨ (Book 2, ch. 1): 1 excerpt
- Index page: https://or.wikisource.org/wiki/ଓଡ଼ିଆ_ଭାଗବତ (no edition/editor is named on the pages).

`ref` format: skandha.adhyaya.couplet range, e.g. `11.8.131–133` (chapter = order of the chapter heading on the page;
couplet numbers as printed on the page). Each line of `text` is one couplet (pada) as on the page; trailing couplet
numbers and stray zero-width non-joiners (no visual effect) were removed. Spelling is kept as on Wikisource,
which is an unproofread transcription and has some typos; excerpts with visibly broken encoding were avoided.

Most excerpts come from the Uddhava Gita / Avadhuta's 24 gurus (11.7–11.11), the marks of a devotee (11.3, 11.12),
universal virtues (11.18, 11.20, 11.26), the Bhikshu Gita (11.24) and the praise of saintly company (11.27).

## Punjabi (pa) sources

Work: Salok Sheikh Farid (ਸਲੋਕ ਸੇਖ ਫਰੀਦ ਕੇ), Sri Guru Granth Sahib, Ang 1377–1384.
Author: Baba Sheikh Farid (Fariduddin Ganjshakar, d. 1266). Public domain: the author died in the 13th century,
and the Guru Granth Sahib was compiled in 1604.

All 60 entries are Farid's own sloks. Sloks with a Guru heading (ਮਃ / ਮਹਲਾ), sloks that name Nanak, and
113, 120, 121, 122, 123, 124 (often credited to the Gurus) were left out.

Pages used:
- https://www.gurugranthdarpan.net/1378.html … /1384.html (one page per Ang): 56 entries. This is the online
  "Sri Guru Granth Darpan" (Prof. Sahib Singh's commentary, in Unicode). Only the gurbani text is used; the commentary
  is not. The `source` of each entry is the Ang page where that slok appears.
- https://pa.wikisource.org/wiki/ਸ਼ਲੋਕ_ਸ਼ੇਖ_ਫਰੀਦ (Wikisource; text PD, page formatting CC BY-SA): 4 entries
  (sloks 2, 41, 64, 89). For these, the Darpan page writes the subscript ha as a doubled ੍ਹ੍ਹ, which renders badly.

Cross-check: every chosen slok matched the BaniDB text (https://api.banidb.com/v2/angs/<ang>/G, the database behind
SikhiToTheMax) exactly, ignoring punctuation and numbers. The pa.wikisource page has many small vowel-sign errors
(e.g. ਕਰ for ਕਰਿ), so it was used only where it matched BaniDB exactly. Sloks whose text did not match BaniDB in either
source were not used (for example 6 and 7).

`ref` gives the Ang and the slok number in the Farid series, e.g. "Ang 1382, Salok 78". Trailing ॥੭੮॥ numbers were
reduced to ॥.

Bulleh Shah was not used. His kafis on pa.wikisource ("ਕਾਫ਼ੀਆਂ ਬੁੱਲ੍ਹੇ ਸ਼ਾਹ") come from a 2007 edited edition and are
split across scanned proofreading pages, and Farid's sloks were enough for 60 entries.
