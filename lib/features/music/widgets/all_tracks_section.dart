/// Виджет секции всех треков
///
/// Отображает список всех доступных музыкальных треков с поддержкой
/// бесконечной прокрутки, пагинации и воспроизведения.
/// Включает состояния загрузки, ошибки и пустого списка.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../core/widgets/custom_refresh_indicator.dart';
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

/// Виджет секции всех треков с бесконечной прокруткой
class AllTracksSection extends StatefulWidget {
  const AllTracksSection({super.key});

  @override
  State<AllTracksSection> createState() => _AllTracksSectionState();
}

class _AllTracksSectionState extends State<AllTracksSection> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  DateTime? _lastLoadMoreTime;
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
        if (musicBloc.state.allTracks.isEmpty && musicBloc.state.allTracksStatus == MusicLoadStatus.initial) {
          musicBloc.add(MusicAllTracksPaginatedFetched());
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
    super.dispose();
  }

  /// Обработчик прокрутки для бесконечной загрузки
  void _onScroll() {
    // Throttling: предотвращение множественных вызовов в течение 300мс
    final now = DateTime.now();
    if (_lastLoadMoreTime != null &&
        now.difference(_lastLoadMoreTime!) < const Duration(milliseconds: 300)) {
      return;
    }

    // Предзагрузка видимых треков
    _preloadVisibleTracks();

    // Порог предварительной загрузки: начать загрузку за 300px от конца (против 200px)
    // Это дает больше времени для загрузки данных до того, как пользователь достигнет конца
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      final musicBloc = context.read<MusicBloc>();
      final state = musicBloc.state;

      // Предотвращение множественных запросов загрузки
      if (_isLoadingMore) return;

      if (state.allTracksHasNextPage &&
          state.allTracksStatus != MusicLoadStatus.loading) {
        _isLoadingMore = true;
        _lastLoadMoreTime = now;
        musicBloc.add(MusicAllTracksPaginatedLoadMore());

        // Сброс флага после задержки для разрешения новых запросов при необходимости
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _isLoadingMore = false;
          }
        });
      }
    }
  }

  /// Предзагружает видимые треки
  void _preloadVisibleTracks() {
    final musicBloc = context.read<MusicBloc>();
    final state = musicBloc.state;
    
    if (state.allTracks.isEmpty) return;

    // Вычисляем видимые индексы на основе позиции прокрутки
    // Приблизительно: каждый элемент ~80px высотой
    const itemHeight = 80.0;
    final scrollOffset = _scrollController.position.pixels;
    final viewportHeight = _scrollController.position.viewportDimension;
    
    final startIndex = (scrollOffset / itemHeight).floor();
    final endIndex = ((scrollOffset + viewportHeight) / itemHeight).ceil() + 3; // +3 для предзагрузки вперед
    
    final clampedStart = startIndex.clamp(0, state.allTracks.length);
    final clampedEnd = endIndex.clamp(0, state.allTracks.length);
    
    // Предзагружаем только если диапазон изменился
    if (clampedEnd > _lastPreloadedEndIndex) {
      _preloadService.preloadVisibleTracks(
        state.allTracks,
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
    if (state.allTracksStatus == MusicLoadStatus.loading && state.allTracks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.allTracksStatus == MusicLoadStatus.failure && state.allTracks.isEmpty) {
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
                context.read<MusicBloc>().add(MusicAllTracksPaginatedFetched());
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

    if (state.allTracks.isEmpty && state.allTracksStatus == MusicLoadStatus.success) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Треки не найдены',
              style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return CustomRefreshIndicator(
      onRefresh: () async {
        context.read<MusicBloc>().add(MusicAllTracksPaginatedFetched(forceRefresh: true));
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
                if (index == state.allTracks.length) {
                  // Индикатор загрузки в конце списка
                  return const ProgressiveLoadingIndicator(
                    message: 'Загрузка треков...',
                  );
                }

                final track = state.allTracks[index];
                return StaggeredListItem(
                  index: index,
                  child: TrackListItem(
                    key: ValueKey(track.id),
                    track: track,
                    onTap: () => _onTrackPlay(track, state.allTracks),
                    onLike: () => _onTrackLike(track),
                  ),
                );
              },
              childCount: state.allTracks.length + (state.allTracksHasNextPage ? 1 : 0),
              // Оптимизация производительности: сохранять элементы треков живыми при прокрутке
              addAutomaticKeepAlives: true,
              // Перерисовка отключена для лучшей производительности с большими списками
              addRepaintBoundaries: false,
              // Семантическая индексация отключена для доступности
              addSemanticIndexes: false,
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
  /// Создает очередь со всеми треками и начинает воспроизведение выбранного трека
  /// Воспроизведение запускается автоматически через MediaPlayerService
  void _onTrackPlay(Track track, List<Track> allTracks) {
    try {
      // Создание очереди со всеми треками
      // Воспроизведение запустится автоматически через MediaPlayerService
      // когда очередь синхронизируется с audio_service
      final trackIndex = allTracks.indexWhere((t) => t.id == track.id);
      if (trackIndex != -1) {
        context.read<QueueBloc>().add(QueuePlayTracksRequested(allTracks, 'allTracks', startIndex: trackIndex));
      }
    } catch (e) {
      // Обработка ошибки без показа пользователю
    }
  }

  /// Обработчик лайка трека
  ///
  /// Отправляет событие лайка трека в MusicBloc для обновления состояния
  void _onTrackLike(Track track) {
    try {
      context.read<MusicBloc>().add(MusicTrackLiked(track.id, track));
    } catch (e) {
      // Обработка ошибки без показа пользователю
    }
  }
}
