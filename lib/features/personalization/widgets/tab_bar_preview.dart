/// Компонент предпоказа таб-бара
library;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../services/storage_service.dart';
import '../../../../core/constants/tab_bar_glass_mode.dart';
import 'personalization_card.dart';

/// Предпоказ таб-бара с различными режимами отображения
class TabBarPreview extends StatelessWidget {
  final TabBarGlassMode mode;
  final bool hideTabBar;

  const TabBarPreview({
    super.key,
    required this.mode,
    required this.hideTabBar,
  });

  @override
  Widget build(BuildContext context) {
    return PersonalizationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Предпоказ',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          // Контейнер для предпоказа с фоном
          ValueListenableBuilder<String?>(
            valueListenable: StorageService.appBackgroundPathNotifier,
            builder: (context, backgroundPath, child) {
              final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
              final previewBgColor = hasBackground 
                  ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                  : Theme.of(context).colorScheme.surfaceContainerLow;
              
              return Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: previewBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    // Предпоказ таб-бара (центрирован, не занимает всю ширину)
                    if (!hideTabBar)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SizedBox(
                            width: 200,
                            height: 40,
                            child: _PreviewGlassWrapper(
                              mode: mode,
                              borderRadius: 25,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  Icon(
                                    Icons.music_note,
                                    size: 16,
                                    color: context.dynamicPrimaryColor,
                                  ),
                                  Icon(
                                    Icons.newspaper,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  Icon(
                                    Icons.grid_view,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Предпоказ мини-плеера (кнопка музыки) - слева
                    Positioned(
                      bottom: 16,
                      left: 8,
                      child: _PreviewGlassWrapper(
                        mode: mode,
                        borderRadius: 25,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: Icon(
                              Icons.music_note,
                              size: 16,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Предпоказ динамической кнопки - справа
                    Positioned(
                      bottom: 16,
                      right: 8,
                      child: _PreviewGlassWrapper(
                        mode: mode,
                        borderRadius: 25,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Обертка для предпоказа с различными режимами стекла
class _PreviewGlassWrapper extends StatelessWidget {
  final TabBarGlassMode mode;
  final double borderRadius;
  final Widget child;

  const _PreviewGlassWrapper({
    required this.mode,
    required this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final settings = const LiquidGlassSettings(
      thickness: 15,
      glassColor: Color(0x33FFFFFF),
      lightIntensity: 1.5,
      chromaticAberration: 1,
      saturation: 1.1,
      ambientStrength: 1,
      blur: 4,
      refractiveIndex: 1.8,
    );

    switch (mode) {
      case TabBarGlassMode.glass:
        return LiquidGlassLayer(
          settings: settings,
          child: LiquidGlass(
            shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
            child: child,
          ),
        );
      case TabBarGlassMode.fakeGlass:
        return FakeGlass(
          shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
          settings: settings,
          child: child,
        );
      case TabBarGlassMode.solid:
        return ValueListenableBuilder<String?>(
          valueListenable: StorageService.appBackgroundPathNotifier,
          builder: (context, backgroundPath, _) {
            final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
            final solidColor = hasBackground 
                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.85)
                : Theme.of(context).colorScheme.surfaceContainerLow;
            
            return Container(
              decoration: BoxDecoration(
                color: solidColor,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: child,
            );
          },
        );
    }
  }
}
