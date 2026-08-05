class ClubLogos {
  ClubLogos._();

  static final RegExp _spacesAroundDash = RegExp(r'\s*-\s*');
  static final RegExp _multipleSpaces = RegExp(r'\s+');

  static const String defaultLogo = 'assets/logos/default.png';

  // LigaDB OrganisationsIDs bleiben im Gegensatz zu TeamIDs über
  // Mannschaften und Saisons hinweg stabil und eignen sich daher für Logos.
  static const String asvBruchsal = 'assets/logos/163.png';
  static const String kscOlympiaGrabenNeudorf = 'assets/logos/165.png';
  static const String acZiegelhausen = 'assets/logos/169.png';
  static const String ksvHemsbach = 'assets/logos/170.png';
  static const String ksvIspringen = 'assets/logos/172.png';
  static const String rgLadenburgRohrbach = 'assets/logos/177.png';
  static const String rscEicheSandhofen = 'assets/logos/181.png';
  static const String svgNiederLiebersbach = 'assets/logos/183.png';
  static const String svgWeingarten = 'assets/logos/195.png';
  static const String rkgReilingenHockenheim = 'assets/logos/694.png';
  static const String falkenBergstrasse = 'assets/logos/2312.png';

  static const Map<int, String> _byOrganisationId = {
    163: asvBruchsal,
    165: kscOlympiaGrabenNeudorf,
    169: acZiegelhausen,
    170: ksvHemsbach,
    172: ksvIspringen,
    177: rgLadenburgRohrbach,
    181: rscEicheSandhofen,
    183: svgNiederLiebersbach,
    195: svgWeingarten,
    694: rkgReilingenHockenheim,
    2312: falkenBergstrasse,
  };

  static const Map<String, String> _byClubName = {
    'asv bruchsal ii': asvBruchsal,
    'ksc olympia': kscOlympiaGrabenNeudorf,
    'ksc olympia graben-neudorf': kscOlympiaGrabenNeudorf,
    'ksc graben-neudorf ii': kscOlympiaGrabenNeudorf,
    'ac ziegelhausen': acZiegelhausen,
    'ac ziegelhausen ii': acZiegelhausen,
    'ksv hemsbach ii': ksvHemsbach,
    'ksv ispringen': ksvIspringen,
    'rg ladenburg-rohrbach': rgLadenburgRohrbach,
    'rg ladenburg-rohrbach iii': rgLadenburgRohrbach,
    'rsc eiche sandhofen ii': rscEicheSandhofen,
    'svg nieder-liebersbach': svgNiederLiebersbach,
    'svg 04 weingarten ii': svgWeingarten,
    'rkg reilingen-hockenheim ii': rkgReilingenHockenheim,
    'falken bergstrasse': falkenBergstrasse,
    'falken bergstrasse ii': falkenBergstrasse,
  };

  static String forClub(String clubName, {int? organisationId}) {
    return _byClubName[_normalize(clubName)] ??
        _byOrganisationId[organisationId] ??
        defaultLogo;
  }

  static String forOrganisation(int? organisationId) {
    return _byOrganisationId[organisationId] ?? defaultLogo;
  }

  static String _normalize(String clubName) {
    return clubName
        .trim()
        .toLowerCase()
        .replaceAll('ß', 'ss')
        .replaceAll(_spacesAroundDash, '-')
        .replaceAll(_multipleSpaces, ' ');
  }
}
