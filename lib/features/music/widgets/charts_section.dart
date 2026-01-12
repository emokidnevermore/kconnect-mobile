/// Секция чартов с табами для разных категорий треков
///
/// Отображает чарты в виде табов: Популярное, Топ, Популярные, Новые.
/// Поддерживает загрузку данных и отображение первых 5 треков в каждой категории.
/// Для популярных треков отображаются индикаторы тренда (рост/падение).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/services/storage_service.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/utils/image_utils.dart';
import '../../../services/cache/audio_preload_service.dart';
import '../domain/models/track.dart';
import '../presentation/blocs/music_bloc.dart';
import '../presentation/blocs/music_state.dart';
import 'trend_indicator.dart';

/// Виджет секции чартов с переключаемыми табами
///
/// Показывает музыкальные чарты в разных категориях.
/// Поддерживает компактное отображение треков с номерами позиций.
class ChartsSection extends StatefulWidget {
  final Function(Track, String, List<Track>)? onTrackTap;
  final Function(Track)? onTrackPlay;
  final Function(Track)? onTrackLike;

  const ChartsSection({
    super.key,
    this.onTrackTap,
    this.onTrackPlay,
    this.onTrackLike,
  });

  @override
  State<ChartsSection> createState() => _ChartsSectionState();
}

class _ChartsSectionState extends State<ChartsSection> {
  String _selectedKey = 'popular';
  final AudioPreloadService _preloadService = AudioPreloadService.instance;

  final List<Map<String, dynamic>> _chartTabs = [
    {'key': 'popular', 'label': 'Популярное', 'icon': Icons.bar_chart},
    {'key': 'most_liked', 'label': 'Топ', 'icon': Icons.favorite},
    {'key': 'most_played', 'label': 'Популярные', 'icon': Icons.local_fire_department},
    {'key': 'new_releases', 'label': 'Новые', 'icon': Icons.star},
  ];

  @override
  void initState() {
    super.initState();
    // Предзагружаем треки при первой загрузке
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = context.read<MusicBloc>().state;
        final selectedTracks = state.charts[_selectedKey] ?? [];
        _preloadTracksForTab(selectedTracks);
      }
    });
  }

  void _preloadTracksForTab(List<Track> tracks) {
    if (tracks.isEmpty) return;
    // Предзагружаем все треки из чарта (их всего 5)
    _preloadService.preloadTracks(tracks, priority: PreloadPriority.visible);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicBloc, MusicState>(
      builder: (context, state) {
        if (state.chartsStatus == MusicLoadStatus.loading && state.charts.isEmpty) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              highlightColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Container(
                height: 500,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header shimmer
                    Container(
                      height: 24,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // SegmentedButton shimmer
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // List items shimmer
                    Expanded(
                      child: Column(
                        children: List.generate(5, (index) => Padding(
                          padding: EdgeInsets.only(bottom: index < 4 ? 12 : 0),
                          child: Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state.charts.isEmpty) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: SizedBox(
              height: 500,
              child: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }

        final selectedTracks = state.charts[_selectedKey] ?? [];

        return ValueListenableBuilder<String?>(
          valueListenable: StorageService.appBackgroundPathNotifier,
          builder: (context, backgroundPath, child) {
            final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
            final cardColor = hasBackground 
                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                : Theme.of(context).colorScheme.surfaceContainerLow;
            
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          color: cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Text(
                      'Чарты',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // SegmentedButton for categories - using grid layout
                    SizedBox(
                      height: 95, // 2 rows * 44px + spacing (8px)
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 4.0, // Increased to make buttons narrower
                        children: _chartTabs.map((tab) {
                          final isSelected = _selectedKey == tab['key'] as String;
                          return _buildSegmentedButtonTab(
                            tab,
                            isSelected,
                            hasBackground,
                            () {
                              setState(() {
                        _selectedKey = tab['key'] as String;
                        // Предзагружаем треки при смене таба
                        _preloadTracksForTab(selectedTracks);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            // Divider
            Divider(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 8),
            // Content - Fixed height container
            SizedBox(
              height: 400,
              child: _buildChartList(selectedTracks, hasBackground),
            ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChartList(List<Track> tracks, bool hasBackground) {
    if (tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Нет данных',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Лимит в 5 треков
    final limitedTracks = tracks.take(5).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: limitedTracks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final track = limitedTracks[index];
        return _buildCompactTrackItem(track, index, tracks, hasBackground);
      },
    );
  }

  Widget _buildSegmentedButtonTab(
    Map<String, dynamic> tab,
    bool isSelected,
    bool hasBackground,
    VoidCallback onTap,
  ) {
    final backgroundColor = isSelected
        ? Theme.of(context).colorScheme.primaryContainer
        : (hasBackground 
            ? Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.7)
            : Theme.of(context).colorScheme.surfaceContainerLow);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  tab['icon'] as IconData? ?? Icons.music_note,
                  size: 16,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tab['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTrackItem(Track track, int index, List<Track> selectedTracks, bool hasBackground) {
    final title = track.title;
    final artist = track.artist;
    final albumArt = track.coverPath;
    final isLiked = track.isLiked;
    final position = index + 1;
    final itemColor = hasBackground 
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
        : Theme.of(context).colorScheme.surfaceContainerLow;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTrackTap != null 
            ? () => widget.onTrackTap!(track, _selectedKey, selectedTracks) 
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: itemColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Position number
              SizedBox(
                width: 32,
                child: Text(
                  '$position',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Album art
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImageUtils.buildAlbumArt(
                  albumArt,
                  context,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artist,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Trend indicator (only for popular charts)
              if (_selectedKey == 'popular')
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TrendIndicator(
                    trend: track.trend,
                    changePercent: null,
                    iconSize: 14,
                  ),
                ),
              // Like button
              if (widget.onTrackLike != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onTrackLike!(track),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: isLiked
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
