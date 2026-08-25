import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
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
          child: InkWell(
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}. Mannschaft',
                style: TextStyle(
                  color: selected ? AppColors.navy : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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
                child: InkWell(
                  onTap: () => onSelected(season),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$season',
                      style: TextStyle(
                        color: selected ? AppColors.navy : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
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
