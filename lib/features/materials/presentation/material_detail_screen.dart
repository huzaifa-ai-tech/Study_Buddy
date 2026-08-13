import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/study_material.dart';
import '../../../data/repositories/study_repository.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../flashcards/presentation/flashcard_study_screen.dart';
import '../../generator/state/generator_bloc.dart';
import '../../quiz/presentation/quiz_history_screen.dart';
import '../../quiz/presentation/quiz_screen.dart';
import '../../study_plan/presentation/study_plan_screen.dart';
import '../state/material_bloc.dart';
import 'edit_material_screen.dart';

/// Detail view of one material with AI actions.
class MaterialDetailScreen extends StatelessWidget {
  const MaterialDetailScreen({super.key, required this.material});

  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(material.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Ask AI',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(material: material),
              ),
            ),
            icon: const Icon(Icons.smart_toy_rounded),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditMaterialScreen(material: material),
              ),
            ),
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: _MaterialDetailBody(material: material),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete material?'),
        content: const Text(
          'This removes the material and all its flashcards, quizzes and '
          'study plans.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      if (!context.mounted) return;
      context.read<MaterialBloc>().add(MaterialDeleted(material.id!));
      Navigator.of(context).pop();
    }
  }
}

class _MaterialDetailBody extends StatefulWidget {
  const _MaterialDetailBody({required this.material});

  final StudyMaterial material;

  @override
  State<_MaterialDetailBody> createState() => _MaterialDetailBodyState();
}

class _MaterialDetailBodyState extends State<_MaterialDetailBody> {
  late Future<_MaterialData> _dataFuture;
  String? _pendingGeneration;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_MaterialData> _load() async {
    final repository = context.read<StudyRepository>();
    final material = await repository.getMaterial(widget.material.id!);
    final cards = await repository.getFlashcards(widget.material.id!);
    final mastered =
        await repository.getFlashcardMasteredCount(widget.material.id!);
    final questions = await repository.getQuizQuestions(widget.material.id!);
    final plan = await repository.getLatestPlan(widget.material.id!);
    return _MaterialData(
      material: material ?? widget.material,
      cardCount: cards.length,
      masteredCount: mastered,
      questionCount: questions.length,
      plan: plan,
    );
  }

