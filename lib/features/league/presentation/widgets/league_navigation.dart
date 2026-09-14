import 'package:flutter/material.dart';

import '../../../../core/widgets/app_glass_surface.dart';

class LeagueTeamSwitcher extends StatelessWidget {
  const LeagueTeamSwitcher({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    borderRadius: 15,
    padding: const EdgeInsets.all(3),
    child: Row(
      children: List.generate(2, (index) {
        final selected = index == selectedIndex;
        return Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x2600142B),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '${index + 1}. Mannschaft',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? const Color(0xFF061E39) : Colors.white70,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );
}

class LeagueSeasonSwitcher extends StatelessWidget {
  const LeagueSeasonSwitcher({
    super.key,
    required this.seasons,
    required this.selectedSeason,
    required this.onSelected,
  });

  final List<int> seasons;
  final int selectedSeason;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = seasons.take(4).toList(growable: false);
    return AppGlassSurface(
      borderRadius: 15,
      padding: const EdgeInsets.all(3),
      child: Row(
        children: visible
            .map((season) {
              final selected = season == selectedSeason;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  child: InkWell(
                    onTap: () => onSelected(season),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  color: Color(0x2600142B),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        '$season',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF061E39)
                              : Colors.white70,
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}
