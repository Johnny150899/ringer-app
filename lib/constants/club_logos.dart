class ClubLogos {
  ClubLogos._();

  static const String defaultLogo = 'assets/logos/default.png';
  static const String kscOlympiaGrabenNeudorf = 'assets/logos/165.png';

  static const Map<String, String> _byClubName = {
    'ksc olympia': kscOlympiaGrabenNeudorf,
    'ksc olympia graben-neudorf': kscOlympiaGrabenNeudorf,
  };

  static String forClub(String clubName) {
    return _byClubName[clubName.trim().toLowerCase()] ?? defaultLogo;
  }
}
