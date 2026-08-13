import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:study_buddy/data/database/app_database.dart';
import 'package:study_buddy/data/models/ai_settings.dart';
import 'package:study_buddy/data/models/flashcard.dart';
import 'package:study_buddy/data/models/quiz_question.dart';
import 'package:study_buddy/data/models/study_material.dart';
import 'package:study_buddy/data/models/study_plan.dart';
import 'package:study_buddy/data/repositories/study_repository.dart';
import 'package:study_buddy/data/services/ai_service.dart';
import 'package:study_buddy/features/flashcards/state/flashcard_session_bloc.dart';
import 'package:study_buddy/features/generator/state/generator_bloc.dart';
import 'package:study_buddy/features/materials/state/material_bloc.dart';
import 'package:study_buddy/features/quiz/state/quiz_session_bloc.dart';
import 'package:study_buddy/features/settings/state/settings_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

var _dbCounter = 0;

Future<StudyRepository> inMemoryRepository() async {
  final path =
      p.join(Directory.systemTemp.path, 'study_buddy_test_${_dbCounter++}.db');
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: AppDatabase.onCreate,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
  return StudyRepository(database: db);
}

class FakeAiService implements AiService {
  @override
  Future<String> generateSummary(String title, String content) async =>
      'A short summary of $title.';

  @override
  Future<List<FlashcardGeneration>> generateFlashcards(
    String title,
    String content, {
    int count = 12,
  }) async =>
      [FlashcardGeneration(front: 'Q', back: 'A')];

  @override
  Future<List<QuizQuestion>> generateQuiz(
    String title,
    String content, {
    int count = 8,
  }) async => [
        QuizQuestion(
          materialId: 0,
          question: 'What is 2+2?',
          options: const ['3', '4', '5'],
          correctIndex: 1,
        ),
      ];

  @override
  Future<StudyPlan> generateStudyPlan(String title, String content) async =>
      StudyPlan(
        materialId: 0,
        title: 'Plan',
        items: const [
          PlanItem(topic: 'Intro', durationMinutes: 20, activities: ['Read'])
        ],
      );

  @override
  Future<String> chatWithNotes(
    String title,
    String content,
    List<({String role, String text})> history,
    String question,
  ) async =>
      'Answer about $title.';
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('FlashcardSessionBloc', () {
    test('walks through cards and finishes', () async {
      final repository = await inMemoryRepository();
      final bloc = FlashcardSessionBloc(repository: repository);
      bloc.add(SessionStarted(const [
        Flashcard(materialId: 1, front: 'A', back: 'B'),
        Flashcard(materialId: 1, front: 'C', back: 'D'),
      ]));
      await bloc.stream.first;
      expect(bloc.state.total, 2);
      expect(bloc.state.index, 0);

      bloc.add(const CardFlipped());
      await bloc.stream.first;
      expect(bloc.state.isFlipped, isTrue);

      bloc.add(const CardRated(true));
      await bloc.stream.first;
      expect(bloc.state.index, 1);

      bloc.add(const CardRated(false));
      await bloc.stream.first;
      expect(bloc.state.isFinished, isTrue);
      expect(bloc.state.knownCount, 1);

      bloc.add(SessionRestarted());
      await bloc.stream.first;
      expect(bloc.state.isFinished, isFalse);
      expect(bloc.state.index, 0);
    });
  });

  group('QuizSessionBloc', () {
    test('scores answers and persists the result', () async {
      final repository = await inMemoryRepository();
      final materialId =
          await repository.insertMaterial(StudyMaterial(title: 'T', content: 'C'));
      final bloc = QuizSessionBloc(repository: repository);

      bloc.add(QuizStarted(const [
        QuizQuestion(
          materialId: 1,
          question: 'Q1',
          options: ['a', 'b'],
          correctIndex: 0,
        ),
        QuizQuestion(
          materialId: 1,
          question: 'Q2',
          options: ['a', 'b'],
          correctIndex: 1,
        ),
      ], materialId));
      await bloc.stream.first;
      expect(bloc.state.total, 2);

      bloc.add(AnswerSelected(0, 0));
      await bloc.stream.first;
      expect(bloc.state.answered, isTrue);

      bloc.add(const QuizNext());
      await bloc.stream.first;
      expect(bloc.state.currentIndex, 1);

      bloc.add(AnswerSelected(1, 0));
      await bloc.stream.first;

      bloc.add(const QuizNext());
      await bloc.stream.first;
      expect(bloc.state.finished, isTrue);

      final results = await repository.getQuizResults(materialId: materialId);
      expect(results, hasLength(1));
      expect(results.first.correct, 1);
      expect(results.first.total, 2);
    });
  });

