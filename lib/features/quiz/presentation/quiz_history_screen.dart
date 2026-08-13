import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../data/models/quiz_result.dart';
import '../../../data/repositories/study_repository.dart';
import 'quiz_screen.dart';

/// Past quiz attempts with scores and a review-wrong-answers action.
class QuizHistoryScreen extends StatefulWidget {
  const QuizHistoryScreen({super.key, required this.materialId});

  final int materialId;

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  late final Future<List<QuizResult>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _resultsFuture =
        context.read<StudyRepository>().getQuizResults(materialId: widget.materialId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz history', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: FutureBuilder<List<QuizResult>>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final results = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Column(
                    children: [
                      Icon(Icons.quiz_rounded,
                          size: 52, color: scheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        'No quizzes taken yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Take a quiz to see your scores here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              else ...[
                for (var i = 0; i < results.length; i++) ...[
                  _ResultCard(result: results[i]),
                  if (i < results.length - 1) const SizedBox(height: 10),
                ],
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    '${results.length} attempt${results.length == 1 ? '' : 's'} '
                    '· best ${_bestScore(results)}%',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  int _bestScore(List<QuizResult> results) {
    final best = results.fold<double>(
      0,
      (max, r) => r.score > max ? r.score : max,
    );
    return (best * 100).round();
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (result.score * 100).round();
    final passed = pct >= 70;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: passed
                    ? scheme.primaryContainer
                    : scheme.errorContainer,
              ),
              child: Center(
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: passed ? scheme.primary : scheme.error,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${result.correct}/${result.total} correct',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.wrongIds.isEmpty
                        ? 'Perfect score!'
                        : '${result.wrongIds.length} wrong · '
                            '${DateFormat('MMM d, HH:mm').format(result.date ?? DateTime.now())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.check_circle_rounded,
                color: passed ? scheme.primary : scheme.outline),
          ],
        ),
      ),
    );
  }
}

/// Re-quiz only the questions answered wrong in past attempts.
class ReviewWrongScreen extends StatefulWidget {
  const ReviewWrongScreen({super.key, required this.materialId});

  final int materialId;

  @override
  State<ReviewWrongScreen> createState() => _ReviewWrongScreenState();
}

class _ReviewWrongScreenState extends State<ReviewWrongScreen> {
  late final Future<int> _wrongCountFuture;

  @override
  void initState() {
    super.initState();
    _wrongCountFuture = context
        .read<StudyRepository>()
        .getWrongQuestionIds(widget.materialId)
        .then((ids) => ids.length);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review wrong answers',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: FutureBuilder<int>(
        future: _wrongCountFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final count = snapshot.data!;
          if (count == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.celebration_rounded,
                        size: 52, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Nothing to review!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You answered every question correctly in your last '
                      'quizzes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.replay_circle_filled_rounded,
                      size: 56, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    '$count question${count == 1 ? '' : 's'} to review',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Re-quiz only the questions you got wrong before.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuizScreen(
                            materialId: widget.materialId,
                            reviewMode: true,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start review quiz'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
