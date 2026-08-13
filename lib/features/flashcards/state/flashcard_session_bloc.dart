import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/flashcard.dart';
import '../../../data/repositories/study_repository.dart';

class FlashcardEvent extends Equatable {
  const FlashcardEvent();

  @override
  List<Object?> get props => [];
}

class SessionStarted extends FlashcardEvent {
  const SessionStarted(this.cards);

  final List<Flashcard> cards;

  @override
  List<Object?> get props => [cards];
}

class CardFlipped extends FlashcardEvent {
  const CardFlipped();
}

class CardRated extends FlashcardEvent {
  const CardRated(this.known);

  final bool known;

  @override
  List<Object?> get props => [known];
}

class SessionRestarted extends FlashcardEvent {
  const SessionRestarted();
}

class FlashcardState extends Equatable {
  const FlashcardState({
    this.cards = const [],
    this.index = 0,
    this.isFlipped = false,
    this.knownMap = const {},
    this.isFinished = false,
  });

  final List<Flashcard> cards;
  final int index;
  final bool isFlipped;
  final Map<int, bool> knownMap;
  final bool isFinished;

  bool get hasCards => cards.isNotEmpty;

  Flashcard? get current => hasCards && index < cards.length ? cards[index] : null;

  int get total => cards.length;

  int get remaining => max(0, total - index);

  int get knownCount => knownMap.values.where((v) => v).length;

  double get progress => total == 0 ? 0 : index / total;

  FlashcardState copyWith({
    List<Flashcard>? cards,
    int? index,
    bool? isFlipped,
    Map<int, bool>? knownMap,
    bool? isFinished,
  }) {
    return FlashcardState(
      cards: cards ?? this.cards,
      index: index ?? this.index,
      isFlipped: isFlipped ?? this.isFlipped,
      knownMap: knownMap ?? this.knownMap,
      isFinished: isFinished ?? this.isFinished,
    );
  }

  @override
  List<Object?> get props => [cards, index, isFlipped, knownMap, isFinished];
}

/// State machine for a flashcard study session.
class FlashcardSessionBloc extends Bloc<FlashcardEvent, FlashcardState> {
  FlashcardSessionBloc({required StudyRepository repository})
      : super(const FlashcardState()) {
    _repository = repository;
    on<SessionStarted>(_onStarted);
    on<CardFlipped>(_onFlipped);
    on<CardRated>(_onRated);
    on<SessionRestarted>(_onRestarted);
  }

  late final StudyRepository _repository;

  void _onStarted(SessionStarted event, Emitter<FlashcardState> emit) {
    emit(FlashcardState(cards: List.of(event.cards)));
  }

  void _onFlipped(CardFlipped event, Emitter<FlashcardState> emit) {
    if (state.isFinished || state.current == null) return;
    emit(state.copyWith(isFlipped: !state.isFlipped));
  }

  void _onRated(CardRated event, Emitter<FlashcardState> emit) {
    if (state.isFinished || state.current == null) return;
    final card = state.current!;
    final updated = Map<int, bool>.of(state.knownMap)
      ..[state.index] = event.known;
    if (card.id != null) {
      _repository.updateFlashcardMastery(card.id!, event.known);
    }
    if (state.index >= state.cards.length - 1) {
      emit(state.copyWith(knownMap: updated, isFinished: true));
    } else {
      emit(state.copyWith(
        knownMap: updated,
        index: state.index + 1,
        isFlipped: false,
      ));
    }
  }

  void _onRestarted(SessionRestarted event, Emitter<FlashcardState> emit) {
    emit(FlashcardState(cards: state.cards));
  }
}