  group('MaterialBloc', () {
    test('adds, lists and deletes materials', () async {
      final repository = await inMemoryRepository();
      final bloc = MaterialBloc(repository: repository)
        ..add(const MaterialsLoaded());
      await bloc.stream.firstWhere((s) => s.status == MaterialStatus.success);

      bloc.add(MaterialAdded(StudyMaterial(title: 'ML', content: 'notes')));
      await bloc.stream
          .firstWhere((s) => s.materials.any((m) => m.title == 'ML'));

      expect(bloc.state.materials, hasLength(1));

      bloc.add(MaterialDeleted(bloc.state.materials.first.id!));
      await bloc.stream.firstWhere((s) => s.materials.isEmpty);

      expect(bloc.state.materials, isEmpty);
    });
  });

  group('GeneratorBloc', () {
    test('generates and persists flashcards', () async {
      final repository = await inMemoryRepository();
      final materialId =
          await repository.insertMaterial(StudyMaterial(title: 'T', content: 'C'));
      final material = await repository.getMaterial(materialId);
      final bloc = GeneratorBloc(
        repository: repository,
        settingsNotifier: ValueNotifier(const AiSettings(apiKey: 'test')),
        overrideService: FakeAiService(),
      );

      bloc.add(GenerateFlashcards(material!));
      await bloc.stream.firstWhere(
          (s) => s.active == GenerationType.none && s.flashcards.isNotEmpty);

      final cards = await repository.getFlashcards(materialId);
      expect(cards, hasLength(1));
      expect(cards.first.front, 'Q');
      expect(cards.first.back, 'A');
    });

    test('reports failure when AI throws', () async {
      final repository = await inMemoryRepository();
      final material = await repository.insertMaterial(
          StudyMaterial(title: 'T', content: 'C'));
      final bloc = GeneratorBloc(
        repository: repository,
        settingsNotifier: ValueNotifier(const AiSettings(apiKey: 'test')),
        overrideService: _ThrowingAiService(),
      );

      bloc.add(GenerateSummary((await repository.getMaterial(material))!));
      await bloc.stream
          .firstWhere((s) => s.errorMessage != null && s.errorMessage!.isNotEmpty);

      expect(bloc.state.errorMessage, 'boom');
      expect(bloc.state.isBusy, isFalse);
    });
  });

  group('SettingsBloc', () {
    test('loads and saves settings via shared_preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ValueNotifier(const AiSettings());
      final bloc = SettingsBloc(settingsNotifier: notifier)
        ..add(const SettingsLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      bloc.add(const SettingsSaved(
          AiSettings(apiKey: 'sk-1', baseUrl: 'https://x/v1', model: 'm')));
      await bloc.stream.firstWhere((s) => s.settings.apiKey == 'sk-1');

      expect(bloc.state.settings.apiKey, 'sk-1');
      expect(notifier.value.apiKey, 'sk-1');

      final loaded = await AiSettings.load();
      expect(loaded.apiKey, 'sk-1');
      expect(loaded.model, 'm');
    });
  });
}

class _ThrowingAiService implements AiService {
  @override
  Future<String> generateSummary(String title, String content) async {
    throw const AiException('boom');
  }

  @override
  Future<List<FlashcardGeneration>> generateFlashcards(
    String title,
    String content, {
    int count = 12,
  }) async {
    throw const AiException('boom');
  }

  @override
  Future<List<QuizQuestion>> generateQuiz(
    String title,
    String content, {
    int count = 8,
  }) async {
    throw const AiException('boom');
  }

  @override
  Future<StudyPlan> generateStudyPlan(String title, String content) async {
    throw const AiException('boom');
  }

  @override
  Future<String> chatWithNotes(
    String title,
    String content,
    List<({String role, String text})> history,
    String question,
  ) async {
    throw const AiException('boom');
  }
}