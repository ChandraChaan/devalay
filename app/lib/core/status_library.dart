import 'muhurta.dart' show tarabalam, taraLabel;
import 'telugu.dart';

/// The curated verse and greeting library behind AI Status. Everything is composed on the phone: no
/// hosted model, no key, no cost, and it works offline. The verses are traditional Sanskrit (public
/// domain); the meanings are Devalay's own translations.

class Verse {
  const Verse(this.id, this.deities, this.tags, this.te, this.hi, this.en, this.meaning);
  final String id;

  /// Deity slugs this verse belongs to ('general' fits any day).
  final List<String> deities;

  /// Extra tags it suits: weekday names, 'morning', 'night', festival slugs.
  final List<String> tags;

  /// The verse in Telugu script, Devanagari and Roman (IAST) transliteration.
  final String te, hi, en;

  /// Meaning in English, Telugu and Hindi (in that order).
  final (String, String, String) meaning;

  String text(String lang) => switch (lang) {
    'te' => te,
    'hi' => hi,
    _ => en,
  };

  String meaningIn(String lang) => switch (lang) {
    'te' => meaning.$2,
    'hi' => meaning.$3,
    _ => meaning.$1,
  };
}

const verses = <Verse>[
  Verse(
    'shatamanam',
    ['general'],
    ['birthday'],
    'శతమానం భవతి శతాయుః పురుషః శతేంద్రియః ।\nఆయుష్యేవేంద్రియే ప్రతితిష్ఠతి ॥',
    'शतमानं भवति शतायुः पुरुषः शतेन्द्रियः ।\nआयुष्येवेन्द्रिये प्रतितिष्ठति ॥',
    'Śatamānaṁ bhavati śatāyuḥ puruṣaḥ śatendriyaḥ\nāyuṣy evendriye pratitiṣṭhati',
    (
      'May you live a hundred years with all your strength; may long life and vigour stay with you.',
      'నిండు నూరేళ్లు, సంపూర్ణ శక్తితో జీవించు. దీర్ఘాయుష్షు, ఆరోగ్యం ఎల్లప్పుడూ నీతోనే ఉండాలి.',
      'सौ वर्ष जियो, पूरी शक्ति के साथ; दीर्घ आयु और ओज सदा तुम्हारे साथ रहें।',
    ),
  ),
  Verse(
    'vakratunda',
    ['ganesha'],
    ['wednesday', 'vinayaka-chavithi'],
    'వక్రతుండ మహాకాయ సూర్యకోటి సమప్రభ ।\nనిర్విఘ్నం కురు మే దేవ సర్వకార్యేషు సర్వదా ॥',
    'वक्रतुण्ड महाकाय सूर्यकोटि समप्रभ ।\nनिर्विघ्नं कुरु मे देव सर्वकार्येषु सर्वदा ॥',
    'Vakratuṇḍa mahākāya sūryakoṭi samaprabha\nnirvighnaṁ kuru me deva sarvakāryeṣu sarvadā',
    (
      'O Lord of the curved trunk and mighty form, radiant as a million suns, keep every work of mine free of obstacles, always.',
      'వంకర తొండం, మహాకాయం, కోటి సూర్యుల కాంతి గల దేవా! నా పనులన్నిటినీ ఎల్లప్పుడూ విఘ్నాలు లేకుండా నెరవేర్చు.',
      'हे वक्रतुण्ड, विशालकाय, करोड़ों सूर्यों के समान तेजस्वी देव! मेरे सभी कार्य सदा निर्विघ्न पूरे करें।',
    ),
  ),
  Verse(
    'shuklambaradharam',
    ['ganesha', 'general'],
    ['wednesday', 'morning'],
    'శుక్లాంబరధరం విష్ణుం శశివర్ణం చతుర్భుజమ్ ।\nప్రసన్నవదనం ధ్యాయేత్ సర్వవిఘ్నోపశాంతయే ॥',
    'शुक्लाम्बरधरं विष्णुं शशिवर्णं चतुर्भुजम् ।\nप्रसन्नवदनं ध्यायेत् सर्वविघ्नोपशान्तये ॥',
    'Śuklāmbaradharaṁ viṣṇuṁ śaśivarṇaṁ caturbhujam\nprasannavadanaṁ dhyāyet sarvavighnopaśāntaye',
    (
      'Meditate on the all-pervading one, clad in white, bright as the moon, four-armed and smiling, and every obstacle is calmed.',
      'తెల్లని వస్త్రాలు ధరించి, చంద్రుని వంటి కాంతితో, నాలుగు చేతులతో, ప్రసన్న వదనంతో ఉన్న దేవుని ధ్యానిస్తే అన్ని విఘ్నాలు తొలగిపోతాయి.',
      'श्वेत वस्त्रधारी, चन्द्रमा जैसे उज्ज्वल, चतुर्भुज, प्रसन्नमुख प्रभु का ध्यान करें, सब विघ्न शान्त हो जाते हैं।',
    ),
  ),
  Verse(
    'tryambakam',
    ['shiva'],
    ['monday', 'karthika', 'maha-shivaratri'],
    'ఓం త్ర్యంబకం యజామహే సుగంధిం పుష్టివర్ధనమ్ ।\nఉర్వారుకమివ బంధనాన్ మృత్యోర్ముక్షీయ మామృతాత్ ॥',
    'ॐ त्र्यम्बकं यजामहे सुगन्धिं पुष्टिवर्धनम् ।\nउर्वारुकमिव बन्धनान्मृत्योर्मुक्षीय मामृतात् ॥',
    'Oṁ tryambakaṁ yajāmahe sugandhiṁ puṣṭivardhanam\nurvārukam iva bandhanān mṛtyor mukṣīya māmṛtāt',
    (
      'We worship the three-eyed Lord, fragrant, who nourishes all. As a ripe cucumber slips from its vine, may he free us from death, not from immortality.',
      'సుగంధభరితుడు, సమస్త జీవులను పోషించే త్రినేత్రుడైన శివుని పూజిస్తున్నాం. పండిన దోసపండు తీగ నుండి విడిపడినట్లు, మమ్మల్ని మృత్యువు నుండి విడిపించి అమృతత్వం ప్రసాదించు.',
      'हम सुगन्धित, पोषण बढ़ाने वाले त्रिनेत्र शिव की पूजा करते हैं। जैसे पका खीरा बेल से छूट जाता है, वैसे ही वे हमें मृत्यु से मुक्त करें, अमरता से नहीं।',
    ),
  ),
  Verse(
    'karpuragauram',
    ['shiva'],
    ['monday', 'night', 'karthika'],
    'కర్పూరగౌరం కరుణావతారం సంసారసారం భుజగేంద్రహారమ్ ।\nసదా వసంతం హృదయారవిందే భవం భవానీసహితం నమామి ॥',
    'कर्पूरगौरं करुणावतारं संसारसारं भुजगेन्द्रहारम् ।\nसदा वसन्तं हृदयारविन्दे भवं भवानीसहितं नमामि ॥',
    'Karpūragauraṁ karuṇāvatāraṁ saṁsārasāraṁ bhujagendrahāram\nsadā vasantaṁ hṛdayāravinde bhavaṁ bhavānīsahitaṁ namāmi',
    (
      'White as camphor, compassion in form, the essence of the world, garlanded with the serpent king: I bow to Shiva with Bhavani, who lives always in the lotus of the heart.',
      'కర్పూరం వంటి తెల్లని దేహం, కరుణే రూపమైనవాడు, జగత్తుకు సారమైనవాడు, నాగరాజును హారంగా ధరించినవాడు, ఎల్లప్పుడూ హృదయకమలంలో నివసించే భవానీసహిత శివునికి నమస్కారం.',
      'कपूर जैसे गौर, करुणा के अवतार, संसार के सार, नागराज का हार धारण करने वाले, हृदय-कमल में सदा बसने वाले भवानी सहित शिव को नमन।',
    ),
  ),
  Verse(
    'shantakaram',
    ['vishnu', 'venkateswara'],
    ['thursday', 'ekadashi', 'vaikuntha-ekadashi'],
    'శాంతాకారం భుజగశయనం పద్మనాభం సురేశం\nవిశ్వాధారం గగనసదృశం మేఘవర్ణం శుభాంగమ్ ।\nలక్ష్మీకాంతం కమలనయనం యోగిభిర్ధ్యానగమ్యం\nవందే విష్ణుం భవభయహరం సర్వలోకైకనాథమ్ ॥',
    'शान्ताकारं भुजगशयनं पद्मनाभं सुरेशं\nविश्वाधारं गगनसदृशं मेघवर्णं शुभाङ्गम् ।\nलक्ष्मीकान्तं कमलनयनं योगिभिर्ध्यानगम्यं\nवन्दे विष्णुं भवभयहरं सर्वलोकैकनाथम् ॥',
    'Śāntākāraṁ bhujagaśayanaṁ padmanābhaṁ sureśaṁ\nviśvādhāraṁ gaganasadṛśaṁ meghavarṇaṁ śubhāṅgam\nlakṣmīkāntaṁ kamalanayanaṁ yogibhirdhyānagamyaṁ\nvande viṣṇuṁ bhavabhayaharaṁ sarvalokaikanātham',
    (
      'Peaceful, resting on the serpent, lotus-navelled Lord of the gods, support of the universe, vast as the sky, dark as a rain cloud: I bow to Vishnu, beloved of Lakshmi, who takes away the fear of worldly life.',
      'శాంత స్వరూపుడు, శేషశయనుడు, పద్మనాభుడు, దేవతల ప్రభువు, విశ్వానికి ఆధారం, ఆకాశమంత విశాలుడు, మేఘవర్ణుడు, లక్ష్మీపతి అయిన విష్ణువుకు నమస్కారం. ఆయన సంసార భయాన్ని తొలగిస్తాడు.',
      'शान्त स्वरूप, शेषशायी, पद्मनाभ, देवों के ईश, विश्व के आधार, आकाश समान, मेघवर्ण, लक्ष्मीपति विष्णु को वन्दन, जो भव-भय हरते हैं।',
    ),
  ),
  Verse(
    'vina-venkatesham',
    ['venkateswara'],
    ['saturday'],
    'వినా వేంకటేశం న నాథో న నాథః\nసదా వేంకటేశం స్మరామి స్మరామి ।\nహరే వేంకటేశ ప్రసీద ప్రసీద\nప్రియం వేంకటేశ ప్రయచ్ఛ ప్రయచ్ఛ ॥',
    'विना वेङ्कटेशं न नाथो न नाथः\nसदा वेङ्कटेशं स्मरामि स्मरामि ।\nहरे वेङ्कटेश प्रसीद प्रसीद\nप्रियं वेङ्कटेश प्रयच्छ प्रयच्छ ॥',
    'Vinā veṅkaṭeśaṁ na nātho na nāthaḥ\nsadā veṅkaṭeśaṁ smarāmi smarāmi\nhare veṅkaṭeśa prasīda prasīda\npriyaṁ veṅkaṭeśa prayaccha prayaccha',
    (
      'Without Venkatesha there is no other protector. I remember Venkatesha always. O Venkatesha, be gracious, and grant what is dear.',
      'వేంకటేశుడు తప్ప నాకు వేరే దిక్కు లేదు. ఎల్లప్పుడూ వేంకటేశుని స్మరిస్తాను. ఓ వేంకటేశా, ప్రసన్నుడివై మాకు శుభం ప్రసాదించు.',
      'वेंकटेश के बिना कोई दूसरा स्वामी नहीं। मैं सदा वेंकटेश का स्मरण करता हूँ। हे वेंकटेश, प्रसन्न हों और प्रिय वर दें।',
    ),
  ),
  Verse(
    'kausalya-supraja',
    ['venkateswara', 'rama', 'general'],
    ['morning'],
    'కౌసల్యా సుప్రజా రామ పూర్వా సంధ్యా ప్రవర్తతే ।\nఉత్తిష్ఠ నరశార్దూల కర్తవ్యం దైవమాహ్నికమ్ ॥',
    'कौसल्यासुप्रजा राम पूर्वा सन्ध्या प्रवर्तते ।\nउत्तिष्ठ नरशार्दूल कर्तव्यं दैवमाह्निकम् ॥',
    'Kausalyā suprajā rāma pūrvā sandhyā pravartate\nuttiṣṭha naraśārdūla kartavyaṁ daivam āhnikam',
    (
      'O Rama, dear son of Kausalya, dawn is breaking in the east. Rise, best of men, the day\'s sacred duties await.',
      'కౌసల్యాదేవి ప్రియ పుత్రా రామా! తూర్పున సంధ్య వెలుగుతోంది. ఓ పురుషోత్తమా, లే! దైవిక విధులు నిర్వర్తించే సమయమైంది.',
      'हे कौसल्या के सुपुत्र राम! पूर्व दिशा में भोर हो रही है। हे नरश्रेष्ठ, उठिए, दिन के दिव्य कर्तव्य आपकी प्रतीक्षा में हैं।',
    ),
  ),
  Verse(
    'rama-nama',
    ['rama'],
    ['rama-navami', 'vivah-panchami'],
    'శ్రీ రామ రామ రామేతి రమే రామే మనోరమే ।\nసహస్రనామ తత్తుల్యం రామనామ వరాననే ॥',
    'श्री राम राम रामेति रमे रामे मनोरमे ।\nसहस्रनाम तत्तुल्यं रामनाम वरानने ॥',
    'Śrī rāma rāma rāmeti rame rāme manorame\nsahasranāma tattulyaṁ rāmanāma varānane',
    (
      'Shiva tells Parvati: chanting Rama, Rama, Rama, I delight in Rama. The name of Rama alone equals the thousand names of Vishnu.',
      'శివుడు పార్వతితో: \'రామ రామ రామ\' అని జపిస్తూ నేను రాముని యందే రమిస్తాను. ఒక్క రామనామం విష్ణు సహస్రనామాలతో సమానం.',
      'शिव पार्वती से कहते हैं: \'राम राम राम\' जपते हुए मैं राम में ही रमता हूँ। एक रामनाम विष्णु सहस्रनाम के बराबर है।',
    ),
  ),
  Verse(
    'manojavam',
    ['hanuman'],
    ['tuesday', 'saturday', 'hanuman-jayanti'],
    'మనోజవం మారుతతుల్యవేగం జితేంద్రియం బుద్ధిమతాం వరిష్ఠమ్ ।\nవాతాత్మజం వానరయూథముఖ్యం శ్రీరామదూతం శరణం ప్రపద్యే ॥',
    'मनोजवं मारुततुल्यवेगं जितेन्द्रियं बुद्धिमतां वरिष्ठम् ।\nवातात्मजं वानरयूथमुख्यं श्रीरामदूतं शरणं प्रपद्ये ॥',
    'Manojavaṁ mārutatulyavegaṁ jitendriyaṁ buddhimatāṁ variṣṭham\nvātātmajaṁ vānarayūthamukhyaṁ śrīrāmadūtaṁ śaraṇaṁ prapadye',
    (
      'Swift as the mind, fast as the wind, master of the senses, wisest of the wise, son of the Wind and chief of the vanaras: I take refuge in Hanuman, the messenger of Shri Rama.',
      'మనసంత వేగం, వాయువంత జవం గలవాడు, ఇంద్రియాలను జయించినవాడు, బుద్ధిమంతులలో శ్రేష్ఠుడు, వాయుపుత్రుడు, వానర సేనానాయకుడు అయిన శ్రీరామదూత హనుమంతుని శరణు వేడుతున్నాను.',
      'मन के समान वेगवान, वायु के समान तीव्र, जितेन्द्रिय, बुद्धिमानों में श्रेष्ठ, पवनपुत्र, वानरसेना के प्रमुख श्रीराम के दूत हनुमान की शरण लेता हूँ।',
    ),
  ),
  Verse(
    'krishnaya-vasudevaya',
    ['krishna', 'radha-krishna'],
    ['krishnashtami'],
    'కృష్ణాయ వాసుదేవాయ హరయే పరమాత్మనే ।\nప్రణతః క్లేశనాశాయ గోవిందాయ నమో నమః ॥',
    'कृष्णाय वासुदेवाय हरये परमात्मने ।\nप्रणतः क्लेशनाशाय गोविन्दाय नमो नमः ॥',
    'Kṛṣṇāya vāsudevāya haraye paramātmane\npraṇataḥ kleśanāśāya govindāya namo namaḥ',
    (
      'To Krishna, son of Vasudeva, Hari, the supreme Self, who ends the sorrow of all who bow to him: to Govinda, salutations again and again.',
      'వాసుదేవ తనయుడు, హరి, పరమాత్మ, శరణన్నవారి కష్టాలు తీర్చే గోవిందుడైన శ్రీకృష్ణునికి మళ్ళీ మళ్ళీ నమస్కారం.',
      'वासुदेव-पुत्र, हरि, परमात्मा, शरणागत के क्लेश मिटाने वाले गोविन्द श्रीकृष्ण को बारम्बार नमस्कार।',
    ),
  ),
  Verse(
    'karmanye',
    ['krishna', 'general'],
    ['gita-jayanti'],
    'కర్మణ్యేవాధికారస్తే మా ఫలేషు కదాచన ।\nమా కర్మఫలహేతుర్భూః మా తే సంగోఽస్త్వకర్మణి ॥',
    'कर्मण्येवाधिकारस्ते मा फलेषु कदाचन ।\nमा कर्मफलहेतुर्भूर्मा ते सङ्गोऽस्त्वकर्मणि ॥',
    'Karmaṇy evādhikāras te mā phaleṣu kadācana\nmā karmaphalahetur bhūr mā te saṅgo \'stv akarmaṇi',
    (
      'Your right is to the work alone, never to its fruits. Do not work for the reward, and do not cling to doing nothing. (Gita 2.47)',
      'నీకు కర్మ చేయడంలోనే అధికారం, ఫలితాలపై ఎప్పుడూ కాదు. ఫలాపేక్షతో పని చేయకు, పని మానేయడంపైనా ఆసక్తి పెంచుకోకు. (గీత 2.47)',
      'तुम्हारा अधिकार केवल कर्म पर है, फल पर कभी नहीं। फल की इच्छा से कर्म मत करो, और कर्म न करने में भी आसक्ति न हो। (गीता 2.47)',
    ),
  ),
  Verse(
    'yada-yada',
    ['krishna'],
    ['gita-jayanti'],
    'యదా యదా హి ధర్మస్య గ్లానిర్భవతి భారత ।\nఅభ్యుత్థానమధర్మస్య తదాత్మానం సృజామ్యహమ్ ॥',
    'यदा यदा हि धर्मस्य ग्लानिर्भवति भारत ।\nअभ्युत्थानमधर्मस्य तदात्मानं सृजाम्यहम् ॥',
    'Yadā yadā hi dharmasya glānir bhavati bhārata\nabhyutthānam adharmasya tadātmānaṁ sṛjāmy aham',
    (
      'Whenever dharma declines and adharma rises, O Bharata, I manifest myself. (Gita 4.7)',
      'ఓ భారతా! ఎప్పుడెప్పుడు ధర్మానికి హాని కలిగి అధర్మం పెరుగుతుందో, అప్పుడప్పుడు నన్ను నేను సృజించుకుంటాను. (గీత 4.7)',
      'हे भारत! जब-जब धर्म की हानि और अधर्म की वृद्धि होती है, तब-तब मैं स्वयं को प्रकट करता हूँ। (गीता 4.7)',
    ),
  ),
  Verse(
    'namastestu',
    ['lakshmi'],
    ['friday', 'diwali', 'varalakshmi-vratam'],
    'నమస్తేఽస్తు మహామాయే శ్రీపీఠే సురపూజితే ।\nశంఖచక్రగదాహస్తే మహాలక్ష్మి నమోఽస్తు తే ॥',
    'नमस्तेऽस्तु महामाये श्रीपीठे सुरपूजिते ।\nशङ्खचक्रगदाहस्ते महालक्ष्मि नमोऽस्तु ते ॥',
    'Namaste \'stu mahāmāye śrīpīṭhe surapūjite\nśaṅkhacakragadāhaste mahālakṣmi namo \'stu te',
    (
      'Salutations to you, great Maya, seated on the throne of prosperity, worshipped by the gods, holding conch, discus and mace: Mahalakshmi, I bow to you.',
      'శ్రీపీఠంపై కొలువై, దేవతలచే పూజలందుకునే, శంఖ చక్ర గదలు ధరించిన మహామాయా! మహాలక్ష్మీ, నీకు నమస్కారం.',
      'श्रीपीठ पर विराजमान, देवताओं से पूजित, शंख-चक्र-गदा धारण करने वाली महामाया महालक्ष्मी, आपको नमस्कार।',
    ),
  ),
  Verse(
    'karagre',
    ['lakshmi', 'saraswati', 'general'],
    ['morning'],
    'కరాగ్రే వసతే లక్ష్మీః కరమధ్యే సరస్వతీ ।\nకరమూలే తు గోవిందః ప్రభాతే కరదర్శనమ్ ॥',
    'कराग्रे वसते लक्ष्मीः करमध्ये सरस्वती ।\nकरमूले तु गोविन्दः प्रभाते करदर्शनम् ॥',
    'Karāgre vasate lakṣmīḥ karamadhye sarasvatī\nkaramūle tu govindaḥ prabhāte karadarśanam',
    (
      'Lakshmi lives at the fingertips, Saraswati in the palm and Govinda at its base: look at your hands at dawn.',
      'చేతి వేళ్ల కొనల్లో లక్ష్మి, అరచేతి మధ్యలో సరస్వతి, మణికట్టు వద్ద గోవిందుడు ఉంటారు. అందుకే ఉదయాన్నే అరచేతులను దర్శించాలి.',
      'हाथ के अग्रभाग में लक्ष्मी, मध्य में सरस्वती और मूल में गोविन्द बसते हैं, इसलिए प्रातः हथेलियों के दर्शन करें।',
    ),
  ),
  Verse(
    'sarvamangala',
    ['durga', 'kali'],
    ['friday', 'tuesday', 'navaratri', 'anniversary'],
    'సర్వమంగళ మాంగళ్యే శివే సర్వార్థ సాధికే ।\nశరణ్యే త్ర్యంబకే గౌరి నారాయణి నమోఽస్తు తే ॥',
    'सर्वमङ्गलमाङ्गल्ये शिवे सर्वार्थसाधिके ।\nशरण्ये त्र्यम्बके गौरि नारायणि नमोऽस्तु ते ॥',
    'Sarvamaṅgala māṅgalye śive sarvārthasādhike\nśaraṇye tryambake gauri nārāyaṇi namo \'stu te',
    (
      'Auspiciousness of all that is auspicious, gracious one who fulfils every aim, refuge of all, three-eyed Gauri, Narayani: I bow to you.',
      'సర్వ మంగళాలకు మంగళమైన, సకల కోరికలు తీర్చే, శరణాగతులను కాపాడే త్రినేత్రి గౌరీ, నారాయణీ, నీకు నమస్కారం.',
      'सब मंगलों में मंगलमयी, सब अर्थ सिद्ध करने वाली, शरणागतवत्सला, त्रिनेत्री गौरी नारायणी, आपको नमस्कार।',
    ),
  ),
  Verse(
    'ya-devi',
    ['durga', 'kali', 'lakshmi', 'saraswati'],
    ['navaratri'],
    'యా దేవీ సర్వభూతేషు శక్తిరూపేణ సంస్థితా ।\nనమస్తస్యై నమస్తస్యై నమస్తస్యై నమో నమః ॥',
    'या देवी सर्वभूतेषु शक्तिरूपेण संस्थिता ।\nनमस्तस्यै नमस्तस्यै नमस्तस्यै नमो नमः ॥',
    'Yā devī sarvabhūteṣu śaktirūpeṇa saṁsthitā\nnamas tasyai namas tasyai namas tasyai namo namaḥ',
    (
      'To the Goddess who dwells in every being as strength: salutations to her, again and again.',
      'సమస్త ప్రాణులలో శక్తి రూపంలో కొలువై ఉన్న దేవికి నమస్కారం, పదే పదే నమస్కారం.',
      'जो देवी सब प्राणियों में शक्ति रूप में स्थित हैं, उन्हें बारम्बार नमस्कार।',
    ),
  ),
  Verse(
    'saraswati-namastubhyam',
    ['saraswati'],
    ['vasant-panchami', 'thursday'],
    'సరస్వతి నమస్తుభ్యం వరదే కామరూపిణి ।\nవిద్యారంభం కరిష్యామి సిద్ధిర్భవతు మే సదా ॥',
    'सरस्वति नमस्तुभ्यं वरदे कामरूपिणि ।\nविद्यारम्भं करिष्यामि सिद्धिर्भवतु मे सदा ॥',
    'Sarasvati namastubhyaṁ varade kāmarūpiṇi\nvidyārambhaṁ kariṣyāmi siddhir bhavatu me sadā',
    (
      'Salutations, Saraswati, giver of boons. As I begin to learn, may I always succeed.',
      'వరాలిచ్చే సరస్వతీ దేవీ, నీకు నమస్కారం. విద్య ప్రారంభిస్తున్నాను, నాకు ఎల్లప్పుడూ సిద్ధి కలుగుగాక.',
      'वर देने वाली माँ सरस्वती, आपको नमस्कार। मैं विद्या आरम्भ कर रहा हूँ, मुझे सदा सफलता मिले।',
    ),
  ),
  Verse(
    'japakusuma',
    ['surya'],
    ['sunday', 'sankranti', 'ratha-saptami', 'morning'],
    'జపాకుసుమ సంకాశం కాశ్యపేయం మహాద్యుతిమ్ ।\nతమోఽరిం సర్వపాపఘ్నం ప్రణతోఽస్మి దివాకరమ్ ॥',
    'जपाकुसुमसङ्काशं काश्यपेयं महाद्युतिम् ।\nतमोऽरिं सर्वपापघ्नं प्रणतोऽस्मि दिवाकरम् ॥',
    'Japākusuma saṅkāśaṁ kāśyapeyaṁ mahādyutim\ntamo \'riṁ sarvapāpaghnaṁ praṇato \'smi divākaram',
    (
      'Red as the hibiscus, son of Kashyapa, of great radiance, enemy of darkness, destroyer of all sins: I bow to the Sun.',
      'మందార పువ్వు వంటి ఎర్రని కాంతి గల, కశ్యపుని కుమారుడు, మహాతేజస్వి, చీకటికి శత్రువు, సర్వపాపాలను హరించే సూర్యునికి నమస్కరిస్తున్నాను.',
      'गुड़हल के फूल जैसे लाल, कश्यप-पुत्र, महातेजस्वी, अन्धकार के शत्रु, सब पापों के नाशक सूर्यदेव को प्रणाम।',
    ),
  ),
  Verse(
    'nilanjana',
    ['shani'],
    ['saturday'],
    'నీలాంజన సమాభాసం రవిపుత్రం యమాగ్రజమ్ ।\nఛాయామార్తాండ సంభూతం తం నమామి శనైశ్చరమ్ ॥',
    'नीलाञ्जनसमाभासं रविपुत्रं यमाग्रजम् ।\nछायामार्तण्डसम्भूतं तं नमामि शनैश्चरम् ॥',
    'Nīlāñjana samābhāsaṁ raviputraṁ yamāgrajam\nchāyāmārtaṇḍa sambhūtaṁ taṁ namāmi śanaiścaram',
    (
      'Dark as blue collyrium, son of the Sun and elder brother of Yama, born of Chhaya and Surya: I bow to Shani.',
      'నీలాంజనం వంటి కాంతి గల, సూర్యపుత్రుడు, యముని అన్న, ఛాయా సూర్యుల కుమారుడైన శనైశ్చరునికి నమస్కారం.',
      'नीले अंजन के समान आभा वाले, सूर्यपुत्र, यम के बड़े भाई, छाया और सूर्य से उत्पन्न शनिदेव को नमस्कार।',
    ),
  ),
  Verse(
    'guru-brahma',
    ['dattatreya', 'general'],
    ['thursday', 'guru-purnima', 'datta-jayanti'],
    'గురుర్బ్రహ్మా గురుర్విష్ణుః గురుర్దేవో మహేశ్వరః ।\nగురుః సాక్షాత్ పరబ్రహ్మ తస్మై శ్రీగురవే నమః ॥',
    'गुरुर्ब्रह्मा गुरुर्विष्णुः गुरुर्देवो महेश्वरः ।\nगुरुः साक्षात् परब्रह्म तस्मै श्रीगुरवे नमः ॥',
    'Gurur brahmā gurur viṣṇuḥ gurur devo maheśvaraḥ\nguruḥ sākṣāt parabrahma tasmai śrīgurave namaḥ',
    (
      'The guru is Brahma, the guru is Vishnu, the guru is Maheshvara; the guru is the supreme Brahman itself. Salutations to that guru.',
      'గురువే బ్రహ్మ, గురువే విష్ణువు, గురువే మహేశ్వరుడు. గురువే సాక్షాత్ పరబ్రహ్మ. అటువంటి శ్రీగురువుకు నమస్కారం.',
      'गुरु ही ब्रह्मा, गुरु ही विष्णु, गुरु ही महेश्वर हैं; गुरु साक्षात् परब्रह्म हैं। उन श्रीगुरु को नमस्कार।',
    ),
  ),
  Verse(
    'sarve-bhavantu',
    ['general'],
    ['night'],
    'సర్వే భవంతు సుఖినః సర్వే సంతు నిరామయాః ।\nసర్వే భద్రాణి పశ్యంతు మా కశ్చిద్ దుఃఖభాగ్భవేత్ ॥',
    'सर्वे भवन्तु सुखिनः सर्वे सन्तु निरामयाः ।\nसर्वे भद्राणि पश्यन्तु मा कश्चिद् दुःखभाग्भवेत् ॥',
    'Sarve bhavantu sukhinaḥ sarve santu nirāmayāḥ\nsarve bhadrāṇi paśyantu mā kaścid duḥkhabhāg bhavet',
    (
      'May all be happy, may all be free of illness, may all see what is good, and may no one suffer.',
      'అందరూ సుఖంగా ఉండాలి, అందరూ ఆరోగ్యంగా ఉండాలి, అందరూ శుభాలనే చూడాలి, ఎవరూ దుఃఖపడకూడదు.',
      'सब सुखी हों, सब निरोगी हों, सब मंगल देखें, कोई भी दुःख का भागी न बने।',
    ),
  ),
  Verse(
    'deepa-jyoti',
    ['general', 'lakshmi', 'shiva'],
    ['karthika', 'karthika-pournami', 'diwali', 'night'],
    'శుభం కరోతి కల్యాణమారోగ్యం ధనసంపదః ।\nశత్రుబుద్ధివినాశాయ దీపజ్యోతిర్నమోఽస్తు తే ॥',
    'शुभं करोति कल्याणमारोग्यं धनसम्पदः ।\nशत्रुबुद्धिविनाशाय दीपज्योतिर्नमोऽस्तु ते ॥',
    'Śubhaṁ karoti kalyāṇam ārogyaṁ dhanasampadaḥ\nśatrubuddhivināśāya dīpajyotir namo \'stu te',
    (
      'Lamp light that brings what is good and auspicious, health and wealth, and ends ill will: I bow to you.',
      'శుభాన్ని, కల్యాణాన్ని, ఆరోగ్యాన్ని, ధనసంపదలను ఇచ్చే, శత్రుబుద్ధిని నశింపజేసే దీపజ్యోతికి నమస్కారం.',
      'जो शुभ, कल्याण, आरोग्य और धन-सम्पदा देती है और शत्रुबुद्धि मिटाती है, उस दीपज्योति को नमस्कार।',
    ),
  ),
  Verse(
    'shadananam',
    ['kartikeya'],
    ['tuesday', 'subrahmanya-shashti'],
    'షడాననం కుంకుమరక్తవర్ణం మహామతిం దివ్యమయూరవాహనమ్ ।\nరుద్రస్య సూనుం సురసైన్యనాథం గుహం సదాహం శరణం ప్రపద్యే ॥',
    'षडाननं कुङ्कुमरक्तवर्णं महामतिं दिव्यमयूरवाहनम् ।\nरुद्रस्य सूनुं सुरसैन्यनाथं गुहं सदाहं शरणं प्रपद्ये ॥',
    'Ṣaḍānanaṁ kuṅkumaraktavarṇaṁ mahāmatiṁ divyamayūravāhanam\nrudrasya sūnuṁ surasainyanāthaṁ guhaṁ sadāhaṁ śaraṇaṁ prapadye',
    (
      'Six-faced, red as kumkum, wise, riding the divine peacock, son of Rudra and commander of the gods\' army: I always take refuge in Guha.',
      'ఆరు ముఖాలు, కుంకుమ వంటి ఎర్రని వర్ణం, మహా బుద్ధి గలవాడు, దివ్య మయూర వాహనుడు, రుద్రుని కుమారుడు, దేవసేనాపతి అయిన గుహుని ఎల్లప్పుడూ శరణు వేడుతాను.',
      'छह मुख वाले, कुमकुम जैसे लाल, महाबुद्धिमान, दिव्य मयूर पर सवार, रुद्र-पुत्र, देवसेना के नायक गुह की मैं सदा शरण लेता हूँ।',
    ),
  ),
];

