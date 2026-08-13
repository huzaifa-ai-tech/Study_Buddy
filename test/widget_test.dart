import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:study_buddy/app_shell.dart';
import 'package:study_buddy/core/theme/app_theme.dart';
import 'package:study_buddy/data/database/app_database.dart';
import 'package:study_buddy/data/models/ai_settings.dart';
import 'package:study_buddy/data/repositories/study_repository.dart';
import 'package:study_buddy/features/flashcards/state/flashcard_session_bloc.dart';
import 'package:study_buddy/features/generator/state/generator_bloc.dart';
import 'package:study_buddy/features/materials/state/material_bloc.dart';
import 'package:study_buddy/features/quiz/state/quiz_session_bloc.dart';
import 'package:study_buddy/features/settings/state/settings_bloc.dart';

var _dbCounter = 0;

void main() {
  late StudyRepository repository;
  late MaterialBloc materialBloc;
  late SettingsBloc settingsBloc;
  late ValueNotifier<AiSettings> settingsNotifier;

  setUp(() async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    final path = p.join(
        Directory.systemTemp.path, 'study_buddy_test_w${_dbCounter++}.db');
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: AppDatabase.onCreate,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    repository = StudyRepository(database: db);

    materialBloc = MaterialBloc(repository: repository)
      ..add(const MaterialsLoaded());
    await materialBloc.stream
        .firstWhere((s) => s.status == MaterialStatus.success);

    settingsNotifier = ValueNotifier(const AiSettings());
    settingsBloc = SettingsBloc(settingsNotifier: settingsNotifier)
      ..add(const SettingsLoaded());
    await settingsBloc.stream.firstWhere((s) => !s.isLoading);
  });

  Widget buildApp() {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: repository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settingsBloc),
          BlocProvider.value(value: materialBloc),
          BlocProvider(
            create: (_) => GeneratorBloc(
              repository: repository,
              settingsNotifier: settingsNotifier,
            ),
          ),
          BlocProvider(create: (_) => FlashcardSessionBloc(repository: repository)),
          BlocProvider(
            create: (_) => QuizSessionBloc(repository: repository),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AppShell(),
        ),
      ),
    );
  }

  testWidgets('app boots and shows home', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('StudyBuddy'), findsOneWidget);
    expect(find.text('Start learning'), findsOneWidget);
    final navBar = find.byType(NavigationBar);
    expect(
      find.descendant(of: navBar, matching: find.text('Home')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('Materials')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('Settings')),
      findsOneWidget,
    );
  });

  testWidgets('navigates to the materials tab', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Materials'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No materials yet'), findsOneWidget);
  });
}