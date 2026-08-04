import 'package:flutter_test/flutter_test.dart';
import 'package:ringer_app/constants/club_logos.dart';

void main() {
  test('finds logos by LigaDB organisation ID', () {
    expect(ClubLogos.forOrganisation(165), ClubLogos.kscOlympiaGrabenNeudorf);
    expect(ClubLogos.forOrganisation(694), ClubLogos.rkgReilingenHockenheim);
    expect(ClubLogos.forOrganisation(999999), ClubLogos.defaultLogo);
  });

  test('normalizes LigaDB club name variants', () {
    expect(
      ClubLogos.forClub('  SVG Nieder-Liebersbach  '),
      ClubLogos.svgNiederLiebersbach,
    );
    expect(
      ClubLogos.forClub('Falken Bergstraße II'),
      ClubLogos.falkenBergstrasse,
    );
    expect(
      ClubLogos.forClub('RG  Ladenburg -Rohrbach III'),
      ClubLogos.rgLadenburgRohrbach,
    );
  });

  test('falls back to organisation ID and default logo', () {
    expect(
      ClubLogos.forClub('Unbekannter Name', organisationId: 172),
      ClubLogos.ksvIspringen,
    );
    expect(ClubLogos.forClub('Unbekannter Verein'), ClubLogos.defaultLogo);
  });
}