/// The deity of each weekday, Monday first, as Telugu households keep it.
const weekdayDeity = ['shiva', 'hanuman', 'ganesha', 'dattatreya', 'lakshmi', 'venkateswara', 'surya'];

const _weekdayTe = [
  'శుభ సోమవారం',
  'శుభ మంగళవారం',
  'శుభ బుధవారం',
  'శుభ గురువారం',
  'శుభ శుక్రవారం',
  'శుభ శనివారం',
  'శుభ ఆదివారం',
];
const _weekdayHi = [
  'शुभ सोमवार',
  'शुभ मंगलवार',
  'शुभ बुधवार',
  'शुभ गुरुवार',
  'शुभ शुक्रवार',
  'शुभ शनिवार',
  'शुभ रविवार',
];
const _weekdayEn = [
  'A blessed Monday',
  'A blessed Tuesday',
  'A blessed Wednesday',
  'A blessed Thursday',
  'A blessed Friday',
  'A blessed Saturday',
  'A blessed Sunday',
];

/// The chant that closes a status, by deity.
const deityChant = <String, (String, String, String)>{
  'shiva': ('Om Namah Shivaya', 'ఓం నమః శివాయ', 'ॐ नमः शिवाय'),
  'hanuman': ('Jai Hanuman', 'జై హనుమాన్', 'जय हनुमान'),
  'ganesha': ('Om Gam Ganapataye Namah', 'ఓం గం గణపతయే నమః', 'ॐ गं गणपतये नमः'),
  'dattatreya': (
    'Digambara Digambara Shripada Vallabha Digambara',
    'దిగంబర దిగంబర శ్రీపాద వల్లభ దిగంబర',
    'दिगम्बरा दिगम्बरा श्रीपाद वल्लभ दिगम्बरा',
  ),
  'lakshmi': ('Om Shri Mahalakshmyai Namah', 'ఓం శ్రీ మహాలక్ష్మ్యై నమః', 'ॐ श्री महालक्ष्म्यै नमः'),
  'venkateswara': ('Om Namo Venkatesaya', 'ఓం నమో వేంకటేశాయ', 'ॐ नमो वेंकटेशाय'),
  'surya': ('Om Suryaya Namah', 'ఓం సూర్యాయ నమః', 'ॐ सूर्याय नमः'),
  'vishnu': ('Om Namo Narayanaya', 'ఓం నమో నారాయణాయ', 'ॐ नमो नारायणाय'),
  'rama': ('Sri Rama Jayam', 'శ్రీరామ జయం', 'जय श्री राम'),
  'krishna': ('Hare Krishna', 'హరే కృష్ణ', 'हरे कृष्ण'),
  'radha-krishna': ('Radhe Krishna', 'రాధే కృష్ణ', 'राधे कृष्ण'),
  'durga': ('Om Dum Durgayai Namah', 'ఓం దుం దుర్గాయై నమః', 'ॐ दुं दुर्गायै नमः'),
  'kali': ('Jai Maa Kali', 'జై కాళీ మాత', 'जय माँ काली'),
  'saraswati': ('Om Aim Saraswatyai Namah', 'ఓం ఐం సరస్వత్యై నమః', 'ॐ ऐं सरस्वत्यै नमः'),
  'shani': ('Om Shanaishcharaya Namah', 'ఓం శనైశ్చరాయ నమః', 'ॐ शनैश्चराय नमः'),
  'kartikeya': ('Om Sharavanabhavaya Namah', 'ఓం శరవణభవాయ నమః', 'ॐ शरवणभवाय नमः'),
  'general': ('Om Shanti', 'ఓం శాంతి', 'ॐ शान्ति'),
};