  void _reload() {
    setState(() => _dataFuture = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MaterialData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final material = data.material;
        final scheme = Theme.of(context).colorScheme;

        return BlocListener<GeneratorBloc, GeneratorState>(
          listener: (context, state) {
            if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
              setState(() => _pendingGeneration = null);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(state.errorMessage!)),
                );
              return;
            }
            final pending = _pendingGeneration;
            if (pending == null || state.active != GenerationType.none) return;
            final target = switch (pending) {
              'flashcards' =>
                state.flashcards.isNotEmpty ? 'flashcards' : null,
              'quiz' => state.questions.isNotEmpty ? 'quiz' : null,
              'plan' => state.plan != null ? 'plan' : null,
              _ => null,
            };
            if (target == null) return;
            setState(() => _pendingGeneration = null);
            _reload();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              switch (target) {
                case 'flashcards':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FlashcardStudyScreen(
                        materialId: widget.material.id!,
                      ),
                    ),
                  );
                case 'quiz':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          QuizScreen(materialId: widget.material.id!),
                    ),
                  );
                case 'plan':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          StudyPlanScreen(materialId: widget.material.id!),
                    ),
                  );
              }
            });
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _SummaryCard(
                material: material,
                onGenerated: _reload,
              ),
              const SizedBox(height: 16),
              Text(
                'Study tools',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              _StudyToolCard(
                icon: Icons.style_rounded,
                color: const Color(0xFF8B5CF6),
                title: 'Flashcards',
                subtitle: data.cardCount == 0
                    ? 'Generate cards from this material'
                    : '${data.cardCount} cards · '
                        '${data.masteredCount} mastered',
                buttonLabel: data.cardCount == 0 ? 'Generate' : 'Study',
                onPressed: () => _handleFlashcards(context, material, data.cardCount),
                secondaryLabel:
                    data.cardCount > 0 && data.masteredCount < data.cardCount
                        ? 'Weak ${data.cardCount - data.masteredCount}'
                        : null,
                onSecondaryPressed: data.cardCount > 0 &&
                        data.masteredCount < data.cardCount
                    ? () => _openStudyScreen(
                          () => FlashcardStudyScreen(
                            materialId: material.id!,
                            weakOnly: true,
                          ),
                        )
                    : null,
              ),
              const SizedBox(height: 10),
              _StudyToolCard(
                icon: Icons.quiz_rounded,
                color: const Color(0xFF0EA5E9),
                title: 'Quiz',
                subtitle: data.questionCount == 0
                    ? 'Generate questions to test yourself'
                    : '${data.questionCount} questions ready',
                buttonLabel: data.questionCount == 0 ? 'Generate' : 'Take quiz',
                onPressed: () => _handleQuiz(context, material, data.questionCount),
                secondaryLabel: data.questionCount > 0 ? 'History' : null,
                onSecondaryPressed: data.questionCount > 0
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QuizHistoryScreen(
                              materialId: material.id!,
                            ),
                          ),
                        )
                    : null,
              ),
              const SizedBox(height: 10),
              _StudyToolCard(
                icon: Icons.route_rounded,
                color: const Color(0xFFF59E0B),
                title: 'Study plan',
                subtitle: data.plan == null
                    ? 'Generate a personalized schedule'
                    : '${data.plan!.items.length} sessions · '
                        '${data.plan!.totalMinutes} min',
                buttonLabel: data.plan == null ? 'Generate' : 'View plan',
                onPressed: () => _handlePlan(context, material, data.plan != null),
              ),
              const SizedBox(height: 24),
              Text(
                'Source content',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(
                  material.content,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleFlashcards(
    BuildContext context,
    StudyMaterial material,
    int count,
  ) {
    if (count == 0) {
      setState(() => _pendingGeneration = 'flashcards');
      context.read<GeneratorBloc>().add(GenerateFlashcards(material));
      _showGenerating('Generating flashcards...');
    } else {
      _openStudyScreen(
        () => FlashcardStudyScreen(materialId: material.id!),
      );
    }
  }

  void _handleQuiz(BuildContext context, StudyMaterial material, int count) {
    if (count == 0) {
      setState(() => _pendingGeneration = 'quiz');
      context.read<GeneratorBloc>().add(GenerateQuiz(material));
      _showGenerating('Generating quiz questions...');
    } else {
      _openStudyScreen(() => QuizScreen(materialId: material.id!));
    }
  }

  void _handlePlan(BuildContext context, StudyMaterial material, bool exists) {
    if (!exists) {
      setState(() => _pendingGeneration = 'plan');
      context.read<GeneratorBloc>().add(GeneratePlan(material));
      _showGenerating('Generating your study plan...');
    } else {
      _openStudyScreen(() => StudyPlanScreen(materialId: material.id!));
    }
  }

  Future<void> _openStudyScreen(Widget Function() builder) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => builder()),
    );
    if (mounted) _reload();
  }

  void _showGenerating(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MaterialData {
  const _MaterialData({
    required this.material,
    required this.cardCount,
    required this.masteredCount,
    required this.questionCount,
    required this.plan,
  });

  final StudyMaterial material;
  final int cardCount;
  final int masteredCount;
  final int questionCount;
  final dynamic plan;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.material, required this.onGenerated});

  final StudyMaterial material;
  final VoidCallback onGenerated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSummary = material.summary != null && material.summary!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (!hasSummary)
                FilledButton(
                  onPressed: () {
                    context.read<GeneratorBloc>().add(GenerateSummary(material));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(content: Text('Generating summary...')),
                      );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: scheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Generate'),
                ),
            ],
          ),
          if (hasSummary) ...[
            const SizedBox(height: 12),
            Text(
              material.summary!,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.55),
            ),
          ] else
            const SizedBox(height: 10),
          if (!hasSummary)
            Text(
              'Get a structured summary of these notes with one tap.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }
}

class _StudyToolCard extends StatelessWidget {
  const _StudyToolCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (secondaryLabel != null && onSecondaryPressed != null) ...[
              OutlinedButton(
                onPressed: onSecondaryPressed,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                child: Text(secondaryLabel!),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton.tonal(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

String formatDate(DateTime? date) =>
    date == null ? '' : DateFormat('MMM d, yyyy').format(date);