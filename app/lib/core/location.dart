import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage.dart';

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
}

const cities = <City>[
  City('delhi', 'New Delhi', 'नई दिल्ली', 28.61, 77.21, 'Asia/Kolkata'),
  City('mumbai', 'Mumbai', 'मुंबई', 19.08, 72.88, 'Asia/Kolkata'),
  City('kolkata', 'Kolkata', 'कोलकाता', 22.57, 88.36, 'Asia/Kolkata'),
  City('chennai', 'Chennai', 'चेन्नई', 13.08, 80.27, 'Asia/Kolkata'),
  City('bengaluru', 'Bengaluru', 'बेंगलुरु', 12.97, 77.59, 'Asia/Kolkata'),
  City('hyderabad', 'Hyderabad', 'हैदराबाद', 17.39, 78.49, 'Asia/Kolkata'),
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
