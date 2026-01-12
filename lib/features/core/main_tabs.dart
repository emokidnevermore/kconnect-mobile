import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/features/feed/feed_screen.dart';
import 'package:kconnect_mobile/features/music/music_home.dart';
import 'package:kconnect_mobile/features/menu/menu_screen.dart';
import 'package:kconnect_mobile/features/messages/messages_screen.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_bloc.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_event.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_state.dart';
import 'package:kconnect_mobile/features/profile/my_profile_screen.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/core/widgets/app_header.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_event.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_state.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/account_bloc.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/account_event.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/account_state.dart';
import 'package:kconnect_mobile/features/auth/presentation/widgets/account_menu.dart';
import 'package:kconnect_mobile/features/feed/presentation/blocs/feed_bloc.dart';
import 'package:kconnect_mobile/features/feed/presentation/blocs/feed_event.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_bloc.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_event.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_state.dart';
import 'package:kconnect_mobile/features/music/presentation/blocs/music_bloc.dart';
import 'package:kconnect_mobile/features/music/presentation/blocs/music_event.dart';
import 'package:kconnect_mobile/features/music/presentation/blocs/music_state.dart';
import 'package:kconnect_mobile/features/music/presentation/blocs/queue_bloc.dart';
import 'package:kconnect_mobile/features/music/presentation/blocs/queue_event.dart';
import 'package:kconnect_mobile/core/theme/presentation/blocs/theme_bloc.dart';
import 'package:kconnect_mobile/core/theme/presentation/blocs/theme_event.dart';
import 'package:kconnect_mobile/services/storage_service.dart';
import 'package:kconnect_mobile/features/music/widgets/mini_player.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:kconnect_mobile/services/audio_service_manager.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:kconnect_mobile/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:kconnect_mobile/core/widgets/glass_mode_wrapper.dart';
import 'package:kconnect_mobile/features/notifications/presentation/bloc/notifications_event.dart';
import 'package:kconnect_mobile/features/notifications/presentation/widgets/notifications_section.dart';
import 'package:kconnect_mobile/routes/route_names.dart';
import 'package:kconnect_mobile/core/widgets/app_background.dart';

