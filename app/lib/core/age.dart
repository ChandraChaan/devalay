/// Ages from a date of birth, for "About you" (about_you.dart) and the owner's statistics (admin_stats.dart).
library;

/// Age groups for the owner's statistics and push targeting. Under 18 is its own group: those profiles are
/// never used for advertising.
const ageGroups = ['under18', '18-24', '25-34', '35-44', '45-54', '55-64', '65+'];

/// Whole years on [today], or null for a birth date in the future.
int? ageOn(DateTime dob, DateTime today) {
  if (dob.isAfter(today)) return null;
  var age = today.year - dob.year;
  if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) age--;
  return age;
}

String? ageGroupFor(DateTime dob, DateTime today) {
  final a = ageOn(dob, today);
  if (a == null) return null;
  if (a < 18) return 'under18';
  if (a < 25) return '18-24';
  if (a < 35) return '25-34';
  if (a < 45) return '35-44';
  if (a < 55) return '45-54';
  if (a < 65) return '55-64';
  return '65+';
}
