import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/ai_settings.dart';
import '../../../data/models/flashcard.dart';
import '../../../data/models/quiz_question.dart';
import '../../../data/models/study_material.dart';
import '../../../data/models/study_plan.dart';
import '../../../data/repositories/study_repository.dart';
import '../../../data/services/ai_service.dart';

class GeneratorEvent extends Equatable {
  const GeneratorEvent();

  @override
  List<Object?> get props => [];
}

class GenerateSummary extends GeneratorEvent {
  const GenerateSummary(this.material);

  final StudyMaterial material;

  @override
  List<Object?> get props => [material];
}

class GenerateFlashcards extends GeneratorEvent {
  const GenerateFlashcards(this.material, {this.count = 12});

  final StudyMaterial material;
  final int count;

  @override
  List<Object?> get props => [material, count];
}

class GenerateQuiz extends GeneratorEvent {
  const GenerateQuiz(this.material, {this.count = 8});

  final StudyMaterial material;
  final int count;

  @override
  List<Object?> get props => [material, count];
}

class GeneratePlan extends GeneratorEvent {
  const GeneratePlan(this.material);

  final StudyMaterial material;

  @override
  List<Object?> get props => [material];
}

enum GenerationType { none, summary, flashcards, quiz, plan }

class GeneratorState extends Equatable {
  const GeneratorState({
    this.active = GenerationType.none,
    this.errorMessage,
    this.summary,
    this.flashcards = const [],
    this.questions = const [],
    this.plan,
  });

  final GenerationType active;
  final String? errorMessage;
  final String? summary;
  final List<Flashcard> flashcards;
  final List<QuizQuestion> questions;
  final StudyPlan? plan;

  bool get isBusy => active != GenerationType.none;

  GeneratorState copyWith({
    GenerationType? active,
    String? Function()? errorMessage,
    String? Function()? summary,
    List<Flashcard>? flashcards,
    List<QuizQuestion>? questions,
    StudyPlan? Function()? plan,
  }) {
    return GeneratorState(
      active: active ?? this.active,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      summary: summary != null ? summary() : this.summary,
      flashcards: flashcards ?? this.flashcards,
      questions: questions ?? this.questions,
      plan: plan != null ? plan() : this.plan,
    );
  }

  @override
  List<Object?> get props =>
      [active, errorMessage, summary, flashcards, questions, plan];
}

/// Generates AI study content (summaries, flashcards, quizzes, plans) and
/// persists the results.
class GeneratorBloc extends Bloc<GeneratorEvent, GeneratorState> {
  GeneratorBloc({
    required StudyRepository repository,
    required ValueNotifier<AiSettings> settingsNotifier,
    AiService? overrideService,
  })  :
        // ignore: prefer_initializing_formals
        _repository = repository,
        // ignore: prefer_initializing_formals
        _settingsNotifier = settingsNotifier,
        // ignore: prefer_initializing_formals
        _overrideService = overrideService,
        super(const GeneratorState()) {
    on<GenerateSummary>(_onSummary);
    on<GenerateFlashcards>(_onFlashcards);
    on<GenerateQuiz>(_onQuiz);
    on<GeneratePlan>(_onPlan);
  }

  final StudyRepository _repository;
  final ValueNotifier<AiSettings> _settingsNotifier;
  final AiService? _overrideService;

  AiService get _service =>
      _overrideService ?? OpenAiService(_settingsNotifier.value);

  Future<void> _onSummary(
    GenerateSummary event,
    Emitter<GeneratorState> emit,
  ) async {
    emit(state.copyWith(
      active: GenerationType.summary,
      errorMessage: () => null,
    ));
    try {
      final summary = await _service.generateSummary(
        event.material.title,
        event.material.content,
      );
      final updated = event.material.copyWith(summary: () => summary);
      await _repository.updateMaterial(updated);
      emit(state.copyWith(
        active: GenerationType.none,
        summary: () => summary,
      ));
    } catch (e) {
      emit(state.copyWith(
        active: GenerationType.none,
        errorMessage: () => _message(e),
      ));
    }
  }

  Future<void> _onFlashcards(
    GenerateFlashcards event,
    Emitter<GeneratorState> emit,
  ) async {
    emit(state.copyWith(
      active: GenerationType.flashcards,
      errorMessage: () => null,
    ));
    try {
      final generated = await _service.generateFlashcards(
        event.material.title,
        event.material.content,
        count: event.count,
      );
      final cards = generated
          .map((g) => Flashcard(
                materialId: event.material.id!,
                front: g.front,
                back: g.back,
              ))
          .toList();
      await _repository.replaceFlashcards(event.material.id!, cards);
      emit(state.copyWith(
        active: GenerationType.none,
        flashcards: cards,
      ));
    } catch (e) {
      emit(state.copyWith(
        active: GenerationType.none,
        errorMessage: () => _message(e),
      ));
    }
  }

  Future<void> _onQuiz(
    GenerateQuiz event,
    Emitter<GeneratorState> emit,
  ) async {
    emit(state.copyWith(
      active: GenerationType.quiz,
      errorMessage: () => null,
    ));
    try {
      final questions = await _service.generateQuiz(
        event.material.title,
        event.material.content,
        count: event.count,
      );
      final withIds = questions
          .map((q) => QuizQuestion(
                materialId: event.material.id!,
                question: q.question,
                options: q.options,
                correctIndex: q.correctIndex,
                explanation: q.explanation,
              ))
          .toList();
      await _repository.replaceQuizQuestions(event.material.id!, withIds);
      emit(state.copyWith(
        active: GenerationType.none,
        questions: withIds,
      ));
    } catch (e) {
      emit(state.copyWith(
        active: GenerationType.none,
        errorMessage: () => _message(e),
      ));
    }
  }

  Future<void> _onPlan(
    GeneratePlan event,
    Emitter<GeneratorState> emit,
  ) async {
    emit(state.copyWith(
      active: GenerationType.plan,
      errorMessage: () => null,
    ));
    try {
      final plan = await _service.generateStudyPlan(
        event.material.title,
        event.material.content,
      );
      final saved = StudyPlan(
        materialId: event.material.id!,
        title: plan.title,
        items: plan.items,
      );
      await _repository.replacePlan(event.material.id!, saved);
      emit(state.copyWith(
        active: GenerationType.none,
        plan: () => saved,
      ));
    } catch (e) {
      emit(state.copyWith(
        active: GenerationType.none,
        errorMessage: () => _message(e),
      ));
    }
  }

  String _message(Object e) => e is AiException ? e.message : '$e';
}