const _hiTithi = <String, String>{
  'Pratipada': 'प्रतिपदा',
  'Dwitiya': 'द्वितीया',
  'Tritiya': 'तृतीया',
  'Chaturthi': 'चतुर्थी',
  'Panchami': 'पंचमी',
  'Shashthi': 'षष्ठी',
  'Saptami': 'सप्तमी',
  'Ashtami': 'अष्टमी',
  'Navami': 'नवमी',
  'Dashami': 'दशमी',
  'Ekadashi': 'एकादशी',
  'Dwadashi': 'द्वादशी',
  'Trayodashi': 'त्रयोदशी',
  'Chaturdashi': 'चतुर्दशी',
  'Purnima': 'पूर्णिमा',
  'Amavasya': 'अमावस्या',
};
const _hiMonths = [
  'चैत्र',
  'वैशाख',
  'ज्येष्ठ',
  'आषाढ़',
  'श्रावण',
  'भाद्रपद',
  'आश्विन',
  'कार्तिक',
  'मार्गशीर्ष',
  'पौष',
  'माघ',
  'फाल्गुन',
];
const _enMonths = [
  'Chaitra',
  'Vaishakha',
  'Jyeshtha',
  'Ashadha',
  'Shravana',
  'Bhadrapada',
  'Ashwayuja',
  'Kartika',
  'Margashira',
  'Pushya',
  'Magha',
  'Phalguna',
];