class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController(initialPage: 2);
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier(2);
  final ValueNotifier<bool> isTabAnimating = ValueNotifier(false);
  late AnimationController _tabBarAnimationController;
  late Animation<double> _tabBarOpacityAnimation;
  late Animation<double> _tabBarBottomAnimation;
  late final ValueNotifier<bool> feedScrolledDown = ValueNotifier(false);
  late final ValueNotifier<bool> scrollToTopRequested = ValueNotifier(false);
  late final List<Widget> _pages;
  final ValueNotifier<MusicSection> _musicSectionController = ValueNotifier(MusicSection.home);
  late final ValueNotifier<bool> _notificationsVisible;
  bool _isNotificationsOpen = false;
  final ValueNotifier<bool> _isMiniPlayerExpanded = ValueNotifier(false);


  @override
  void initState() {
    super.initState();
    _tabBarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Material 3 standard duration
    );

    _tabBarOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _tabBarAnimationController, curve: Curves.easeOutCubic) // Material 3 emphasized easing
    );
    _tabBarBottomAnimation = Tween<double>(begin: 16.0, end: -50.0).animate(
      CurvedAnimation(parent: _tabBarAnimationController, curve: Curves.easeOutCubic) // Material 3 emphasized easing
    );
    _notificationsVisible = ValueNotifier(false);

    _pages = [

      const MyProfileScreen(),

      MusicHome(
        sectionController: _musicSectionController,
      ),
      FeedScreen(
        isTabAnimating: isTabAnimating,
        onScrollChanged: _onFeedScrollChanged,
        scrollToTopRequested: scrollToTopRequested,
      ),


      const MessagesScreen(),
      const MenuScreen(),

    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.position.isScrollingNotifier.addListener(() {
        isTabAnimating.value = _pageController.position.isScrollingNotifier.value;
      });
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) {
        context.read<AuthBloc>().add(RefreshAuthEvent());
      }
      context.read<AccountBloc>().add(LoadAccountsEvent());
      context.read<NotificationsBloc>().add(const NotificationsStarted());
      context.read<MessagesBloc>().add(ConnectWebSocketEvent());
    });
  }

  @override
  void dispose() {
    _tabBarAnimationController.dispose();
    _notificationsVisible.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOutCubic); // Material 3 standard easing
  }

  void _onPageChanged(int index) {
    _currentIndexNotifier.value = index;
  }

  void _onFeedScrollChanged(bool scrolledDown) {
    feedScrolledDown.value = scrolledDown;
  }

  void _onMusicFavoritesBack() {
    _onTabTapped(1);
    _musicSectionController.value = MusicSection.home;
  }

  void _onMusicPlaylistsBack() {
    _onTabTapped(1);
    _musicSectionController.value = MusicSection.home;
  }

  void _onMusicAllTracksBack() {
    _onTabTapped(1);
    _musicSectionController.value = MusicSection.home;
  }

  void _onMusicSearchBack() {
    _onTabTapped(1);
    _musicSectionController.value = MusicSection.home;
  }

  void _onMusicArtistBack() {
    _onTabTapped(1);
    _musicSectionController.value = MusicSection.home;
  }




  IconData _getDynamicIcon() {
    switch (_currentIndexNotifier.value) {
      case 0:
        return Icons.add;
      case 1:
        return Icons.search;
      case 2:
        return feedScrolledDown.value ? Icons.arrow_upward : Icons.add;
      case 3:
        return Icons.edit;
      case 4:
        return Icons.person;
      default:
        return Icons.add;
    }
  }

  void _onDynamicButtonPressed() {
    // TODO: Реализовать действия для каждой вкладки - добавить навигацию к соответствующим экранам
    // Для каждой вкладки реализовать специфическое действие при нажатии на динамическую кнопку
    switch (_currentIndexNotifier.value) {
      case 0:
        // Профиль: редактирование??
        break;
      case 1:
        // Музыка: поиск +
        _onMusicSearchPressed();
        break;
      case 2:
        // Лента: новый пост или прокрутка вверх +-
        if (feedScrolledDown.value) {
          scrollToTopRequested.value = true;
        } else {
          // Навигация к созданию поста
          Navigator.of(context).pushNamed(RouteNames.createPost);
        }
        break;
      case 3:
        // Сообщения: новый чат
        Navigator.of(context).pushNamed(RouteNames.createChat);
        break;
      case 4:
        // Меню: мульти-аккаунт +
        _showAccountMenu();
        break;
    }
  }

  void _onMusicSearchPressed() {
    _onTabTapped(1);
    _musicSectionController.value = MusicSection.search;
  }

  void _showAccountMenu() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: const AccountMenu(),
      ),
    );
  }

  void _onTabBarToggle(bool hide) {
    _isMiniPlayerExpanded.value = hide;
    if (hide) {
      _tabBarAnimationController.forward();
    } else {
      _tabBarAnimationController.reverse();
    }
  }

  void _toggleNotifications([bool? visible]) {
    final nextValue = visible ?? !_notificationsVisible.value;
    setState(() {
      _notificationsVisible.value = nextValue;
      _isNotificationsOpen = nextValue;
    });
    if (nextValue) {
      context.read<NotificationsBloc>().add(const NotificationsStarted());
    }
  }

  void _onNotificationClose() {
    setState(() {
      _notificationsVisible.value = false;
      _isNotificationsOpen = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<MessagesBloc>()),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<AccountBloc, AccountState>(
            listener: (context, state) {
              // Триггер обновления данных (включая смену аккаунта)
              if (state is AccountLoaded && state.activeAccount != null) {
                context.read<FeedBloc>().add(RefreshFeedEvent());

                context.read<ProfileBloc>().add(RefreshProfileEvent());

                context.read<MusicBloc>().add(MusicMyVibeFetched());
                context.read<MusicBloc>().add(MusicPopularFetched());
                context.read<MusicBloc>().add(MusicChartsFetched());
                context.read<NotificationsBloc>().add(const NotificationsRefreshed());
              }
            },
          ),
          BlocListener<ProfileBloc, ProfileState>(
            listener: (context, state) async {
              if (state is ProfileLoaded) {
                final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated &&
            state.profile.username == authState.user.username) {
          final useProfileAccent = await StorageService.getUseProfileAccentColor();
          if (context.mounted) {
            if (useProfileAccent) {
              final profileColor = state.profile.profileColor;
              if (profileColor != null && profileColor.isNotEmpty) {
                context.read<ThemeBloc>().add(UpdateAccentColorStateEvent(profileColor));
              } else {
                context.read<ThemeBloc>().add(UpdateAccentColorStateEvent(null));
              }
            }
          }
        }
              }
            },
          ),
        ],
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              if (_isNotificationsOpen) {
                _onNotificationClose();
                return;
              }
              if (_currentIndexNotifier.value == 1 && _musicSectionController.value == MusicSection.search) {
                _musicSectionController.value = MusicSection.home;
              } else if (_currentIndexNotifier.value == 1 && _musicSectionController.value != MusicSection.home) {
                _musicSectionController.value = MusicSection.home;
              }
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppBackground(fallbackColor: Theme.of(context).colorScheme.surface),
              Scaffold(
                backgroundColor: Colors.transparent,
                body: Stack(
                  children: [
                    // Контент (PageView) на нижнем слое - заполняет всё пространство
                    SafeArea(
                      bottom: false,
                      child: ValueListenableBuilder<MusicSection>(
                        valueListenable: _musicSectionController,
                        builder: (context, section, child) {
                          return PageView(
                            controller: _pageController,
                            onPageChanged: _onPageChanged,
                            physics: section != MusicSection.home ? const NeverScrollableScrollPhysics() : null,
                            children: _pages,
                          );
                        },
                      ),
                    ),
                    // Хедер поверх контента (вне SafeArea для правильной прозрачности)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: ValueListenableBuilder<MusicSection>(
                          valueListenable: _musicSectionController,
                          builder: (context, currentSection, child) => ValueListenableBuilder<int>(
                            valueListenable: _currentIndexNotifier,
                            builder: (context, currentIndex, child) => AppHeader(
                              currentTabIndex: currentIndex,
                              isInMusicFavoritesSection: currentIndex == 1 && currentSection == MusicSection.favorites,
                              onMusicFavoritesBack: (currentIndex == 1 && currentSection == MusicSection.favorites) ? _onMusicFavoritesBack : null,
                              isInMusicPlaylistsSection: currentIndex == 1 && currentSection == MusicSection.playlists,
                              onMusicPlaylistsBack: (currentIndex == 1 && currentSection == MusicSection.playlists) ? _onMusicPlaylistsBack : null,
                              isInMusicAllTracksSection: currentIndex == 1 && currentSection == MusicSection.allTracks,
                              onMusicAllTracksBack: (currentIndex == 1 && currentSection == MusicSection.allTracks) ? _onMusicAllTracksBack : null,
                              isInMusicSearchSection: currentIndex == 1 && currentSection == MusicSection.search,
                              onMusicSearchBack: (currentIndex == 1 && currentSection == MusicSection.search) ? _onMusicSearchBack : null,
                            isInMusicArtistSection: currentIndex == 1 && currentSection == MusicSection.artist,
                            onMusicArtistBack: (currentIndex == 1 && currentSection == MusicSection.artist) ? _onMusicArtistBack : null,
                            artistNameWidget: (currentIndex == 1 && currentSection == MusicSection.artist) 
                                ? BlocBuilder<MusicBloc, MusicState>(
                                    builder: (context, state) {
                                      final name = state.currentArtist?.name ?? 'Артист';
                                      return Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                                  )
                                : null,
                              onNotificationsTap: _toggleNotifications,
                              isNotificationsOpen: _isNotificationsOpen,
                              hideNotificationsBadge: _isNotificationsOpen,
                            ),
                          ),
                        ),
                      ),
                    ),
                      // TabBar и другие элементы поверх контента
                      ValueListenableBuilder<MusicSection>(
                        valueListenable: _musicSectionController,
                        builder: (context, section, child) {
                          // Скрываем таббар и кнопку в секции артиста
                          if (section == MusicSection.artist) {
                            return _buildArtistPlayButton();
                          }
                          
                          return FutureBuilder<bool>(
                            future: StorageService.getHideTabBar(),
                            builder: (context, snapshot) {
                              final hideTabBar = snapshot.data ?? false;
                              if (hideTabBar) {
                                return const SizedBox.shrink();
                              }
                              return AnimatedBuilder(
                                animation: _tabBarAnimationController,
                                builder: (context, child) => Positioned(
                                  bottom: _tabBarBottomAnimation.value,
                                  left: 0,
                                  right: 0,
                                  child: Opacity(
                                    opacity: _tabBarOpacityAnimation.value,
                                    child: _buildTabBar(),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      ValueListenableBuilder<MusicSection>(
                        valueListenable: _musicSectionController,
                        builder: (context, section, child) {
                          // Скрываем динамическую кнопку в секции артиста
                          if (section == MusicSection.artist) {
                            return const SizedBox.shrink();
                          }
                          
                          return AnimatedBuilder(
                            animation: _tabBarAnimationController,
                            builder: (context, child) => Positioned(
                              bottom: _tabBarBottomAnimation.value,
                              right: 12,
                              child: Opacity(
                                opacity: _tabBarOpacityAnimation.value,
                                child: ValueListenableBuilder<int>(
                                  valueListenable: _currentIndexNotifier,
                                  builder: (context, currentIndex, child) => ValueListenableBuilder<bool>(
                                    valueListenable: feedScrolledDown,
                                    builder: (context, scrolledDown, child) => _buildDynamicButton(),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      MiniPlayer(onMusicTabTap: () => _onTabTapped(1), onTabBarToggle: _onTabBarToggle),
                      ValueListenableBuilder<bool>(
                        valueListenable: _notificationsVisible,
                        builder: (context, visible, child) => NotificationsSection(
                          isVisible: visible,
                          onClose: _onNotificationClose,
                        ),
                      ),
                    ],
                  ),
                ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.65, // 65% ширины
        height: 50, // тонкая сигаретка
        child: GlassModeWrapper(
          borderRadius: 25,
          settings: const LiquidGlassSettings(
            thickness: 15,
            glassColor: Color(0x33FFFFFF),
            lightIntensity: 1.5,
            chromaticAberration: 1,
            saturation: 1.1,
            ambientStrength: 1,
            blur: 4,
            refractiveIndex: 1.8,
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: _currentIndexNotifier,
            builder: (context, currentIndex, child) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabIcon(0, Icons.person),
                StreamBuilder<({bool hasTrack, bool playing, double progress})>(
                  stream: () {
                    final handler = AudioServiceManager.getHandler();

                    // Используем handler напрямую для mediaItem, если доступен (более надежно)
                    Stream<MediaItem?> mediaItemStream;
                    if (handler != null) {
                      final initialMediaItem = handler.mediaItem.valueOrNull;
                      mediaItemStream = handler.mediaItem.startWith(initialMediaItem);
                    } else {
                      // Fallback when handler is not available - create a stream that emits null initially
                      mediaItemStream = Stream.value(null);
                    }

                    // Используем handler напрямую для playing, если доступен (более надежно)
                    Stream<bool> playingStream;
                    if (handler != null) {
                      final initialPlaying = handler.playbackState.valueOrNull?.playing ?? false;
                      playingStream = handler.playbackState
                          .map((state) => state.playing)
                          .distinct()
                          .startWith(initialPlaying);
                    } else {
                      // Fallback when handler is not available - create a stream that emits false initially
                      playingStream = Stream.value(false);
                    }
                    
                    return Rx.combineLatest3<MediaItem?, bool, Duration, ({bool hasTrack, bool playing, double progress})>(
                      mediaItemStream,
                      playingStream,
                      AudioService.position.startWith(Duration.zero),
                      (mediaItem, playing, position) {
                        final duration = mediaItem?.duration;
                        final progress = (duration != null && duration.inSeconds > 0)
                            ? position.inSeconds / duration.inSeconds
                            : 0.0;
                        final hasTrack = mediaItem != null;
                        return (hasTrack: hasTrack, playing: playing, progress: progress);
                      },
                    );
                  }(),
                  builder: (context, snapshot) {
                    final data = snapshot.data ?? (hasTrack: false, playing: false, progress: 0.0);
                    // Показываем кружок, если есть трек (независимо от playing)
                    return _buildMusicTabIcon(data.hasTrack, data.progress, data.playing);
                  },
                ),
                _buildTabIcon(2, Icons.newspaper),
                _buildTabIcon(3, Icons.chat_bubble_outline),
                _buildTabIcon(4, Icons.grid_view),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMusicTabIcon(bool hasTrack, double progress, bool isPlaying) {
    final isSelected = _currentIndexNotifier.value == 1;
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () => _onTabTapped(1),
      icon: Icon(
        Icons.music_note,
        size: 24,
        // Используем динамический цвет для активной вкладки, как у других табов
        color: isSelected ? context.dynamicPrimaryColor : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildTabIcon(int index, IconData icon) {
    final isSelected = _currentIndexNotifier.value == index;

    if (index == 3) {
      return BlocSelector<MessagesBloc, MessagesState, int>(
        selector: (state) => state.totalUnreadCount,
        builder: (context, unreadCount) {
          debugPrint('MainTabs: Messages badge - unreadCount: $unreadCount');
          return IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _onTabTapped(index),
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: context.dynamicPrimaryColor,
              textColor: Theme.of(context).colorScheme.onPrimary,
              alignment: AlignmentDirectional.topEnd,
              offset: const Offset(4, -4),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? context.dynamicPrimaryColor : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
      );
    }

    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () => _onTabTapped(index),
      icon: Icon(
        icon,
        size: 24,
        color: isSelected ? context.dynamicPrimaryColor : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildDynamicButton() {
    return GlassModeWrapper(
      borderRadius: 25,
      settings: const LiquidGlassSettings(
        thickness: 15,
        glassColor: Color(0x33FFFFFF),
        lightIntensity: 1.5,
        chromaticAberration: 1,
        saturation: 1.1,
        ambientStrength: 1,
        blur: 4,
        refractiveIndex: 1.8,
      ),
      child: SizedBox(
        width: 50,
        height: 50,
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: _onDynamicButtonPressed,
          icon: Icon(
            _getDynamicIcon(),
            size: 24,
            // Используем цвет неактивных кнопок таб-бара
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildArtistPlayButton() {
    final handler = AudioServiceManager.getHandler();
    return StreamBuilder<MediaItem?>(
      stream: handler?.mediaItem ?? Stream.value(null),
      builder: (context, snapshot) {
        final hasTrack = snapshot.hasData && snapshot.data != null;
        
        return ValueListenableBuilder<bool>(
          valueListenable: _isMiniPlayerExpanded,
          builder: (context, isExpanded, child) {
            // Скрываем кнопку если мини-плеер открыт или есть трек
            if (isExpanded || hasTrack) {
              return const SizedBox.shrink();
            }

            return BlocBuilder<MusicBloc, MusicState>(
              builder: (context, state) {
                final artist = state.currentArtist;
                final tracks = artist?.tracks ?? [];
                
                if (tracks.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Positioned(
                  bottom: 16,
                  left: 12,
                  right: 12,
                  child: GlassModeWrapper(
                    borderRadius: 25,
                    settings: const LiquidGlassSettings(
                      thickness: 15,
                      glassColor: Color(0x33FFFFFF),
                      lightIntensity: 1.5,
                      chromaticAberration: 1,
                      saturation: 1.1,
                      ambientStrength: 1,
                      blur: 4,
                      refractiveIndex: 1.8,
                    ),
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.read<QueueBloc>().add(
                            QueuePlayTracksRequested(
                              tracks,
                              'artist_${artist?.id}',
                              startIndex: 0,
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Воспроизвести все'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
