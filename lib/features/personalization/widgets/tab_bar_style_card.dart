/// Карточка настройки стиля таб-бара
library;

import 'package:flutter/material.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../../core/constants/tab_bar_glass_mode.dart';
import 'personalization_card.dart';

/// Карточка для выбора стиля отображения таб-бара
class TabBarStyleCard extends StatelessWidget {
  final TabBarGlassMode selectedMode;
  final ValueChanged<TabBarGlassMode> onModeChanged;

  const TabBarStyleCard({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PersonalizationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Выберите стиль отображения',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<TabBarGlassMode>(
            segments: [
              ButtonSegment<TabBarGlassMode>(
                value: TabBarGlassMode.glass,
                label: const Text('Glass'),
                icon: const Icon(Icons.auto_awesome, size: 18),
              ),
              ButtonSegment<TabBarGlassMode>(
                value: TabBarGlassMode.fakeGlass,
                label: const Text('Fake Glass'),
                icon: const Icon(Icons.grid_view, size: 18),
              ),
              ButtonSegment<TabBarGlassMode>(
                value: TabBarGlassMode.solid,
                label: const Text('Solid'),
                icon: const Icon(Icons.check_box, size: 18),
              ),
            ],
            selected: {selectedMode},
            onSelectionChanged: (Set<TabBarGlassMode> newSelection) {
              if (newSelection.isNotEmpty) {
                onModeChanged(newSelection.first);
              }
            },
            multiSelectionEnabled: false,
          ),
        ],
      ),
    );
  }
}

