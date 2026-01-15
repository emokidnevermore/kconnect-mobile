import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../theme/app_text_styles.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/theme/presentation/blocs/theme_bloc.dart';
import '../../core/theme/presentation/blocs/theme_state.dart';
import 'widgets/section_list.dart';
import 'widgets/charts_section.dart';
import 'widgets/vibe_animated_card.dart';
import 'widgets/music_navigation_card.dart';
import 'widgets/favorites_screen.dart';
import 'widgets/playlists_screen.dart';
import 'widgets/all_tracks_screen.dart';

import 'widgets/artists_section.dart';
import 'widgets/artist_screen.dart';
import './domain/models/track.dart';
import './domain/models/artist.dart';
import './presentation/blocs/queue_bloc.dart';
import './domain/repositories/audio_repository.dart';
import '../../injection.dart';
import './presentation/blocs/queue_event.dart';
import './presentation/blocs/music_bloc.dart';
import './presentation/blocs/music_event.dart';
import './presentation/blocs/music_state.dart';
import '../../services/storage_service.dart';


enum MusicSection { home, favorites, playlists, allTracks, artist }

class MusicHome extends StatefulWidget {
  final ValueNotifier<MusicSection>? sectionController;

  const MusicHome({super.key, this.sectionController});

  @override
  State<MusicHome> createState() => _MusicHomeState();
}

