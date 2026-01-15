/// Экран детальной информации об артисте
///
/// Отображает полную информацию об артисте с красивым дизайном,
/// анимациями и Material Design 3 компонентами.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../theme/app_text_styles.dart';
import '../../../services/storage_service.dart';
import '../../../core/widgets/app_background.dart';
import '../domain/models/track.dart';
import '../domain/models/album.dart';
import '../domain/models/artist_detail.dart';
import '../presentation/blocs/music_bloc.dart';
import '../presentation/blocs/music_event.dart';
import '../presentation/blocs/music_state.dart';
import '../presentation/blocs/queue_bloc.dart';
import '../presentation/blocs/queue_event.dart';
import 'track_list_item.dart';

/// Экран артиста с параллакс эффектом и анимациями
class ArtistScreen extends StatefulWidget {
  final int artistId;

  const ArtistScreen({
    super.key,
    required this.artistId,
  });

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideUpAnimation;

  final ScrollController _scrollController = ScrollController();
  late AnimationController _bioAnimationController;
  late Animation<double> _bioFadeAnimation;
  late Animation<Offset> _bioSlideAnimation;
  bool _showBio = false;

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

    _bioAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _bioFadeAnimation = CurvedAnimation(
      parent: _bioAnimationController,
      curve: Curves.easeOut,
    );

