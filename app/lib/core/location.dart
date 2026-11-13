import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage.dart';
import '../l10n/l10n.dart';
import 'telugu.dart';

/// Panchang timings depend on location. Users pick the nearest city instead of
/// granting GPS access, which keeps the app free of location permissions.
class City {
  const City(this.id, this.name, this.nameHi, this.lat, this.lon, this.tz);
  final String id;
  final String name;
  final String nameHi;
  final double lat;
  final double lon;
  final String tz;

  Map<String, String> get query => {'lat': '$lat', 'lon': '$lon', 'tz': tz};

  String label(String lang) => switch (lang) {
    'hi' => nameHi,
    'te' => teluguCities[id] ?? name,
    _ => translate(lang, name) ?? name,
  };
}

const cities = <City>[
  City('delhi', 'New Delhi', 'नई दिल्ली', 28.61, 77.21, 'Asia/Kolkata'),
  City('mumbai', 'Mumbai', 'मुंबई', 19.08, 72.88, 'Asia/Kolkata'),
  City('kolkata', 'Kolkata', 'कोलकाता', 22.57, 88.36, 'Asia/Kolkata'),
  City('chennai', 'Chennai', 'चेन्नई', 13.08, 80.27, 'Asia/Kolkata'),
  City('bengaluru', 'Bengaluru', 'बेंगलुरु', 12.97, 77.59, 'Asia/Kolkata'),
  City('hyderabad', 'Hyderabad', 'हैदराबाद', 17.39, 78.49, 'Asia/Kolkata'),
  City('vijayawada', 'Vijayawada', 'विजयवाड़ा', 16.51, 80.65, 'Asia/Kolkata'),
  City('visakhapatnam', 'Visakhapatnam', 'विशाखापत्तनम', 17.69, 83.22, 'Asia/Kolkata'),
  City('tirupati', 'Tirupati', 'तिरुपति', 13.63, 79.42, 'Asia/Kolkata'),
  City('guntur', 'Guntur', 'गुंटूर', 16.31, 80.44, 'Asia/Kolkata'),
  City('warangal', 'Warangal', 'वारंगल', 17.97, 79.59, 'Asia/Kolkata'),
  City('nellore', 'Nellore', 'नेल्लोर', 14.44, 79.99, 'Asia/Kolkata'),
  City('kurnool', 'Kurnool', 'कुर्नूल', 15.83, 78.04, 'Asia/Kolkata'),
  City('rajahmundry', 'Rajahmundry', 'राजमुंदरी', 17.00, 81.80, 'Asia/Kolkata'),
  City('kakinada', 'Kakinada', 'काकीनाडा', 16.99, 82.25, 'Asia/Kolkata'),
  City('karimnagar', 'Karimnagar', 'करीमनगर', 18.44, 79.13, 'Asia/Kolkata'),
  City('khammam', 'Khammam', 'खम्मम', 17.25, 80.15, 'Asia/Kolkata'),
  City('nizamabad', 'Nizamabad', 'निज़ामाबाद', 18.67, 78.09, 'Asia/Kolkata'),
  City('anantapur', 'Anantapur', 'अनंतपुर', 14.68, 77.60, 'Asia/Kolkata'),
  City('kadapa', 'Kadapa', 'कडपा', 14.47, 78.82, 'Asia/Kolkata'),
  City('srikakulam', 'Srikakulam', 'श्रीकाकुलम', 18.30, 83.90, 'Asia/Kolkata'),
  City('ongole', 'Ongole', 'ओंगोल', 15.50, 80.05, 'Asia/Kolkata'),
  City('eluru', 'Eluru', 'एलुरु', 16.71, 81.10, 'Asia/Kolkata'),
  City('srisailam', 'Srisailam', 'श्रीशैलम', 16.07, 78.87, 'Asia/Kolkata'),
  City('bhadrachalam', 'Bhadrachalam', 'भद्राचलम', 17.67, 80.89, 'Asia/Kolkata'),
  City('ahmedabad', 'Ahmedabad', 'अहमदाबाद', 23.02, 72.57, 'Asia/Kolkata'),
  City('pune', 'Pune', 'पुणे', 18.52, 73.86, 'Asia/Kolkata'),
  City('jaipur', 'Jaipur', 'जयपुर', 26.91, 75.79, 'Asia/Kolkata'),
  City('lucknow', 'Lucknow', 'लखनऊ', 26.85, 80.95, 'Asia/Kolkata'),
  City('patna', 'Patna', 'पटना', 25.59, 85.14, 'Asia/Kolkata'),
  City('bhopal', 'Bhopal', 'भोपाल', 23.26, 77.41, 'Asia/Kolkata'),
  City('varanasi', 'Varanasi', 'वाराणसी', 25.32, 82.97, 'Asia/Kolkata'),
  City('ayodhya', 'Ayodhya', 'अयोध्या', 26.80, 82.20, 'Asia/Kolkata'),
  City('ujjain', 'Ujjain', 'उज्जैन', 23.18, 75.78, 'Asia/Kolkata'),
  City('haridwar', 'Haridwar', 'हरिद्वार', 29.95, 78.16, 'Asia/Kolkata'),
  City('mathura', 'Mathura', 'मथुरा', 27.49, 77.67, 'Asia/Kolkata'),
  City('puri', 'Puri', 'पुरी', 19.81, 85.83, 'Asia/Kolkata'),
  City('guwahati', 'Guwahati', 'गुवाहाटी', 26.14, 91.74, 'Asia/Kolkata'),
  City('kochi', 'Kochi', 'कोच्चि', 9.93, 76.27, 'Asia/Kolkata'),
  City('kathmandu', 'Kathmandu', 'काठमांडू', 27.72, 85.32, 'Asia/Kathmandu'),
  City('dubai', 'Dubai', 'दुबई', 25.20, 55.27, 'Asia/Dubai'),
  City('singapore', 'Singapore', 'सिंगापुर', 1.35, 103.82, 'Asia/Singapore'),
  City('london', 'London', 'लंदन', 51.51, -0.13, 'Europe/London'),
  City('new-york', 'New York', 'न्यूयॉर्क', 40.71, -74.01, 'America/New_York'),
  City('toronto', 'Toronto', 'टोरंटो', 43.65, -79.38, 'America/Toronto'),
  City('san-francisco', 'San Francisco', 'सैन फ़्रांसिस्को', 37.77, -122.42, 'America/Los_Angeles'),
  City('sydney', 'Sydney', 'सिडनी', -33.87, 151.21, 'Australia/Sydney'),
];

final cityProvider = Provider<City>((ref) {
  final id = ref.watch(prefsProvider.select((p) => p.cityId));
  return cities.firstWhere((c) => c.id == id, orElse: () => cities.first);
});