/// Today's Panchang in one short line: "కార్తీక బహుళ చవితి · పునర్వసు". Null without Panchang data.
String? panchangLine(Map? panchang, String lang) {
  if (panchang == null) return null;
  final tithi = panchang['tithi'] as Map?;
  final name = '${tithi?['name'] ?? ''}';
  if (name.isEmpty) return null;
  final shukla = tithi?['paksha'] == 'Shukla';
  final month = (panchang['lunar_month'] as Map?)?['index'];
  final m = month is int && month >= 0 && month < 12 ? month : null;
  final nak = (panchang['nakshatra'] as Map?);
  final nakIndex = nak?['index'];
  switch (lang) {
    case 'te':
      final monthTe = m == null ? '' : '${teluguMonths[m].replaceAll(RegExp(r'ం$'), '')} ';
      final nakTe = nakIndex is int && nakIndex > 0 && nakIndex < teluguNakshatra.length
          ? teluguNakshatra[nakIndex]
          : '';
      final day = '$monthTe${shukla ? 'శుద్ధ' : 'బహుళ'} ${teluguTithi[name] ?? name}';
      return nakTe.isEmpty ? day : '$day · $nakTe';
    case 'hi':
      final day = '${m == null ? '' : '${_hiMonths[m]} '}${shukla ? 'शुक्ल' : 'कृष्ण'} ${_hiTithi[name] ?? name}';
      return day;
    default:
      final day = '${m == null ? '' : '${_enMonths[m]} '}${shukla ? 'Shukla' : 'Krishna'} $name';
      final nakEn = '${nak?['name'] ?? ''}';
      return nakEn.isEmpty ? day : '$day · $nakEn';
  }
}

