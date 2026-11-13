/// Odia translations of Devalay's one-line festival and deity descriptions, keyed by the English text.
/// Source list: tool/l10n/strings_descriptions.json. Keys must match the English exactly.
const descOr = <String, String>{
  'The Sun enters Makara; a harvest festival of holy dips, til-gud and kites.':
      'ସୂର୍ଯ୍ୟ ମକର ରାଶିରେ ପ୍ରବେଶ କରନ୍ତି; ପବିତ୍ର ସ୍ନାନ, ତିଳ-ଗୁଡ଼ ଓ ଗୁଡ଼ିର ଅମଳ ପର୍ବ।',
  'The first day of Sankranti in Andhra Pradesh and Telangana: Bhogi bonfire and Bhogi pallu.':
      'ଆନ୍ଧ୍ରପ୍ରଦେଶ ଓ ତେଲଙ୍ଗାନାରେ ସଂକ୍ରାନ୍ତିର ପ୍ରଥମ ଦିନ: ଭୋଗି ନିଆଁ ଓ ଭୋଗି ପଲ୍ଲୁ।',
  'The cattle festival on the day after Sankranti, honouring cows and farm life.':
      'ସଂକ୍ରାନ୍ତିର ପରଦିନ ଗୋରୁଗାଈ ପର୍ବ, ଗାଈ ଓ ଚାଷ ଜୀବନକୁ ସମ୍ମାନ।',
  'Surya Jayanti: the Sun god\'s chariot turns north; holy bath with arka leaves.':
      'ସୂର୍ଯ୍ୟ ଜୟନ୍ତୀ: ସୂର୍ଯ୍ୟଦେବଙ୍କ ରଥ ଉତ୍ତରକୁ ମୋଡ଼ ନିଏ; ଅର୍କ ପତ୍ର ସହ ପବିତ୍ର ସ୍ନାନ।',
  'Worship of Maa Saraswati, goddess of learning, at the start of spring.':
      'ବସନ୍ତ ଆରମ୍ଭରେ ବିଦ୍ୟାର ଦେବୀ ମା\' ସରସ୍ୱତୀଙ୍କ ପୂଜା।',
  'The great night of Shiva, kept with fasting, night-long vigil and abhishek.':
      'ଶିବଙ୍କ ମହାରାତ୍ରି, ଉପବାସ, ରାତିସାରା ଜାଗରଣ ଓ ଅଭିଷେକ ସହ ପାଳିତ।',
  'The bonfire recalling Prahlad\'s devotion and Holika\'s defeat.':
      'ପ୍ରହ୍ଲାଦଙ୍କ ଭକ୍ତି ଓ ହୋଲିକାର ପରାଜୟକୁ ମନେ ପକାଉଥିବା ଅଗ୍ନି ଉତ୍ସବ।',
  'The festival of colours celebrating spring, love and the victory of good.':
      'ବସନ୍ତ, ପ୍ରେମ ଓ ଭଲର ବିଜୟ ପାଳନ କରୁଥିବା ରଙ୍ଗର ପର୍ବ।',
  'New Year by the lunar calendar; Chaitra Navratri also begins today.':
      'ଚାନ୍ଦ୍ର ପଞ୍ଜିକା ଅନୁସାରେ ନୂଆ ବର୍ଷ; ଆଜି ଚୈତ୍ର ନବରାତ୍ରି ମଧ୍ୟ ଆରମ୍ଭ।',
  'The birth of Shri Ram, celebrated at midday with Ramayan path and bhajans.':
      'ଶ୍ରୀରାମଙ୍କ ଜନ୍ମ, ମଧ୍ୟାହ୍ନରେ ରାମାୟଣ ପାଠ ଓ ଭଜନ ସହ ପାଳିତ।',
  'The birth of Hanuman Ji, honoured with Hanuman Chalisa and Sundarkand.':
      'ହନୁମାନଙ୍କ ଜନ୍ମ, ହନୁମାନ ଚାଳିଶା ଓ ସୁନ୍ଦରକାଣ୍ଡ ପାଠ ସହ ପାଳିତ।',
  'An auspicious day for new beginnings, charity and Lakshmi-Narayan puja.':
      'ନୂଆ ଆରମ୍ଭ, ଦାନ ଓ ଲକ୍ଷ୍ମୀ-ନାରାୟଣ ପୂଜା ପାଇଁ ଶୁଭ ଦିନ।',
  'Vaishakha Purnima, remembered as the birth of the Buddha.': 'ବୈଶାଖ ପୂର୍ଣ୍ଣିମା, ବୁଦ୍ଧଙ୍କ ଜନ୍ମ ଦିନ ଭାବେ ସ୍ମରଣୀୟ।',
  'The descent of Maa Ganga to earth.': 'ମା\' ଗଙ୍ଗାଙ୍କ ପୃଥିବୀକୁ ଅବତରଣ।',
  'The strictest Ekadashi fast, kept without water.': 'ପାଣି ବିନା ପାଳିତ ସବୁଠୁ କଠୋର ଏକାଦଶୀ ଉପବାସ।',
  'Lord Jagannath\'s chariot procession, famous at Puri.': 'ମହାପ୍ରଭୁ ଶ୍ରୀଜଗନ୍ନାଥଙ୍କ ରଥଯାତ୍ରା, ପୁରୀରେ ବିଶ୍ୱପ୍ରସିଦ୍ଧ।',
  'Lord Vishnu begins his cosmic rest; Chaturmas starts.': 'ଭଗବାନ ବିଷ୍ଣୁ ଯୋଗନିଦ୍ରାକୁ ଯାଆନ୍ତି; ଚାତୁର୍ମାସ୍ୟ ଆରମ୍ଭ।',
  'Gratitude to the Guru and to Maharishi Ved Vyas.': 'ଗୁରୁ ଓ ମହର୍ଷି ବେଦବ୍ୟାସଙ୍କ ପ୍ରତି କୃତଜ୍ଞତା।',
  'Worship of the serpent deities.': 'ନାଗ ଦେବତାଙ୍କ ପୂଜା।',
  'Sisters tie rakhi; a festival of love and protection.': 'ଭଉଣୀମାନେ ରାଖୀ ବାନ୍ଧନ୍ତି; ସ୍ନେହ ଓ ସୁରକ୍ଷାର ପର୍ବ।',
  'Married women worship Varalakshmi on the Friday before Shravana Purnima.':
      'ଶ୍ରାବଣ ପୂର୍ଣ୍ଣିମା ପୂର୍ବର ଶୁକ୍ରବାରରେ ବିବାହିତା ମହିଳାମାନେ ବରଲକ୍ଷ୍ମୀଙ୍କ ପୂଜା କରନ୍ତି।',
  'The birth of Shri Krishna, celebrated with midnight puja and bhajans.':
      'ଶ୍ରୀକୃଷ୍ଣଙ୍କ ଜନ୍ମ, ମଧ୍ୟରାତ୍ରି ପୂଜା ଓ ଭଜନ ସହ ପାଳିତ।',
  'A fast honouring Maa Parvati\'s devotion to Shiva.': 'ଶିବଙ୍କ ପ୍ରତି ମା\' ପାର୍ବତୀଙ୍କ ଭକ୍ତିକୁ ସମ୍ମାନ ଦେଇ ପାଳିତ ବ୍ରତ।',
  'The arrival of Ganpati Bappa, welcomed for ten days of celebration.':
      'ଗଣପତି ବାପ୍ପାଙ୍କ ଆଗମନ, ଦଶ ଦିନର ଉତ୍ସବ ସହ ସ୍ୱାଗତ।',
  'Ganesh Visarjan and worship of Anant (Vishnu).': 'ଗଣେଶ ବିସର୍ଜନ ଓ ଅନନ୍ତ (ବିଷ୍ଣୁ)ଙ୍କ ପୂଜା।',
  'A fortnight of remembrance and offerings for ancestors.': 'ପିତୃପୁରୁଷଙ୍କ ସ୍ମରଣ ଓ ତର୍ପଣର ପକ୍ଷ।',
  'Mahalaya Amavasya: Telangana\'s nine-day flower festival of Bathukamma begins.':
      'ମହାଳୟା ଅମାବାସ୍ୟା: ତେଲଙ୍ଗାନାର ନଅ ଦିନିଆ ଫୁଲ ପର୍ବ ବଥୁକମ୍ମା ଆରମ୍ଭ।',
  'Nine nights of Maa Durga\'s worship begin with Ghatasthapana.': 'ଘଟସ୍ଥାପନା ସହ ମା\' ଦୁର୍ଗାଙ୍କ ନଅ ରାତିର ପୂଜା ଆରମ୍ଭ।',
  'Maha Ashtami, with Kanya Puja and Sandhi Puja.': 'ମହାଷ୍ଟମୀ, କୁମାରୀ ପୂଜା ଓ ସନ୍ଧି ପୂଜା ସହ।',
  'The grand final day of Bathukamma, on Durgashtami.': 'ଦୁର୍ଗାଷ୍ଟମୀ ଦିନ ବଥୁକମ୍ମାର ମହା ସମାପନ ଦିନ।',
  'Victory of Shri Ram over Ravan and of Maa Durga over Mahishasur.':
      'ରାବଣ ଉପରେ ଶ୍ରୀରାମଙ୍କ ଓ ମହିଷାସୁର ଉପରେ ମା\' ଦୁର୍ଗାଙ୍କ ବିଜୟ।',
  'The full moon of autumn; kheer is kept under moonlight.': 'ଶରତର ପୂର୍ଣ୍ଣିମା; ଜହ୍ନ ଆଲୁଅରେ ଖିରି ରଖାଯାଏ।',
  'Married women fast from sunrise to moonrise for their husbands.':
      'ବିବାହିତା ମହିଳାମାନେ ସ୍ୱାମୀଙ୍କ ପାଇଁ ସୂର୍ଯ୍ୟୋଦୟରୁ ଚନ୍ଦ୍ରୋଦୟ ପର୍ଯ୍ୟନ୍ତ ଉପବାସ ରଖନ୍ତି।',
  'Women fast for Gauri\'s blessings, swing on uyyala and offer dosas (atlu) at moonrise.':
      'ମହିଳାମାନେ ଗୌରୀଙ୍କ ଆଶୀର୍ବାଦ ପାଇଁ ଉପବାସ ରଖନ୍ତି, ଉୟ୍ୟାଲା (ଦୋଳି) ଝୁଲନ୍ତି ଓ ଚନ୍ଦ୍ରୋଦୟରେ ଦୋସା (ଅଟ୍ଲୁ) ଅର୍ପଣ କରନ୍ତି।',
  'The first day of Diwali; worship of Dhanvantari and Kuber.': 'ଦୀପାବଳିର ପ୍ରଥମ ଦିନ; ଧନ୍ୱନ୍ତରି ଓ କୁବେରଙ୍କ ପୂଜା।',
  'Choti Diwali, remembering Krishna\'s victory over Narakasur.': 'ଛୋଟ ଦୀପାବଳି, ନରକାସୁର ଉପରେ ଶ୍ରୀକୃଷ୍ଣଙ୍କ ବିଜୟର ସ୍ମରଣ।',
  'The festival of lights: Lakshmi-Ganesh puja on Kartika Amavasya evening.':
      'ଆଲୋକର ପର୍ବ: କାର୍ତ୍ତିକ ଅମାବାସ୍ୟା ସନ୍ଧ୍ୟାରେ ଲକ୍ଷ୍ମୀ-ଗଣେଶ ପୂଜା।',
  'Annakoot offered to Krishna, who lifted Govardhan hill.': 'ଗୋବର୍ଦ୍ଧନ ପର୍ବତ ଟେକିଥିବା ଶ୍ରୀକୃଷ୍ଣଙ୍କୁ ଅନ୍ନକୂଟ ଭୋଗ।',
  'Sisters pray for their brothers\' long life.': 'ଭଉଣୀମାନେ ଭାଇମାନଙ୍କ ଦୀର୍ଘାୟୁ ପାଇଁ ପ୍ରାର୍ଥନା କରନ୍ତି।',
  'Evening arghya to the setting Sun and Chhathi Maiya.': 'ଅସ୍ତଗାମୀ ସୂର୍ଯ୍ୟ ଓ ଛଠି ମାଈଙ୍କୁ ସନ୍ଧ୍ୟା ଅର୍ଘ୍ୟ।',
  'Milk is offered at snake mounds (putta) for the family\'s wellbeing.':
      'ପରିବାରର ମଙ୍ଗଳ ପାଇଁ ହୁଙ୍କାରେ (ପୁଟ୍ଟା) କ୍ଷୀର ଅର୍ପଣ।',
  'Lord Vishnu awakens; Tulsi Vivah and the wedding season begin.':
      'ଭଗବାନ ବିଷ୍ଣୁ ଜାଗ୍ରତ ହୁଅନ୍ତି; ତୁଳସୀ ବିବାହ ଓ ବିବାହ ଋତୁ ଆରମ୍ଭ।',
  'Holy dips and lamps on the ghats; Guru Nanak Jayanti falls today too.':
      'ଘାଟରେ ପବିତ୍ର ସ୍ନାନ ଓ ଦୀପ; ଆଜି ଗୁରୁ ନାନକ ଜୟନ୍ତୀ ମଧ୍ୟ।',
  'The divine wedding of Shri Ram and Mata Sita.': 'ଶ୍ରୀରାମ ଓ ମା\' ସୀତାଙ୍କ ଦିବ୍ୟ ବିବାହ।',
  'The day Shri Krishna spoke the Bhagavad Gita to Arjuna.': 'ଯେଉଁ ଦିନ ଶ୍ରୀକୃଷ୍ଣ ଅର୍ଜୁନଙ୍କୁ ଭଗବଦ୍ ଗୀତା ଉପଦେଶ ଦେଇଥିଲେ।',
  'Mahadev, the auspicious one: destroyer of ignorance, lord of yoga and compassion.':
      'ମହାଦେବ, ମଙ୍ଗଳମୟ: ଅଜ୍ଞାନର ବିନାଶକ, ଯୋଗ ଓ କରୁଣାର ଅଧିପତି।',
  'Bajrangbali, devoted servant of Shri Ram, giver of strength, courage and wisdom.':
      'ବଜରଙ୍ଗବଳୀ, ଶ୍ରୀରାମଙ୍କ ଅନନ୍ୟ ସେବକ, ବଳ, ସାହସ ଓ ବୁଦ୍ଧିଦାତା।',
  'Ganpati, remover of obstacles, worshipped first before every undertaking.':
      'ଗଣପତି, ବିଘ୍ନହର୍ତ୍ତା, ପ୍ରତିଟି ଶୁଭ କାମ ପୂର୍ବରୁ ପ୍ରଥମେ ପୂଜିତ।',
  'Narayan, the preserver, who descends as avatars to protect dharma.':
      'ନାରାୟଣ, ପାଳନକର୍ତ୍ତା, ଧର୍ମ ରକ୍ଷା ପାଇଁ ଅବତାର ନିଅନ୍ତି।',
  'Srinivasa of Tirumala, the Lord of the Seven Hills, who answers every sincere prayer.':
      'ତିରୁମଳାର ଶ୍ରୀନିବାସ, ସପ୍ତଗିରିର ପ୍ରଭୁ, ଯିଏ ପ୍ରତିଟି ଆନ୍ତରିକ ପ୍ରାର୍ଥନା ଶୁଣନ୍ତି।',
  'Goddess of prosperity, beauty and good fortune, consort of Vishnu.':
      'ସମୃଦ୍ଧି, ସୌନ୍ଦର୍ଯ୍ୟ ଓ ସୌଭାଗ୍ୟର ଦେବୀ, ବିଷ୍ଣୁଙ୍କ ସହଧର୍ମିଣୀ।',
  'Lord of Saturday and karma, who rewards patience and honest effort.':
      'ଶନିବାର ଓ କର୍ମର ଅଧିପତି, ଯିଏ ଧୈର୍ଯ୍ୟ ଓ ସଚ୍ଚୋଟ ପରିଶ୍ରମର ଫଳ ଦିଅନ୍ତି।',
  'The Sun, the visible god, source of light, health and the Gayatri Mantra.':
      'ସୂର୍ଯ୍ୟ, ପ୍ରତ୍ୟକ୍ଷ ଦେବତା, ଆଲୋକ, ସ୍ୱାସ୍ଥ୍ୟ ଓ ଗାୟତ୍ରୀ ମନ୍ତ୍ରର ଉତ୍ସ।',
  'Maryada Purushottam, the ideal king and seventh avatar of Vishnu.':
      'ମର୍ଯ୍ୟାଦା ପୁରୁଷୋତ୍ତମ, ଆଦର୍ଶ ରାଜା ଓ ବିଷ୍ଣୁଙ୍କ ସପ୍ତମ ଅବତାର।',
  'The eighth avatar, teacher of the Bhagavad Gita and the playful cowherd of Vrindavan.':
      'ଅଷ୍ଟମ ଅବତାର, ଭଗବଦ୍ ଗୀତାର ଉପଦେଷ୍ଟା ଓ ବୃନ୍ଦାବନର ଲୀଳାମୟ ଗୋପାଳ।',
  'The divine couple, the highest expression of loving devotion.': 'ଦିବ୍ୟ ଯୁଗଳ, ପ୍ରେମଭକ୍ତିର ସର୍ବୋଚ୍ଚ ପ୍ରକାଶ।',
  'Mata Rani, the invincible mother who destroys evil and protects her children.':
      'ମାତା ରାଣୀ, ଅଜେୟ ମା\', ଯିଏ ଅଶୁଭର ବିନାଶ କରି ନିଜ ସନ୍ତାନଙ୍କୁ ରକ୍ଷା କରନ୍ତି।',
  'The fierce mother beyond time, who frees devotees from fear.':
      'କାଳର ଅତୀତ ଉଗ୍ର ମା\', ଯିଏ ଭକ୍ତଙ୍କୁ ଭୟରୁ ମୁକ୍ତ କରନ୍ତି।',
  'Goddess of knowledge, music, speech and the arts.': 'ଜ୍ଞାନ, ସଙ୍ଗୀତ, ବାଣୀ ଓ କଳାର ଦେବୀ।',
  'Prayers and mantras for every day.': 'ପ୍ରତିଦିନ ପାଇଁ ପ୍ରାର୍ଥନା ଓ ମନ୍ତ୍ର।',
};
