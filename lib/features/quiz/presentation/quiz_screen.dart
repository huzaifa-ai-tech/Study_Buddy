import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/quiz_question.dart';
import '../../../data/repositories/study_repository.dart';
import '../state/quiz_session_bloc.dart';
import 'quiz_history_screen.dart';

/// Quiz session: multiple choice questions with immediate feedback.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.materialId, this.reviewMode = false});

  final int materialId;

  /// When true, only questions answered wrong in past attempts are asked.
  final bool reviewMode;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final Future<List<QuizQuestion>> _questionsFuture;
  List<int?>? _startedIds;

  @override
  void initState() {
    super.initState();
    _questionsFuture = _loadQuestions();
  }

  Future<List<QuizQuestion>> _loadQuestions() async {
    final repository = context.read<StudyRepository>();
    if (!widget.reviewMode) {
      return repository.getQuizQuestions(widget.materialId);
    }
    final wrongIds = await repository.getWrongQuestionIds(widget.materialId);
    return repository.getQuizQuestionsByIds(widget.materialId, wrongIds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.reviewMode ? 'Review quiz' : 'Quiz',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Quiz history',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      QuizHistoryScreen(materialId: widget.materialId),
                ),
              );
            },
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<QuizQuestion>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final questions = snapshot.data!;
          if (questions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  widget.reviewMode
                      ? 'Nothing to review — you answered everything correctly!'
                      : 'No quiz yet. Generate questions from your material.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final bloc = context.read<QuizSessionBloc>();
          final loadedIds = questions.map((q) => q.id).toList();
          if (!listEquals(_startedIds, loadedIds)) {
            _startedIds = loadedIds;
            bloc.add(QuizStarted(questions, widget.materialId));
          }
          return BlocBuilder<QuizSessionBloc, QuizState>(
            builder: (context, state) {
              if (state.questions.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.finished) {
                return _QuizSummary(
                  state: state,
                  onRestart: () => bloc.add(QuizRestarted()),
                  onReviewWrong: state.wrongIds.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => QuizScreen(
                                materialId: widget.materialId,
                                reviewMode: true,
                              ),
                            ),
                          );
                        },
                  onDone: () => Navigator.of(context).pop(),
                );
              }
              return _QuestionView(
                state: state,
                onSelect: (i) =>
                    bloc.add(AnswerSelected(state.currentIndex, i)),
                onNext: () => bloc.add(const QuizNext()),
              );
            },
          );
        },
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.state,
    required this.onSelect,
    required this.onNext,
  });

  final QuizState state;
  final ValueChanged<int> onSelect;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final question = state.current!;
    final progress = state.total == 0 ? 0.0 : state.currentIndex / state.total;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${state.currentIndex + 1} / ${state.total}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  question.question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < question.options.length; i++) ...[
                _OptionTile(
                  index: i,
                  text: question.options[i],
                  selected: state.selectedAnswer == i,
                  answered: state.answered,
                  isCorrect: question.correctIndex == i,
                  onTap: state.answered ? null : () => onSelect(i),
                ),
                if (i < question.options.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.answered ? onNext : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(state.answered ? 'Next question' : 'Check answer'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.text,
    required this.selected,
    required this.answered,
    required this.isCorrect,
    required this.onTap,
  });

  final int index;
  final String text;
  final bool selected;
  final bool answered;
  final bool isCorrect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color? bg;
    Color? border;
    IconData? icon;

    if (answered) {
      if (isCorrect) {
        bg = scheme.primaryContainer;
        border = scheme.primary;
        icon = Icons.check_circle_rounded;
      } else if (selected) {
        bg = scheme.errorContainer;
        border = scheme.error;
        icon = Icons.cancel_rounded;
      }
    } else if (selected) {
      border = scheme.primary;
      bg = scheme.primary.withValues(alpha: 0.08);
    }

    return Material(
      color: bg ?? scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: border ?? scheme.outlineVariant,
          width: border != null ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                String.fromCharCode(65 + index),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              if (icon != null)
                Icon(icon, color: isCorrect ? scheme.primary : scheme.error),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizSummary extends StatelessWidget {
  const _QuizSummary({
    required this.state,
    required this.onRestart,
    required this.onReviewWrong,
    required this.onDone,
  });

  final QuizState state;
  final VoidCallback onRestart;
  final VoidCallback? onReviewWrong;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = state.total;
    final pct = total == 0 ? 0 : (state.correctCount / total * 100).round();
    final passed = pct >= 70;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: passed
                      ? const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)])
                      : const LinearGradient(colors: [Color(0xFF5B4FE9), Color(0xFF8B5CF6)]),
                ),
                child: Center(
                  child: Text(
                    '${state.correctCount}/$total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                passed ? 'Great job!' : 'Keep practicing!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'You answered $pct% correctly.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (onReviewWrong != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${state.wrongIds.length} question${state.wrongIds.length == 1 ? '' : 's'} '
                  'to review.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRestart,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Retry'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDone,
                      icon: const Icon(Icons.done_rounded),
                      label: const Text('Done'),
                    ),
                  ),
                ],
              ),
              if (onReviewWrong != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onReviewWrong,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Review wrong answers'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}