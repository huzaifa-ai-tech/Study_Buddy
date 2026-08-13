import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app_shell.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_widgets.dart';
import '../../../data/models/study_material.dart';
import '../../materials/presentation/material_detail_screen.dart';
import '../../materials/state/material_bloc.dart';
import '../../settings/state/settings_bloc.dart';

/// Dashboard with stats, quick actions and recent materials.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onSeeAll});

  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final settings = context.select((SettingsBloc b) => b.state.settings);
    return BlocBuilder<MaterialBloc, MaterialsState>(
      builder: (context, state) {
        final materials = state.materials;
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async =>
                context.read<MaterialBloc>().add(const MaterialsLoaded()),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: HeroHeader(
                    title: 'StudyBuddy',
                    subtitle: 'Turn your notes into knowledge',
                    stats: [
                      HeroStat(
                        icon: Icons.library_books_rounded,
                        label: 'Materials',
                        value: '${state.stats['materials'] ?? 0}',
                      ),
                      HeroStat(
                        icon: Icons.style_rounded,
                        label: 'Flashcards',
                        value: '${state.stats['flashcards'] ?? 0}',
                      ),
                      HeroStat(
                        icon: Icons.quiz_rounded,
                        label: 'Quizzes',
                        value: '${state.stats['quizzes'] ?? 0}',
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList.list(
                    children: [
                      AiStatusBanner(settings: settings),
                      Text(
                        'Start learning',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: QuickActionCard(
                              icon: Icons.style_rounded,
                              title: 'Flashcards',
                              subtitle: 'Study with smart cards',
                              color: const Color(0xFF8B5CF6),
                              onTap: () => _pickMaterial(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: QuickActionCard(
                              icon: Icons.quiz_rounded,
                              title: 'Quiz',
                              subtitle: 'Test what you know',
                              color: const Color(0xFF0EA5E9),
                              onTap: () => _pickMaterial(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: QuickActionCard(
                              icon: Icons.route_rounded,
                              title: 'Study plan',
                              subtitle: 'Learn on a schedule',
                              color: const Color(0xFFF59E0B),
                              onTap: () => _pickMaterial(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text(
                            'Recent materials',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          if (materials.isNotEmpty)
                            TextButton(
                              onPressed: onSeeAll,
                              child: const Text('See all'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                if (materials.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyHome(onAdd: () {}),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                    sliver: SliverList.separated(
                      itemCount: materials.length.clamp(0, 4),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) =>
                          _RecentMaterialCard(material: materials[i]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickMaterial(BuildContext context) async {
    final state = context.read<MaterialBloc>().state;
    if (state.materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a study material first')),
      );
      return;
    }
    final picked = await showModalBottomSheet<StudyMaterial>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Choose a material',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            for (final material in state.materials)
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: Text(material.title),
                subtitle: Text(
                  '${material.wordCount} words',
                ),
                onTap: () => Navigator.pop(sheetContext, material),
              ),
          ],
        ),
      ),
    );
    if (picked != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MaterialDetailScreen(material: picked),
        ),
      );
    }
  }
}

class _RecentMaterialCard extends StatelessWidget {
  const _RecentMaterialCard({required this.material});

  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
        ),
        title: Text(
          material.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          material.summary != null && material.summary!.isNotEmpty
              ? material.summary!.length > 80
                  ? '${material.summary!.substring(0, 80)}...'
                  : material.summary!
              : '${material.wordCount} words · ${_date(material.createdAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MaterialDetailScreen(material: material),
          ),
        ),
      ),
    );
  }

  String _date(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM d').format(date);
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to StudyBuddy!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first study material and the AI will turn it into '
              'flashcards, quizzes and a study plan.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}