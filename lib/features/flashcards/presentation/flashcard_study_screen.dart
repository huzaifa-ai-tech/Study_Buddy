import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/flashcard.dart';
import '../../../data/repositories/study_repository.dart';
import '../state/flashcard_session_bloc.dart';

/// Flashcard study session with flip animation and self-assessment.
class FlashcardStudyScreen extends StatefulWidget {
  const FlashcardStudyScreen({
    super.key,
    required this.materialId,
    this.weakOnly = false,
  });

  final int materialId;

  /// When true, only cards not yet mastered are studied.
  final bool weakOnly;

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  late final Future<List<Flashcard>> _cardsFuture;
  List<int?>? _startedIds;

  @override
  void initState() {
    super.initState();
    _cardsFuture = widget.weakOnly
        ? context.read<StudyRepository>().getWeakFlashcards(widget.materialId)
        : context.read<StudyRepository>().getFlashcards(widget.materialId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.weakOnly ? 'Weak cards' : 'Flashcards',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<List<Flashcard>>(
        future: _cardsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final cards = snapshot.data!;
          if (cards.isEmpty) {
            return const Center(
              child: Text('No flashcards yet. Generate them from your material.'),
            );
          }
          final bloc = context.read<FlashcardSessionBloc>();
          final loadedIds = cards.map((c) => c.id).toList();
          if (!listEquals(_startedIds, loadedIds)) {
            _startedIds = loadedIds;
            bloc.add(SessionStarted(cards));
          }
          return BlocBuilder<FlashcardSessionBloc, FlashcardState>(
            builder: (context, state) {
              if (state.cards.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.isFinished) {
                return _SessionSummary(
                  knownCount: state.knownCount,
                  total: state.total,
                  onRestart: () => bloc.add(SessionRestarted()),
                  onDone: () => Navigator.of(context).pop(),
                );
              }
              return _SessionView(
                state: state,
                onFlip: () => bloc.add(const CardFlipped()),
                onRate: (known) => bloc.add(CardRated(known)),
              );
            },
          );
        },
      ),
    );
  }
}

class _SessionView extends StatelessWidget {
  const _SessionView({
    required this.state,
    required this.onFlip,
    required this.onRate,
  });

  final FlashcardState state;
  final VoidCallback onFlip;
  final ValueChanged<bool> onRate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = state.current!;

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
                    value: state.progress,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${state.index + 1} / ${state.total}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: GestureDetector(
                onTap: onFlip,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: state.isFlipped
                      ? _CardFace(
                          key: const ValueKey('back'),
                          gradient: false,
                          label: 'ANSWER',
                          text: card.back,
                        )
                      : _CardFace(
                          key: const ValueKey('front'),
                          gradient: true,
                          label: 'QUESTION · tap to flip',
                          text: card.front,
                        ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onRate(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Didn't know"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onRate(true),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('I knew it'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    super.key,
    required this.gradient,
    required this.label,
    required this.text,
  });

  final bool gradient;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradient ? null : null,
        color: gradient ? null : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: gradient ? null : Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                gradient ? Icons.auto_awesome_rounded : Icons.lightbulb_rounded,
                color: gradient ? Colors.white : scheme.primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: gradient
                      ? Colors.white.withValues(alpha: 0.85)
                      : scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: gradient ? Colors.white : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({
    required this.knownCount,
    required this.total,
    required this.onRestart,
    required this.onDone,
  });

  final int knownCount;
  final int total;
  final VoidCallback onRestart;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = total == 0 ? 0 : (knownCount / total * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: pct >= 80
                    ? const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)])
                    : const LinearGradient(colors: [Color(0xFF5B4FE9), Color(0xFF8B5CF6)]),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'mastered',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Session complete!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'You knew $knownCount of $total cards.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRestart,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Restart'),
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
          ],
        ),
      ),
    );
  }
}