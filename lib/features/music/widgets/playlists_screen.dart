/// Экран плейлистов
///
/// Полноэкранный интерфейс для просмотра плейлистов пользователя.
/// Использует анимации аналогично полноэкранному редактированию профиля.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/core/widgets/app_background.dart';
import 'package:kconnect_mobile/services/storage_service.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import '../domain/models/playlist.dart';
import '../presentation/blocs/music_bloc.dart';
import '../presentation/blocs/music_event.dart';
import '../presentation/blocs/music_state.dart';
import 'playlist_card.dart';

/// Виджет полноэкранного просмотра плейлистов
///
/// Анимируется аналогично ProfileEditScreen с fade и slide up эффектами.
class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideUpAnimation;

  final ScrollController _scrollController = ScrollController();

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
      // Загрузка данных при открытии экрана
      if (mounted) {
        final musicBloc = context.read<MusicBloc>();
        musicBloc.add(MusicMyPlaylistsFetched());
        musicBloc.add(MusicPublicPlaylistsFetched());
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Load more for my playlists - disabled for now
      // if (state.myPlaylistsHasNextPage && state.myPlaylistsStatus != MusicLoadStatus.loading) {
      //   musicBloc.add(const MusicMyPlaylistsLoadMore());
      // }

      // Load more for public playlists - disabled for now
      // if (state.publicPlaylistsHasNextPage && state.publicPlaylistsStatus != MusicLoadStatus.loading) {
      //   musicBloc.add(const MusicPublicPlaylistsLoadMore());
      // }
    }
  }

  /// Построение содержимого в зависимости от состояния загрузки
  Widget _buildContent(MusicState state) {
    if (state.myPlaylistsStatus == MusicLoadStatus.loading && state.myPlaylists.isEmpty &&
        state.publicPlaylistsStatus == MusicLoadStatus.loading && state.publicPlaylists.isEmpty) {
      return Center(
        child: const CircularProgressIndicator(),
      );
    }

    if (state.myPlaylistsStatus == MusicLoadStatus.failure && state.myPlaylists.isEmpty &&
        state.publicPlaylistsStatus == MusicLoadStatus.failure && state.publicPlaylists.isEmpty) {
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
                context.read<MusicBloc>().add(MusicMyPlaylistsFetched());
                context.read<MusicBloc>().add(MusicPublicPlaylistsFetched());
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

    return RefreshIndicator(
      onRefresh: () async {
        context.read<MusicBloc>().add(MusicMyPlaylistsFetched(forceRefresh: true));
        context.read<MusicBloc>().add(MusicPublicPlaylistsFetched(forceRefresh: true));
      },
      color: context.dynamicPrimaryColor,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Отступ сверху под хедер
          const SliverToBoxAdapter(
            child: SizedBox(height: 52),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Мои плейлисты',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),

          if (state.myPlaylists.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.myPlaylists.length + (state.myPlaylistsHasNextPage ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.myPlaylists.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final playlist = state.myPlaylists[index];
                    return PlaylistCard(
                      key: ValueKey(playlist.id),
                      playlist: playlist,
                      onTap: () => _onPlaylistTap(playlist),
                    );
                  },
                ),
              ),
            ),

          if (state.myPlaylists.isEmpty && state.myPlaylistsStatus != MusicLoadStatus.loading)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Text(
                  'У вас пока нет плейлистов',
                  style: AppTextStyles.bodySecondary.copyWith(color: Theme.of(context).colorScheme.onSurface),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          if (state.publicPlaylists.isNotEmpty || state.publicPlaylistsStatus == MusicLoadStatus.loading)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Публичные плейлисты',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),

          if (state.publicPlaylists.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.publicPlaylists.length + (state.publicPlaylistsHasNextPage ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.publicPlaylists.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final playlist = state.publicPlaylists[index];
                    return PlaylistCard(
                      key: ValueKey(playlist.id),
                      playlist: playlist,
                      onTap: () => _onPlaylistTap(playlist),
                    );
                  },
                ),
              ),
            ),

          if (state.publicPlaylists.isEmpty && state.publicPlaylistsStatus != MusicLoadStatus.loading)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Text(
                  'Публичные плейлисты не найдены',
                  style: AppTextStyles.bodySecondary.copyWith(color: Theme.of(context).colorScheme.onSurface),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  void _onPlaylistTap(Playlist playlist) {
    // TODO: Навигация в подробности плейлиста
    debugPrint('Tapped playlist: ${playlist.name}');
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
                                            'Плейлисты',
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
