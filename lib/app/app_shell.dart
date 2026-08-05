import 'package:flutter/material.dart';

import '../core/constants/club_logos.dart';
import '../features/livestream/presentation/screens/livestream_screen.dart';
import '../features/matches/presentation/screens/home_screen.dart';
import '../features/news/presentation/screens/news_screen.dart';
import '../features/team/presentation/screens/team_screen.dart';
import '../features/training/presentation/screens/training_screen.dart';
import 'app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    TrainingScreen(),
    NewsScreen(),
    TeamScreen(),
    LivestreamScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _AppHeader(),
              Expanded(
                child: IndexedStack(index: _selectedIndex, children: _screens),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Training',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article_rounded),
            label: 'News',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv_rounded),
            label: 'Live',
          ),
        ],
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      decoration: const BoxDecoration(
        color: Color(0x10000000),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            ClubLogos.kscOlympiaGrabenNeudorf,
            width: 42,
            height: 42,
            fit: BoxFit.contain,
          ),
          const CircleAvatar(
            radius: 19,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, size: 21, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