    _bioSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bioAnimationController,
      curve: Curves.easeOut,
    ));

    // Start animation and load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      // Загрузка данных артиста
      if (mounted) {
        context.read<MusicBloc>().add(MusicArtistDetailsFetched(widget.artistId));
        context.read<MusicBloc>().add(MusicArtistAlbumsFetched(widget.artistId));
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    _bioAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Загрузка следующей страницы при приближении к концу
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 300) {
      final state = context.read<MusicBloc>().state;
      if (state.artistTracksHasNextPage && 
          state.artistDetailsStatus != MusicLoadStatus.loading) {
        context.read<MusicBloc>().add(MusicArtistTracksLoadMore(widget.artistId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicBloc, MusicState>(
      builder: (context, state) {
        if (state.artistDetailsStatus == MusicLoadStatus.loading &&
            state.currentArtist == null) {
          return _buildLoadingState();
        }

        if (state.artistDetailsStatus == MusicLoadStatus.failure &&
            state.currentArtist == null) {
          return _buildErrorState();
        }

        final artist = state.currentArtist;
        if (artist == null) {
          return _buildEmptyState();
        }

        return _buildContent(artist, state);
      },
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: Shimmer.fromColors(
                  baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  highlightColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(5, (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Shimmer.fromColors(
                      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      highlightColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Популярные',
                style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  context.read<MusicBloc>().add(
                    MusicArtistDetailsFetched(widget.artistId, forceRefresh: true),
                  );
                },
                child: Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Text(
            'Артист не найден',
            style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ArtistDetail artist, MusicState state) {
    final imageUrl = ImageUtils.getCompleteImageUrl(artist.avatarUrl);
    final hasBackground = StorageService.appBackgroundPathNotifier.value != null &&
        StorageService.appBackgroundPathNotifier.value!.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // AppBackground as bottom layer
        AppBackground(fallbackColor: Theme.of(context).colorScheme.surface),

        // Main content
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) => Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _slideUpAnimation.value),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Hero header с параллакс эффектом (теперь как обычный sliver)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 350,
                      child: _buildHeroHeader(imageUrl, artist, hasBackground),
                    ),
                  ),

                  // Контент
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Жанры
                        if (artist.genres.isNotEmpty)
                          _buildGenresSection(artist.genres, hasBackground),

                        // Биография (показывается над альбомами при нажатии на кнопку инфо)
                        if (artist.bio.isNotEmpty)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _showBio
                                ? FadeTransition(
                                    opacity: _bioFadeAnimation,
                                    child: SlideTransition(
                                      position: _bioSlideAnimation,
                                      child: _buildBioSection(artist.bio, hasBackground),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                        // Альбомы
                        _buildAlbumsSection(state.artistAlbums, hasBackground),

                        // Популярные треки
                        _buildPopularTracksSection(state.artistPopularTracks, state),

                        // Заголовок треков
                        _buildTracksHeader(artist.tracksCount, hasBackground),

                        // Список треков
                        _buildTracksList(artist.tracks, state, hasBackground),
                      ],
                    ),
                  ),

                  // Индикатор загрузки следующей страницы
                  if (state.artistDetailsStatus == MusicLoadStatus.loading &&
                      artist.tracks.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),

                  // Отступ снизу
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
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
                                    Flexible(
                                      child: Text(
                                        artist.name,
                                        style: AppTextStyles.postAuthor.copyWith(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildHeroHeader(String? imageUrl, ArtistDetail artist, bool hasBackground) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Фоновое изображение
        if (imageUrl != null && imageUrl.isNotEmpty)
          Hero(
            tag: 'artist_${artist.id}',
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 800,
              memCacheHeight: 800,
              maxWidthDiskCache: 1600,
              maxHeightDiskCache: 1600,
              placeholder: (context, url) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.person,
                  size: 100,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.person,
              size: 100,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

        // Градиентный overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.7),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Информация об артисте
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        artist.name,
                        style: AppTextStyles.h1.copyWith(
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Социальные ссылки справа от имени
                    if (artist.instagram != null ||
                        artist.facebook != null ||
                        artist.twitter != null ||
                        artist.website != null)
                      ..._buildSocialIcons(artist),
                    if (artist.verified)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.dynamicPrimaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.verified,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (artist.tracksCount > 0)
                      Flexible(
                        child: Text(
                          '${artist.tracksCount} ${_getTracksWord(artist.tracksCount)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    // Кнопка инфо справа от числа треков
                    if (artist.bio.isNotEmpty)
                      Material(
                        color: Colors.transparent,
                        
                        child: InkWell(
                          
                          onTap: () {
                            setState(() {
                              _showBio = !_showBio;
                              if (_showBio) {
                                _bioAnimationController.forward();
                              } else {
                                _bioAnimationController.reverse();
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(9),

                            decoration: BoxDecoration(
                              color: _showBio 
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              _showBio ? Icons.info : Icons.info_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSocialIcons(ArtistDetail artist) {
    final links = <MapEntry<String, String?>>[
      MapEntry('instagram', artist.instagram),
      MapEntry('facebook', artist.facebook),
      MapEntry('twitter', artist.twitter),
      MapEntry('website', artist.website),
    ].where((e) => e.value != null && e.value!.isNotEmpty).toList();

    if (links.isEmpty) return [];

    final accentColor = context.dynamicPrimaryColor;

    return links.map((link) {
      String? iconPath;
      IconData? fallbackIcon;
      
      switch (link.key) {
        case 'instagram':
          iconPath = 'lib/assets/icons/social_icons/instagram.svg';
          break;
        case 'facebook':
          iconPath = 'lib/assets/icons/social_icons/facebook.svg';
          break;
        case 'twitter':
          iconPath = 'lib/assets/icons/social_icons/twitter.svg';
          break;
        case 'website':
          fallbackIcon = Icons.language;
          break;
        default:
          fallbackIcon = Icons.link;
      }

      return Container(
        margin: const EdgeInsets.only(left: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _launchUrl(link.value!),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: iconPath != null
                  ? SvgPicture.asset(
                      iconPath,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        accentColor,
                        BlendMode.srcIn,
                      ),
                    )
                  : Icon(
                      fallbackIcon ?? Icons.link,
                      color: accentColor,
                      size: 20,
                    ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildBioSection(String bio, bool hasBackground) {
    final cardColor = hasBackground
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
        : Theme.of(context).colorScheme.surfaceContainerLow;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'О исполнителе',
                style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 12),
              Text(
                bio,
                style: AppTextStyles.bodyMedium.copyWith(
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenresSection(List<String> genres, bool hasBackground) {
    final cardColor = hasBackground
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
        : Theme.of(context).colorScheme.surfaceContainerLow;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Жанры',
                style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: genres.map((String genre) {
                  return Chip(
                    label: Text(genre),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTracksHeader(int tracksCount, bool hasBackground) {
    final cardColor = hasBackground
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
        : Theme.of(context).colorScheme.surfaceContainerLow;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                'Треки',
                style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
              const Spacer(),
              Text(
                '$tracksCount',
                style: AppTextStyles.bodySecondary.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTracksList(List<Track> tracks, MusicState state, bool hasBackground) {
    if (tracks.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Треки не найдены',
            style: AppTextStyles.bodySecondary.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: TrackListItem(
            key: ValueKey(tracks[index].id),
            track: tracks[index],
            onTap: () => _onTrackPlay(tracks[index], tracks),
            onLike: () => _onTrackLike(tracks[index]),
          ),
        );
      },
    );
  }

  void _onTrackPlay(Track track, List<Track> allTracks) {
    try {
      final trackIndex = allTracks.indexWhere((t) => t.id == track.id);
      if (trackIndex != -1) {
        context.read<QueueBloc>().add(
          QueuePlayTracksRequested(allTracks, 'artist_${widget.artistId}', startIndex: trackIndex),
        );
      }
    } catch (e) {
      // Ошибка
    }
  }

  void _onTrackLike(Track track) {
    try {
      context.read<MusicBloc>().add(MusicTrackLiked(track.id, track));
    } catch (e) {
      // Ошибка
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      
      // Проверяем, может ли URL быть запущен
      bool canLaunch = false;
      try {
        canLaunch = await canLaunchUrl(uri);
      } catch (e) {
        // Если canLaunchUrl не работает, попробуем запустить напрямую
        debugPrint('Error checking if URL can be launched: $e');
      }
      
      // Если URL может быть запущен, запускаем его
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Попробуем запустить напрямую, даже если canLaunchUrl вернул false
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('Error launching URL: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _launchUrl: $e');
      // Не показываем ошибку пользователю, просто логируем
    }
  }

  String _getTracksWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'трек';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return 'трека';
    }
    return 'треков';
  }

  Widget _buildAlbumsSection(List<Album> albums, bool hasBackground) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Альбомы',
              style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          SizedBox(
            height: 180,
            child: albums.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Альбомы не найдены',
                        style: AppTextStyles.bodySecondary.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    cacheExtent: 1000,
                    addAutomaticKeepAlives: true,
                    addRepaintBoundaries: true,
                    itemCount: albums.length,
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      return _buildAlbumCard(album, hasBackground, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(Album album, bool hasBackground, int index) {
    // Используем coverUrl напрямую, так как он может быть полным URL или относительным путем
    final coverUrl = album.coverUrl ?? album.coverPath;
    // Для относительных путей /static/music/... используем s3.k-connect.ru вместо k-connect.ru
    String? imageUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      if (coverUrl.startsWith('http')) {
        imageUrl = coverUrl;
      } else if (coverUrl.startsWith('/static/music/')) {
        // Относительные пути для музыки должны идти на s3.k-connect.ru
        imageUrl = 'https://s3.k-connect.ru$coverUrl';
      } else {
        imageUrl = ImageUtils.getCompleteImageUrl(coverUrl);
      }
    }
    
    if (kDebugMode && imageUrl != null) {
      debugPrint('Album $index (${album.id}): coverUrl=$coverUrl, imageUrl=$imageUrl');
    }

    return GestureDetector(
      key: ValueKey('album_${album.id}_$index'),
      onTap: () {
        // TODO: Navigate to album details
        debugPrint('Tapped album: ${album.title}');
      },
      child: Container(
        key: ValueKey('album_container_${album.id}_$index'),
        width: 160,
        height: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Обложка альбома
              imageUrl != null && imageUrl.isNotEmpty
                  ? RepaintBoundary(
                      key: ValueKey('album_image_${album.id}_$index'),
                      child: CachedNetworkImage(
                        key: ValueKey('cached_image_${album.id}_$index'),
                        imageUrl: imageUrl,
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                        memCacheWidth: 320,
                        memCacheHeight: 320,
                        maxWidthDiskCache: 640,
                        maxHeightDiskCache: 640,
                        fadeInDuration: const Duration(milliseconds: 200),
                        fadeOutDuration: const Duration(milliseconds: 100),
                        placeholder: (context, url) {
                          if (kDebugMode) {
                            debugPrint('Loading album image $index: $url');
                          }
                          return Container(
                            width: 160,
                            height: 160,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorWidget: (context, url, error) {
                          debugPrint('Error loading album image $index (${album.id}): $url');
                          debugPrint('  Original coverUrl: ${album.coverUrl}');
                          debugPrint('  Original coverPath: ${album.coverPath}');
                          debugPrint('  Final imageUrl: $imageUrl');
                          debugPrint('  Error: $error');
                          return Container(
                            width: 160,
                            height: 160,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.album,
                              size: 50,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    )
                  : Container(
                      width: 160,
                      height: 160,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.album,
                        size: 50,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
              // Градиент для читаемости текста
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Название альбома и количество треков
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${album.tracksCount} ${_getTracksWord(album.tracksCount)}',
                        style: AppTextStyles.bodySecondary.copyWith(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.9),
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularTracksSection(List<Track> tracks, MusicState state) {
    final hasBackground = StorageService.appBackgroundPathNotifier.value != null &&
        StorageService.appBackgroundPathNotifier.value!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4,bottom: 12),
            child: Text(
              'Популярные',
              style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          SizedBox(
            height: 80,
            child: state.artistPopularTracksStatus == MusicLoadStatus.loading && tracks.isEmpty
                ? _buildPopularTracksShimmer()
                : tracks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Популярные треки не найдены',
                            style: AppTextStyles.bodySecondary.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        itemCount: tracks.length,
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          return _buildPopularTrackCard(track, state, hasBackground, index);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularTracksShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          width: 280,
          margin: EdgeInsets.only(
            left: index == 0 ? 0 : 12,
            right: 12,
          ),
          child: Shimmer.fromColors(
            baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            highlightColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopularTrackCard(Track track, MusicState state, bool hasBackground, int index) {
    final cardColor = hasBackground
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
        : Theme.of(context).colorScheme.surfaceContainerLow;
    final imageUrl = ImageUtils.getCompleteImageUrl(track.coverPath);

    return Container(
      width: 280,
      margin: EdgeInsets.only(
        left: index == 0 ? 0 : 0,
        right: 0,
      ),
      child: Card(
        color: cardColor,
        child: InkWell(
          onTap: () => _onTrackPlay(track, state.currentArtist?.tracks ?? []),
          borderRadius: BorderRadius.circular(12),
              child: Row(
            children: [
              // Обложка
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: ImageUtils.buildAlbumArt(
                  imageUrl,
                  context,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              // Информация
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        track.title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${track.playsCount} прослушиваний',
                        style: AppTextStyles.bodySecondary.copyWith(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
