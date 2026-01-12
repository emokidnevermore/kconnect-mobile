/// Экран поиска музыкальных треков
///
/// Предоставляет интерфейс для поиска треков с debounced вводом.
/// Показывает историю прослушанных треков при отсутствии поиска.
/// Интегрируется с PlaybackBloc для воспроизведения найденных треков.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../theme/app_text_styles.dart';
import '../domain/models/track.dart';
import '../presentation/blocs/music_bloc.dart';
import '../presentation/blocs/music_event.dart';
import '../presentation/blocs/music_state.dart';
import '../domain/repositories/audio_repository.dart';
import '../../../../injection.dart';
import 'track_list_item.dart';

/// Экран поиска музыки с историей прослушиваний
///
/// Поддерживает поиск с задержкой, кэширование результатов поиска
/// и отображение истории прослушанных треков.
class MusicSearchScreen extends StatefulWidget {
  const MusicSearchScreen({super.key});

  @override
  State<MusicSearchScreen> createState() => _MusicSearchScreenState();
}

class _MusicSearchScreenState extends State<MusicSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    // Load played tracks history when screen opens
    context.read<MusicBloc>().add(MusicPlayedTracksHistoryLoaded());

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
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
    final audioRepository = locator<AudioRepository>();
    audioRepository.playTrack(track).catchError((e) {
      debugPrint('MusicSearchScreen: Error playing track: $e');
    });
  }

  void _onTrackTap(Track track) {
    // Play the track
    final audioRepository = locator<AudioRepository>();
    audioRepository.playTrack(track).catchError((e) {
      debugPrint('MusicSearchScreen: Error playing track: $e');
    });
    // Save track to played history
    context.read<MusicBloc>().add(MusicPlayedTrackSaved(track));
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Отступ сверху под хедер
                  const SizedBox(height: 46),
                  // Search field
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Введите название трека, артиста...',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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

            // Clear history button (only show when displaying history)
            if (_currentQuery.isEmpty)
              Positioned(
                bottom: 50,
                left: 16,
                right: 16,
                child: Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _onClearHistory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildPlayedTracksHistory(List<Track> history) {
    if (history.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 80),
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
    );
  }

  Widget _buildSearchResults(MusicState state) {
    if (state.searchStatus == MusicLoadStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.searchStatus == MusicLoadStatus.failure) {
      return Center(
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
    }

    if (state.searchResults.isEmpty && _currentQuery.isNotEmpty) {
      return Center(
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
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 80),
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
}
