/// Полноэкранный поиск музыки
///
/// Открывается как отдельный экран с анимацией, аналогично полноэкранному плееру.
/// Предоставляет интерфейс для поиска треков с debounced вводом.
/// Показывает историю прослушанных треков при отсутствии поиска.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../theme/app_text_styles.dart';
import '../domain/models/track.dart';
import '../presentation/blocs/music_bloc.dart';
import '../presentation/blocs/music_event.dart';
import '../presentation/blocs/music_state.dart';
import '../presentation/blocs/queue_bloc.dart';
import '../presentation/blocs/queue_event.dart';
import 'track_list_item.dart';
import '../../../services/storage_service.dart';
import '../../../core/widgets/app_background.dart';

/// Виджет полноэкранного поиска музыки
///
/// Анимируется аналогично FullScreenPlayer с fade и slide up эффектами.
/// Поддерживает поиск с задержкой и отображение истории прослушанных треков.
class FullScreenSearch extends StatefulWidget {
  const FullScreenSearch({super.key});

  @override
  State<FullScreenSearch> createState() => _FullScreenSearchState();
}

class _FullScreenSearchState extends State<FullScreenSearch>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideUpAnimation;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _slideUpAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Запускаем анимации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });

    // Load played tracks history when screen opens
    context.read<MusicBloc>().add(MusicPlayedTracksHistoryLoaded());
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    // Cancel previous timer
    _debounceTimer?.cancel();

    // If query is empty, clear current query and results, show history
    if (query.isEmpty) {
      setState(() => _currentQuery = '');
      // Clear search results when query is empty
      context.read<MusicBloc>().add(MusicTracksSearched(''));
      return;
    }

    // Debounce search
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (query.length >= 2 && query != _currentQuery) {
        setState(() => _currentQuery = query);
        context.read<MusicBloc>().add(MusicTracksSearched(query));
      }
    });
  }

  void _onHistoryTrackTap(Track track) {
    // When tapping on a track from history, just play it
    _playTrack(track);
  }

  void _onTrackTap(Track track) {
    // Play the track
    _playTrack(track);
    // Save track to played history
    context.read<MusicBloc>().add(MusicPlayedTrackSaved(track));
  }

  void _playTrack(Track track) {
    try {
      // Use the same approach as music_home.dart - create a queue with the single track
      context.read<QueueBloc>().add(QueuePlayTracksRequested([track], 'search', startIndex: 0));
    } catch (e) {
      debugPrint('FullScreenSearch: Error playing track: $e');
    }
  }

  void _onClearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Очистить историю'),
        content: const Text('Вы уверены, что хотите очистить историю прослушанных треков?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              context.read<MusicBloc>().add(MusicPlayedTracksHistoryCleared());
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // AppBackground as bottom layer
        AppBackground(fallbackColor: Theme.of(context).colorScheme.surface),

        // Main content
        Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Контент
                SafeArea(
                  child: Column(
                    children: [
                      // Хедер с карточкой
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) => Opacity(
                          opacity: _fadeAnimation.value,
                          child: Transform.translate(
                            offset: Offset(0, _slideUpAnimation.value),
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
                              color: Colors.transparent,
                              child: Row(
                                children: [
                                  ValueListenableBuilder<String?>(
                                    valueListenable: StorageService.appBackgroundPathNotifier,
                                    builder: (context, backgroundPath, child) {
                                      final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
                                      final cardColor = hasBackground
                                          ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                                          : Theme.of(context).colorScheme.surfaceContainerLow;

                                      return Card(
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
                                                'Поиск музыки',
                                                style: AppTextStyles.postAuthor.copyWith(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Search field
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) => Opacity(
                          opacity: _fadeAnimation.value,
                          child: Transform.translate(
                            offset: Offset(0, _slideUpAnimation.value),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: ValueListenableBuilder<String?>(
                                valueListenable: StorageService.appBackgroundPathNotifier,
                                builder: (context, backgroundPath, child) {
                                  final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
                                  final inputFillColor = hasBackground
                                      ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                                      : Theme.of(context).colorScheme.surfaceContainerHighest;

                                  return TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: 'Введите название трека, артиста...',
                                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      filled: true,
                                      fillColor: inputFillColor,
                                      prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Content
                      Expanded(
                        child: BlocBuilder<MusicBloc, MusicState>(
                          builder: (context, state) {
                            // Show played tracks history if no query
                            if (_currentQuery.isEmpty) {
                              return _buildPlayedTracksHistory(state.playedTracksHistory);
                            }

                            // Show search results
                            return _buildSearchResults(state);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Clear history button (only show when displaying history)
                if (_currentQuery.isEmpty)
                  Positioned(
                    bottom: 50,
                    left: 16,
                    right: 16,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) => Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _slideUpAnimation.value),
                          child: Center(
                            child: ValueListenableBuilder<String?>(
                              valueListenable: StorageService.appBackgroundPathNotifier,
                              builder: (context, backgroundPath, child) {
                                final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
                                final buttonColor = hasBackground
                                    ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                                    : Theme.of(context).colorScheme.surfaceContainerHighest;

                                return TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: _onClearHistory,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: buttonColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Очистить историю',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayedTracksHistory(List<Track> history) {
    if (history.isEmpty) {
      return AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) => Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideUpAnimation.value),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.queue_music,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Начните искать музыку',
                    style: AppTextStyles.bodySecondary.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) => Opacity(
        opacity: _fadeAnimation.value,
        child: Transform.translate(
          offset: Offset(0, _slideUpAnimation.value),
          child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 1).copyWith(bottom: 80),
            itemCount: history.length,
            addAutomaticKeepAlives: true,
            addRepaintBoundaries: true,
            cacheExtent: 500.0,
            itemBuilder: (context, index) {
              final track = history[index];
              return TrackListItem(
                track: track,
                onTap: () => _onHistoryTrackTap(track),
                onLike: () {
                  context.read<MusicBloc>().add(MusicTrackLiked(track.id, track));
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(MusicState state) {
    Widget content;

    if (state.searchStatus == MusicLoadStatus.loading) {
      content = const Center(
        child: CircularProgressIndicator(),
      );
    } else if (state.searchStatus == MusicLoadStatus.failure) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Ошибка поиска',
              style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            Text(
              'Попробуйте ещё раз',
              style: AppTextStyles.bodySecondary,
            ),
          ],
        ),
      );
    } else if (state.searchResults.isEmpty && _currentQuery.isNotEmpty) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Попробуйте изменить запрос',
              style: AppTextStyles.bodySecondary,
            ),
          ],
        ),
      );
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12).copyWith(bottom: 80),
        itemCount: state.searchResults.length,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        cacheExtent: 500.0,
        itemBuilder: (context, index) {
          final track = state.searchResults[index];
          return TrackListItem(
            track: track,
            onTap: () => _onTrackTap(track),
            onLike: () {
              context.read<MusicBloc>().add(MusicTrackLiked(track.id, track));
            },
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) => Opacity(
        opacity: _fadeAnimation.value,
        child: Transform.translate(
          offset: Offset(0, _slideUpAnimation.value),
          child: content,
        ),
      ),
    );
  }
}
