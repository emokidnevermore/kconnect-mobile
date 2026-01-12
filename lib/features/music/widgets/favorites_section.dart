/// Виджет секции избранных треков
///
/// Отображает список любимых треков пользователя с поддержкой
/// бесконечной прокрутки, пагинации и воспроизведения.
/// Включает состояния загрузки, ошибки и пустого списка.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../theme/app_text_styles.dart';
import '../../../services/cache/audio_preload_service.dart';
import '../domain/models/track.dart';
import '../presentation/blocs/queue_bloc.dart';
import '../presentation/blocs/queue_event.dart';
import '../presentation/blocs/music_bloc.dart';
import '../presentation/blocs/music_event.dart';
import '../presentation/blocs/music_state.dart';

import 'track_list_item.dart';

/// Виджет секции избранных треков с бесконечной прокруткой
class FavoritesSection extends StatefulWidget {
  const FavoritesSection({super.key});

  @override
  State<FavoritesSection> createState() => _FavoritesSectionState();
}

class _FavoritesSectionState extends State<FavoritesSection> {
  final ScrollController _scrollController = ScrollController();
  final AudioPreloadService _preloadService = AudioPreloadService.instance;
  int _lastPreloadedEndIndex = -1;

  /// Инициализация виджета
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Загрузка данных при открытии секции
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final musicBloc = context.read<MusicBloc>();
        if (musicBloc.state.favorites.isEmpty && musicBloc.state.favoritesStatus == MusicLoadStatus.initial) {
          musicBloc.add(MusicFavoritesFetched());
        } else {
          // Предзагружаем первые видимые треки
          _preloadVisibleTracks();
        }
      }
    });
  }

  /// Освобождение ресурсов
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Обработчик прокрутки для бесконечной загрузки
  void _onScroll() {
    // Предзагрузка видимых треков
    _preloadVisibleTracks();

    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final musicBloc = context.read<MusicBloc>();
      if (musicBloc.state.favoritesHasNextPage && musicBloc.state.favoritesStatus != MusicLoadStatus.loading) {
        musicBloc.add(MusicFavoritesLoadMore());
      }
    }
  }

  /// Предзагружает видимые треки
  void _preloadVisibleTracks() {
    final musicBloc = context.read<MusicBloc>();
    final state = musicBloc.state;
    
    if (state.favorites.isEmpty) return;

    // Вычисляем видимые индексы на основе позиции прокрутки
    const itemHeight = 80.0;
    final scrollOffset = _scrollController.position.pixels;
    final viewportHeight = _scrollController.position.viewportDimension;
    
    final startIndex = (scrollOffset / itemHeight).floor();
    final endIndex = ((scrollOffset + viewportHeight) / itemHeight).ceil() + 3;
    
    final clampedStart = startIndex.clamp(0, state.favorites.length);
    final clampedEnd = endIndex.clamp(0, state.favorites.length);
    
    // Предзагружаем только если диапазон изменился
    if (clampedEnd > _lastPreloadedEndIndex) {
      _preloadService.preloadVisibleTracks(
        state.favorites,
        clampedStart,
        clampedEnd,
      );
      _lastPreloadedEndIndex = clampedEnd;
    }
  }

  /// Построение виджета с реакцией на изменения состояния
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicBloc, MusicState>(
      builder: (context, state) {
        return _buildContent(state);
      },
    );
  }

  /// Построение содержимого в зависимости от состояния загрузки
  Widget _buildContent(MusicState state) {
    if (state.favoritesStatus == MusicLoadStatus.loading && state.favorites.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.favoritesStatus == MusicLoadStatus.failure && state.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                context.read<MusicBloc>().add(MusicFavoritesFetched());
              },
              child: Text(
                'Повторить',
                style: AppTextStyles.bodyMedium.copyWith(color: context.dynamicPrimaryColor),
              ),
            ),
          ],
        ),
      );
    }

    if (state.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'У вас пока нет любимых треков',
              style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<MusicBloc>().add(MusicFavoritesFetched(forceRefresh: true));
      },
      color: context.dynamicPrimaryColor,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Отступ сверху под хедер
          const SliverToBoxAdapter(
            child: SizedBox(height: 52),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == state.favorites.length) {
                  // Индикатор загрузки в конце списка
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final track = state.favorites[index];
                return TrackListItem(
                  key: ValueKey(track.id),
                  track: track,
                  onTap: () => _onTrackPlay(track, state.favorites),
                  onLike: () => _onTrackLike(track),
                );
              },
              childCount: state.favorites.length + (state.favoritesHasNextPage ? 1 : 0),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  /// Обработчик воспроизведения трека
  ///
  /// Создает очередь с избранными треками и начинает воспроизведение выбранного трека
  /// Воспроизведение запускается автоматически через MediaPlayerService
  void _onTrackPlay(Track track, List<Track> allTracks) {
    try {
      // Создание очереди с избранными треками
      // Воспроизведение запустится автоматически через MediaPlayerService
      // когда очередь синхронизируется с audio_service
      final trackIndex = allTracks.indexWhere((t) => t.id == track.id);
      if (trackIndex != -1) {
        context.read<QueueBloc>().add(QueuePlayTracksRequested(allTracks, 'favorites', startIndex: trackIndex));
      }
    } catch (e) {
      // Обработка ошибки без показа пользователю
    }
  }

  /// Обработчик снятия лайка с трека
  ///
  /// Отправляет событие снятия лайка с трека в MusicBloc для обновления состояния
  void _onTrackLike(Track track) {
    try {
      context.read<MusicBloc>().add(MusicTrackLiked(track.id, track));
    } catch (e) {
      // Обработка ошибки без показа пользователю
    }
  }
}