/// What a status says.
class StatusContent {
  const StatusContent({
    required this.lang,
    required this.deity,
    required this.headline,
    required this.verse,
    required this.meaning,
    required this.chant,
    this.panchang,
    this.signature,
    this.personal,
  });
  final String lang, deity, headline, chant;
  final Verse verse;
  final String meaning;
  final String? panchang, signature;

  /// The Premium personal line (Tarabalam for the sender's birth star), or null.
  final String? personal;
}

/// A festival the status can greet, with its names in English, Telugu and Hindi.
typedef StatusFestival = ({String slug, String deity, String en, String te, String hi});

/// What a status is for. [today] greets the festival or the weekday.
enum StatusOccasion {
  today('Today', 'आज', 'ఈ రోజు'),
  morning('Good morning', 'सुप्रभात', 'శుభోదయం'),
  night('Good night', 'शुभ रात्रि', 'శుభ రాత్రి'),
  birthday('Birthday', 'जन्मदिन', 'పుట్టినరోజు'),
  anniversary('Anniversary', 'सालगिरह', 'పెళ్లిరోజు');

  const StatusOccasion(this.en, this.hi, this.te);
  final String en, hi, te;
  String label(String lang) => switch (lang) {
    'te' => te,
    'hi' => hi,
    _ => en,
  };
}

