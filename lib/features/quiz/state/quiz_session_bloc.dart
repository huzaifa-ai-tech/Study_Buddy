import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/quiz_question.dart';
import '../../../data/models/quiz_result.dart';
import '../../../data/repositories/study_repository.dart';

class QuizEvent extends Equatable {
  const QuizEvent();

  @override
  List<Object?> get props => [];
}

class QuizStarted extends QuizEvent {
  const QuizStarted(this.questions, this.materialId);

  final List<QuizQuestion> questions;
  final int materialId;

  @override
  List<Object?> get props => [questions, materialId];
}

class AnswerSelected extends QuizEvent {
  const AnswerSelected(this.questionIndex, this.answerIndex);

  final int questionIndex;
  final int answerIndex;

  @override
  List<Object?> get props => [questionIndex, answerIndex];
}

class QuizNext extends QuizEvent {
  const QuizNext();
}

class QuizRestarted extends QuizEvent {
  const QuizRestarted();
}

class QuizState extends Equatable {
  const QuizState({
    this.questions = const [],
    this.materialId,
    this.currentIndex = 0,
    this.selectedAnswer,
    this.answered = false,
    this.correctCount = 0,
    this.wrongIds = const [],
    this.finished = false,
    this.resultId,
    this.errorMessage,
  });

  final List<QuizQuestion> questions;
  final int? materialId;
  final int currentIndex;
  final int? selectedAnswer;
  final bool answered;
  final int correctCount;
  final List<int> wrongIds;
  final bool finished;
  final int? resultId;
  final String? errorMessage;

  bool get hasQuestions => questions.isNotEmpty;

  QuizQuestion? get current =>
      hasQuestions && currentIndex < questions.length
          ? questions[currentIndex]
          : null;

  int get total => questions.length;

  double get score => total == 0 ? 0 : correctCount / total;

  QuizState copyWith({
    List<QuizQuestion>? questions,
    int? Function()? materialId,
    int? currentIndex,
    int? Function()? selectedAnswer,
    bool? answered,
    int? correctCount,
    List<int>? wrongIds,
    bool? finished,
    int? Function()? resultId,
    String? Function()? errorMessage,
  }) {
    return QuizState(
      questions: questions ?? this.questions,
      materialId: materialId != null ? materialId() : this.materialId,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedAnswer:
          selectedAnswer != null ? selectedAnswer() : this.selectedAnswer,
      answered: answered ?? this.answered,
      correctCount: correctCount ?? this.correctCount,
      wrongIds: wrongIds ?? this.wrongIds,
      finished: finished ?? this.finished,
      resultId: resultId != null ? resultId() : this.resultId,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        questions,
        materialId,
        currentIndex,
        selectedAnswer,
        answered,
        correctCount,
        wrongIds,
        finished,
        resultId,
        errorMessage,
      ];
}

/// State machine for a quiz session; persists the result on completion.
class QuizSessionBloc extends Bloc<QuizEvent, QuizState> {
  // ignore: prefer_initializing_formals
  QuizSessionBloc({required StudyRepository repository}) : _repository = repository,
        super(const QuizState()) {
    on<QuizStarted>(_onStarted);
    on<AnswerSelected>(_onAnswer);
    on<QuizNext>(_onNext);
    on<QuizRestarted>(_onRestarted);
  }

  final StudyRepository _repository;

  void _onStarted(QuizStarted event, Emitter<QuizState> emit) {
    emit(QuizState(questions: List.of(event.questions), materialId: event.materialId));
  }

  void _onAnswer(AnswerSelected event, Emitter<QuizState> emit) {
    if (state.answered || state.finished || event.questionIndex != state.currentIndex) {
      return;
    }
    final question = state.current;
    if (question == null) return;
    final isCorrect = event.answerIndex == question.correctIndex;
    emit(state.copyWith(
      answered: true,
      selectedAnswer: () => event.answerIndex,
      correctCount: isCorrect ? state.correctCount + 1 : state.correctCount,
      wrongIds: isCorrect
          ? state.wrongIds
          : question.id != null
              ? [...state.wrongIds, question.id!]
              : state.wrongIds,
    ));
  }

  Future<void> _onNext(QuizNext event, Emitter<QuizState> emit) async {
    if (state.currentIndex >= state.questions.length - 1) {
      if (!state.finished) {
        try {
          final id = await _repository.insertQuizResult(QuizResult(
            materialId: state.materialId ?? 0,
            total: state.total,
            correct: state.correctCount,
            wrongIds: state.wrongIds,
          ));
          emit(state.copyWith(
            finished: true,
            resultId: () => id,
          ));
        } catch (e) {
          emit(state.copyWith(
            finished: true,
            errorMessage: () => 'Could not save result: $e',
          ));
        }
      }
      return;
    }
    emit(state.copyWith(
      currentIndex: state.currentIndex + 1,
      selectedAnswer: () => null,
      answered: false,
    ));
  }

  void _onRestarted(QuizRestarted event, Emitter<QuizState> emit) {
    emit(QuizState(questions: state.questions, materialId: state.materialId));
  }
}