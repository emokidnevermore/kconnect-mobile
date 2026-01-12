/// Экран управления кэшем
///
/// Предоставляет интерфейс для просмотра и управления кэшем приложения
/// с круговой диаграммой и возможностью выборочной очистки категорий.
library;

import 'package:flutter/material.dart';
import '../../services/cache/global_cache_service.dart';
import '../../services/cache/cache_category.dart';
import '../../core/utils/cache_size_calculator.dart';
import '../../theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../features/profile/components/swipe_pop_container.dart';
import '../../services/storage_service.dart';
import 'widgets/cache_pie_chart.dart';
import 'widgets/cache_category_card.dart';

/// Экран управления кэшем
class CacheManagementScreen extends StatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  State<CacheManagementScreen> createState() => _CacheManagementScreenState();
}

class _CacheManagementScreenState extends State<CacheManagementScreen> {
  final GlobalCacheService _cacheService = GlobalCacheService();
  Map<CacheCategory, int> _cacheSizes = {};
  final Map<CacheCategory, bool> _selectedCategories = {};
  int _totalSize = 0;
  bool _isLoading = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSizes();
    // Инициализируем все категории как не выбранные
    for (final category in CacheCategory.values) {
      _selectedCategories[category] = false;
    }
  }

  Future<void> _loadCacheSizes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sizes = await _cacheService.getCacheSizes();
      final total = await _cacheService.getTotalCacheSize();

      setState(() {
        _cacheSizes = sizes;
        _totalSize = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleCategorySelection(CacheCategory category, bool value) {
    setState(() {
      _selectedCategories[category] = value;
    });
  }

  Future<void> _clearSelectedCache() async {
    final selected = _selectedCategories.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();



    setState(() {
      _isClearing = true;
    });

    try {
      await _cacheService.clearCache(selected);
      
      if (mounted) {
        // Сбрасываем выбор
        for (final category in CacheCategory.values) {
          _selectedCategories[category] = false;
        }

        // Перезагружаем размеры кэша
        await _loadCacheSizes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ошибка при очистке кэша'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedCount = _selectedCategories.values.where((v) => v).length;

    return Stack(
      fit: StackFit.expand,
      children: [
        AppBackground(fallbackColor: colorScheme.surface),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SwipePopContainer(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadCacheSizes,
                      child: CustomScrollView(
                        slivers: [
                          // Отступ сверху для хедера
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 72),
                          ),
                          // Круговая диаграмма
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Center(
                                child: FadeTransition(
                                  opacity: AlwaysStoppedAnimation(1.0),
                                  child: CachePieChart(
                                    cacheSizes: _cacheSizes,
                                    totalSize: _totalSize,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Общий размер кэша
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: ValueListenableBuilder<String?>(
                                valueListenable: StorageService.appBackgroundPathNotifier,
                                builder: (context, backgroundPath, child) {
                                  final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
                                  final cardColor = hasBackground
                                      ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                                      : Theme.of(context).colorScheme.surfaceContainerLow;

                                  return Card(
                                    color: cardColor,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Общий размер кэша',
                                            style: AppTextStyles.h3.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            CacheSizeCalculator.formatBytes(_totalSize),
                                            style: AppTextStyles.button.copyWith(
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 24),
                          ),
                          // Заголовок категорий
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                'Категории кэша',
                                style: AppTextStyles.h3.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 12),
                          ),
                          // Список категорий
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final category = CacheCategory.values[index];
                                  final size = _cacheSizes[category] ?? 0;
                                  final isSelected = _selectedCategories[category] ?? false;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: CacheCategoryCard(
                                      category: category,
                                      cacheSize: size,
                                      isSelected: isSelected,
                                      onSelectionChanged: (value) =>
                                          _toggleCategorySelection(category, value),
                                    ),
                                  );
                                },
                                childCount: CacheCategory.values.length,
                              ),
                            ),
                          ),
                          // Кнопка очистки
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: FilledButton(
                                onPressed: _isClearing ? null : _clearSelectedCache,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                  backgroundColor: selectedCount > 0
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHighest,
                                ),
                                child: _isClearing
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        selectedCount > 0
                                            ? 'Очистить выбранное ($selectedCount)'
                                            : 'Выберите категории для очистки',
                                        style: AppTextStyles.button.copyWith(
                                          color: selectedCount > 0
                                              ? colorScheme.onPrimary
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
        // Кастомный хедер с карточками (поверх всего)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: ValueListenableBuilder<String?>(
              valueListenable: StorageService.appBackgroundPathNotifier,
              builder: (context, backgroundPath, child) {
                final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
                final cardColor = hasBackground 
                    ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                    : Theme.of(context).colorScheme.surfaceContainerLow;
                
                return Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      // Карточка слева: кнопка назад и название
                      Card(
                        margin: EdgeInsets.zero,
                        color: cardColor,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Управление кэшем',
                                style: AppTextStyles.postAuthor.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}



