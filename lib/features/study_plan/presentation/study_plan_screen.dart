import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/study_plan.dart';
import '../../../data/repositories/study_repository.dart';

/// Personalized study plan with daily sessions.
class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key, required this.materialId});

  final int materialId;

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  late final Future<StudyPlan?> _planFuture;

  @override
  void initState() {
    super.initState();
    _planFuture =
        context.read<StudyRepository>().getLatestPlan(widget.materialId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study plan')),
      body: FutureBuilder<StudyPlan?>(
        future: _planFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final plan = snapshot.data;
          if (plan == null) {
            return const Center(
              child: Text('No study plan yet. Generate one from your material.'),
            );
          }
          return _PlanView(plan: plan);
        },
      ),
    );
  }
}

class _PlanView extends StatelessWidget {
  const _PlanView({required this.plan});

  final StudyPlan plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_rounded, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Text(
                    '${plan.items.length} sessions · '
                    '${plan.totalMinutes} minutes total',
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'One step at a time — tackle one session each day.',
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < plan.items.length; i++) ...[
          _SessionCard(item: plan.items[i], day: i + 1),
          if (i < plan.items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.item, required this.day});

  final PlanItem item;
  final int day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B4FE9), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'D$day',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.topic,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.activities.join(' · '),
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.durationMinutes} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}