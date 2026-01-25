import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../provider/user.dart';

/// Modern bottom sheet for skill level selection during onboarding.
class SkillLevelSheet extends StatefulWidget {
  const SkillLevelSheet({super.key});

  @override
  State<SkillLevelSheet> createState() => _SkillLevelSheetState();
}

class _SkillLevelSheetState extends State<SkillLevelSheet> {
  String? _selectedLevel;
  bool _isSubmitting = false;

  static const List<_SkillLevel> _levels = [
    _SkillLevel(
      key: 'beginner',
      title: 'Beginner',
      description: 'Learning the basics',
      icon: Icons.emoji_events_outlined,
      rating: 1000,
      color: Colors.green,
    ),
    _SkillLevel(
      key: 'intermediate',
      title: 'Intermediate',
      description: 'Comfortable with rallies',
      icon: Icons.workspace_premium_outlined,
      rating: 1400,
      color: Colors.orange,
    ),
    _SkillLevel(
      key: 'advanced',
      title: 'Advanced',
      description: 'Competitive player',
      icon: Icons.military_tech,
      rating: 1800,
      color: Colors.purple,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'What\'s your skill level?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.2, end: 0),
              const SizedBox(height: 8),

              Text(
                'This helps us match you with the right players',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 100.ms),
              const SizedBox(height: 28),

              // Level Options
              ...List.generate(_levels.length, (index) {
                final level = _levels[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LevelOption(
                    level: level,
                    isSelected: _selectedLevel == level.key,
                    onTap: () => setState(() => _selectedLevel = level.key),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms, delay: (150 + index * 80).ms)
                      .slideX(begin: 0.1, end: 0, delay: (150 + index * 80).ms),
                );
              }),

              const SizedBox(height: 20),

              // Continue Button
              _buildContinueButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    final profile = context.read<ProfileProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return FilledButton(
      onPressed: _selectedLevel == null || _isSubmitting
          ? null
          : () async {
              setState(() => _isSubmitting = true);
              await profile.completeOnboarding(selectedLevel: _selectedLevel!);
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: colorScheme.primary,
        disabledBackgroundColor: colorScheme.surfaceContainerHighest,
      ),
      child: _isSubmitting
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onPrimary,
              ),
            )
          : Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _selectedLevel == null
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onPrimary,
              ),
            ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 500.ms)
        .slideY(begin: 0.2, end: 0, delay: 500.ms);
  }
}

/// Data class for skill level options
class _SkillLevel {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final int rating;
  final Color color;

  const _SkillLevel({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.rating,
    required this.color,
  });
}

/// Individual skill level option card
class _LevelOption extends StatelessWidget {
  final _SkillLevel level;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelOption({
    required this.level,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withOpacity(0.15)
                      : level.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  level.icon,
                  size: 28,
                  color: isSelected ? colorScheme.primary : level.color,
                ),
              ),
              const SizedBox(width: 16),

              // Title and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Rating badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withOpacity(0.15)
                      : colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${level.rating}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              // Checkmark
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  size: 24,
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
