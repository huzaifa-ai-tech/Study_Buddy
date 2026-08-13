import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_shell.dart';
import 'core/theme/app_theme.dart';
import 'data/models/ai_settings.dart';
import 'data/repositories/study_repository.dart';
import 'features/flashcards/state/flashcard_session_bloc.dart';
import 'features/generator/state/generator_bloc.dart';
import 'features/materials/state/material_bloc.dart';
import 'features/quiz/state/quiz_session_bloc.dart';
import 'features/settings/state/settings_bloc.dart';

/// Application root: theme, repositories and bloc wiring.
class StudyBuddyApp extends StatefulWidget {
  const StudyBuddyApp({super.key, required this.repository});

  final StudyRepository repository;

  @override
  State<StudyBuddyApp> createState() => _StudyBuddyAppState();
}

class _StudyBuddyAppState extends State<StudyBuddyApp> {
  late final ValueNotifier<AiSettings> _settingsNotifier;

  @override
  void initState() {
    super.initState();
    _settingsNotifier = ValueNotifier<AiSettings>(const AiSettings());
  }

  @override
  void dispose() {
    _settingsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.repository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => SettingsBloc(
              settingsNotifier: _settingsNotifier,
            )..add(const SettingsLoaded()),
          ),
          BlocProvider(
            create: (context) =>
                MaterialBloc(repository: widget.repository)
                  ..add(const MaterialsLoaded()),
          ),
          BlocProvider(
            create: (context) => GeneratorBloc(
              repository: widget.repository,
              settingsNotifier: _settingsNotifier,
            ),
          ),
          BlocProvider(
            create: (context) => FlashcardSessionBloc(
              repository: context.read<StudyRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => QuizSessionBloc(repository: widget.repository),
          ),
        ],
        child: ValueListenableBuilder<AiSettings>(
          valueListenable: _settingsNotifier,
          builder: (context, settings, _) {
            return MaterialApp(
              title: 'StudyBuddy',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: switch (settings.themeMode) {
                'light' => ThemeMode.light,
                'dark' => ThemeMode.dark,
                _ => ThemeMode.system,
              },
              home: const AppShell(),
            );
          },
        ),
      ),
    );
  }
}