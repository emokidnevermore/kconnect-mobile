/// Экран любимых треков
///
/// Полноэкранный интерфейс для просмотра любимых треков пользователя.
/// Использует анимации аналогично полноэкранному редактированию профиля.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/core/widgets/app_background.dart';
import 'package:kconnect_mobile/services/storage_service.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/services/cache/audio_preload_service.dart';
import '../domain/models/track.dart';
import '../presentation/blocs/queue_bloc.dart';
import '../presentation/blocs/queue_event.dart';
import '../presentation/blocs/music_bloc.dart';
import '../presentation/blocs/music_event.dart';
import '../presentation/blocs/music_state.dart';
import 'track_list_item.dart';

/// Виджет полноэкранного просмотра любимых треков
///
/// Анимируется аналогично ProfileEditScreen с fade и slide up эффектами.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideUpAnimation;

  final ScrollController _scrollController = ScrollController();
  final AudioPreloadService _preloadService = AudioPreloadService.instance;
  int _lastPreloadedEndIndex = -1;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

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

    // Start animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      // Загрузка данных при открытии секции
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

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
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
          body: Stack(
            children: [
              // Content
              SafeArea(
                bottom: true,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) => Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideUpAnimation.value),
                      child: BlocBuilder<MusicBloc, MusicState>(
                        builder: (context, state) => _buildContent(state),
                      ),
                    ),
                  ),
                ),
              ),

              // Header positioned above content
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) => Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideUpAnimation.value),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
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
                                            'Любимые',
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
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