class _MusicHomeState extends State<MusicHome> with AutomaticKeepAliveClientMixin {
  MusicSection currentSection = MusicSection.home;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.sectionController?.addListener(_onSectionControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final musicBloc = context.read<MusicBloc>();
        musicBloc.add(MusicMyVibeFetched());
        musicBloc.add(MusicPopularFetched());
        musicBloc.add(MusicChartsFetched());
        musicBloc.add(MusicRecommendedArtistsFetched());
      }
    });
  }

  @override
  void dispose() {
    widget.sectionController?.removeListener(_onSectionControllerChanged);
    super.dispose();
  }

  void _onSectionControllerChanged() {
    setState(() => currentSection = widget.sectionController?.value ?? MusicSection.home);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    switch (currentSection) {
      case MusicSection.home:
        return _buildHomeSection();
      default:
        return _buildHomeSection();
    }
  }

  Widget _buildHomeSection() {
    return SizedBox.expand(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              final musicBloc = context.read<MusicBloc>();
              musicBloc.add(MusicPopularFetched(forceRefresh: true));
              musicBloc.add(MusicChartsFetched(forceRefresh: true));
            },
            color: context.dynamicPrimaryColor,
            child: CustomScrollView(
              slivers: [
                // Отступ сверху под хедер
                const SliverToBoxAdapter(
                  child: SizedBox(height: 40),
                ),
                SliverToBoxAdapter(
                  child: VibeAnimatedCard(
                    onPressed: _onVibeTap,
                  ),
                ),
                // Маленький отступ только между вайбом и кнопками любимых/плейлистов
                const SliverToBoxAdapter(
                  child: SizedBox(height: 4),
                ),
                SliverToBoxAdapter(
                  child: BlocBuilder<ThemeBloc, ThemeState>(
                    builder: (context, state) {
                      return MusicNavigationCardsRow(
                        leftCard: MusicNavigationCard(
                          title: 'Любимые',
                          icon: Icons.favorite,
                          onPressed: _onFavoritesTap,
                        ),
                        rightCard: MusicNavigationCard(
                          title: 'Плейлисты',
                          icon: Icons.album,
                          onPressed: _onPlaylistsTap,
                        ),
                      );
                    },
                  ),
                ),
                // Равные вертикальные отступы между основными секциями
                const SliverToBoxAdapter(
                  child: SizedBox(height: 2),
                ),
                SliverToBoxAdapter(
                  child: ValueListenableBuilder<String?>(
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
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Популярные треки',
                                  style: AppTextStyles.h3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              BlocBuilder<MusicBloc, MusicState>(
                                builder: (context, state) {
                                  return SectionList(
                                    items: state.popularTracks,
                                    status: state.popularStatus,
                                    onTrackTap: (track) => _onTrackPlay(track, queueContext: 'popular', allTracks: state.popularTracks),
                                    onTrackLike: (track) => _onTrackLike(track, context),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 8),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    child: BlocBuilder<ThemeBloc, ThemeState>(
                      builder: (context, state) {
                        return _buildRectangleCard(
                          'Все треки',
                          Icons.queue_music,
                          () => _onAllTracksTap(),
                          color: context.dynamicPrimaryColor,
                          textPosition: TextAlign.left,
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 8),
                ),
                SliverToBoxAdapter(
                  child: ChartsSection(
                    onTrackTap: (track, chartType, allTracks) => _onTrackPlay(track, queueContext: chartType, allTracks: allTracks),
                    onTrackLike: (track) => _onTrackLike(track, context),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 8),
                ),
                SliverToBoxAdapter(
                  child: ValueListenableBuilder<String?>(
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
                          padding: const EdgeInsets.only(top: 16, bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Исполнители',
                                  style: AppTextStyles.h3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              BlocBuilder<MusicBloc, MusicState>(
                                builder: (context, state) {
                                  return ArtistsSection(
                                    items: state.recommendedArtists,
                                    status: state.recommendedArtistsStatus,
                                    onArtistTap: (artist) => _onArtistTap(artist),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: const SizedBox(height: 75),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }













  Widget _buildRectangleCard(String title, IconData icon, VoidCallback onTap, {required Color color, TextAlign textPosition = TextAlign.center}) {
    return ValueListenableBuilder<String?>(
      valueListenable: StorageService.appBackgroundPathNotifier,
      builder: (context, backgroundPath, child) {
        final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
        final cardColor = hasBackground 
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
            : Theme.of(context).colorScheme.surfaceContainerLow;
        
        return Card(
          margin: EdgeInsets.zero,
          color: cardColor,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      icon,
                      size: 24,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.button,
                      textAlign: textPosition,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onVibeTap() {
    try {
      final musicBloc = context.read<MusicBloc>();
      final vibeTracks = musicBloc.state.vibeTracks;

      if (vibeTracks.isNotEmpty) {
        // Создание очереди - воспроизведение запустится автоматически через MediaPlayerService
        context.read<QueueBloc>().add(QueuePlayTracksRequested(vibeTracks, 'vibe', startIndex: 0));
      }
    } catch (e) {
      // Ошибка
    }
  }

  void _onFavoritesTap() {
    final musicBloc = context.read<MusicBloc>();
    musicBloc.add(MusicFavoritesFetched());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FavoritesScreen(),
      ),
    );
  }

  void _onPlaylistsTap() {
    final musicBloc = context.read<MusicBloc>();
    musicBloc.add(MusicMyPlaylistsFetched());
    musicBloc.add(MusicPublicPlaylistsFetched());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PlaylistsScreen(),
      ),
    );
  }

  void _onAllTracksTap() {
    final musicBloc = context.read<MusicBloc>();
    musicBloc.add(MusicAllTracksPaginatedFetched());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AllTracksScreen(),
      ),
    );
  }

  void _onTrackPlay(Track track, {String? queueContext, List<Track>? allTracks}) {
    try {
      if (allTracks != null && allTracks.isNotEmpty) {
        final trackIndex = allTracks.indexWhere((t) => t.id == track.id);
        if (trackIndex != -1) {
          // Создаем очередь - синхронизация и воспроизведение произойдут автоматически
          context.read<QueueBloc>().add(QueuePlayTracksRequested(allTracks, queueContext ?? 'unknown', startIndex: trackIndex));
        }
      } else {
        // Если нет списка треков, используем старый способ (один трек)
        final audioRepository = locator<AudioRepository>();
        audioRepository.playTrack(track).catchError((e) {
          debugPrint('MusicHome: Error playing track: $e');
        });
      }
    } catch (e) {
      // Ошибка
    }
  }

  void _onTrackLike(Track track, BuildContext context) async {
    try {
      context.read<MusicBloc>().add(MusicTrackLiked(track.id, track));
    } catch (e) {
      // Ошибка
    }
  }

  void _onArtistTap(Artist artist) {
    final musicBloc = context.read<MusicBloc>();
    musicBloc.add(MusicArtistDetailsFetched(artist.id));
    musicBloc.add(MusicArtistAlbumsFetched(artist.id));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArtistScreen(artistId: artist.id),
      ),
    );
  }


}