/// A personal line from the reader's birth star (0-26) and today's nakshatra (the API's 1-27 index):
/// "Today is your Sampat tara: a good day to begin something new." Null without both.
String? personalBlessing({required int? birthStar, required int? todayStar, required String lang, String name = ''}) {
  if (birthStar == null || todayStar == null || todayStar < 1) return null;
  final t = tarabalam(birthStar, todayStar - 1);
  final tara = taraLabel(lang, t.key);
  final who = name.trim();
  final good = t.tara == 2 || t.tara == 4 || t.tara == 6 || t.tara == 8 || t.tara == 9;
  return switch (lang) {
    'te' when good =>
      '${who.isEmpty ? '' : '$who, '}ఈ రోజు మీకు $tara తార: శుభకార్యాలకు, కొత్త ప్రారంభాలకు అనుకూలమైన రోజు.',
    'te' when t.tara == 1 => '${who.isEmpty ? '' : '$who, '}ఈ రోజు మీ జన్మ తార: దైవ స్మరణతో ప్రశాంతంగా సాగండి.',
    'te' => '${who.isEmpty ? '' : '$who, '}ఈ రోజు $tara తార: దైవనామ స్మరణ మీకు రక్ష.',
    'hi' when good =>
      '${who.isEmpty ? '' : '$who, '}आज आपका $tara तारा है: शुभ कार्यों और नई शुरुआत के लिए अनुकूल दिन।',
    'hi' when t.tara == 1 => '${who.isEmpty ? '' : '$who, '}आज आपका जन्म तारा है: ईश्वर स्मरण के साथ शान्ति से चलें।',
    'hi' => '${who.isEmpty ? '' : '$who, '}आज $tara तारा है: भगवान का नाम आपकी रक्षा करेगा।',
    _ when good => '${who.isEmpty ? '' : '$who, '}today is your $tara tara: a good day to begin something new.',
    _ when t.tara == 1 => '${who.isEmpty ? '' : '$who, '}today is your Janma tara: go gently, with God in mind.',
    _ => '${who.isEmpty ? '' : '$who, '}today is $tara tara: let a prayer guard your day.',
  };
}

