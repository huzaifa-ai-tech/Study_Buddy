import 'package:flutter/material.dart';

import 'data/models/ai_settings.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/materials/presentation/materials_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

/// App shell with bottom navigation.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onSeeAll: () => setState(() => _index = 1)),
      const MaterialsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books_rounded),
            label: 'Materials',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Convenience: whether AI is configured, read from the settings notifier.
class AiStatusBanner extends StatelessWidget {
  const AiStatusBanner({super.key, required this.settings});

  final AiSettings settings;

  @override
  Widget build(BuildContext context) {
    if (settings.isConfigured) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.key_rounded,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Add your AI API key in Settings to unlock summaries, '
              'flashcards, quizzes and study plans.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}