/// Composes today's status: a greeting for the festival (when one is today) or the weekday, the
/// deity's verse, its meaning, today's Panchang and the sender's name.
///
/// [variant] picks another fitting verse ("Shuffle"); the same inputs always give the same status.
StatusContent composeStatus({
  required String lang,
  required DateTime day,
  String? deity,
  StatusFestival? festival,
  Map? panchang,
  String name = '',
  int variant = 0,
  StatusOccasion occasion = StatusOccasion.today,
  String to = '',
  String? personal,
}) {
  final weekday = day.weekday - 1;
  final chosen = deity ?? festival?.deity ?? weekdayDeity[weekday];
  final weekdayTag = const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'][weekday];
  final tags = switch (occasion) {
    StatusOccasion.today => {weekdayTag, ?festival?.slug, if (day.hour < 12) 'morning', if (day.hour >= 19) 'night'},
    StatusOccasion.morning => {'morning'},
    StatusOccasion.night => {'night'},
    StatusOccasion.birthday => {'birthday'},
    StatusOccasion.anniversary => {'anniversary'},
  };
  // On Today the deity leads; for an occasion (birthday, good night) the occasion's verses do.
  final tagWeight = occasion == StatusOccasion.today ? 2 : 8;
  int score(Verse v) =>
      (v.deities.contains(chosen) ? 4 : 0) +
      v.tags.where(tags.contains).length * tagWeight +
      (v.deities.contains('general') ? 1 : 0);
  final ranked = [...verses]..sort((a, b) => score(b).compareTo(score(a)));
  final floor = occasion == StatusOccasion.today ? (ranked.first.deities.contains(chosen) ? 4 : 1) : tagWeight;
  final fitting = ranked.where((v) => score(v) >= floor).toList();
  final pool = fitting.isEmpty ? ranked.take(3).toList() : fitting;
  final verse = pool[variant.abs() % pool.length];

  final recipient = to.trim();
  final headline =
      switch (occasion) {
        StatusOccasion.morning => t3s(lang, 'Good morning', 'सुप्रभात', 'శుభోదయం'),
        StatusOccasion.night => t3s(lang, 'Good night', 'शुभ रात्रि', 'శుభ రాత్రి'),
        StatusOccasion.birthday =>
          recipient.isEmpty
              ? t3s(lang, 'Happy Birthday', 'जन्मदिन की\nशुभकामनाएँ', 'జన్మదిన\nశుభాకాంక్షలు')
              : t3s(
                  lang,
                  'Happy Birthday,\n$recipient',
                  '$recipient को जन्मदिन की\nशुभकामनाएँ',
                  '$recipientకి జన్మదిన\nశుభాకాంక్షలు',
                ),
        StatusOccasion.anniversary =>
          recipient.isEmpty
              ? t3s(lang, 'Happy Anniversary', 'विवाह वर्षगाँठ की\nशुभकामनाएँ', 'పెళ్లిరోజు\nశుభాకాంక్షలు')
              : t3s(
                  lang,
                  'Happy Anniversary,\n$recipient',
                  '$recipient को सालगिरह की\nशुभकामनाएँ',
                  '$recipientకి పెళ్లిరోజు\nశుభాకాంక్షలు',
                ),
        StatusOccasion.today => null,
      } ??
      (festival != null
          ? switch (lang) {
              'te' => '${festival.te}\nశుభాకాంక్షలు',
              'hi' => '${festival.hi} की\nशुभकामनाएँ',
              _ => 'Happy ${festival.en}',
            }
          : switch (lang) {
              'te' => _weekdayTe[weekday],
              'hi' => _weekdayHi[weekday],
              _ => _weekdayEn[weekday],
            });
  final chant = deityChant[chosen] ?? deityChant['general']!;
  final trimmed = name.trim();
  return StatusContent(
    lang: lang,
    deity: chosen,
    headline: headline,
    verse: verse,
    meaning: verse.meaningIn(lang),
    chant: switch (lang) {
      'te' => chant.$2,
      'hi' => chant.$3,
      _ => chant.$1,
    },
    panchang: panchangLine(panchang, lang),
    signature: trimmed.isEmpty ? null : '— $trimmed',
    personal: personal,
  );
}

String t3s(String lang, String en, String hi, String te) => switch (lang) {
  'te' => te,
  'hi' => hi,
  _ => en,
};
