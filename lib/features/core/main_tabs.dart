import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/features/feed/feed_screen.dart';
import 'package:kconnect_mobile/features/music/music_home.dart';
import 'package:kconnect_mobile/features/menu/menu_screen.dart';
import 'package:kconnect_mobile/features/messages/messages_screen.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_bloc.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_event.dart';
import 'package:kconnect_mobile/features/profile/my_profile_screen.dart';
import 'package:kconnect_mobile/features/profile/widgets/profile_edit_screen.dart';
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
import 'package:kconnect_mobile/features/music/widgets/full_screen_player.dart';
import 'package:kconnect_mobile/features/music/widgets/full_screen_search.dart';
import 'package:audio_service/audio_service.dart';
import 'package:kconnect_mobile/services/audio_service_manager.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:kconnect_mobile/core/widgets/glass_mode_wrapper.dart';
import 'package:kconnect_mobile/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:kconnect_mobile/features/notifications/presentation/bloc/notifications_event.dart';

import 'package:kconnect_mobile/features/notifications/presentation/screens/notifications_screen.dart';

import 'package:kconnect_mobile/core/widgets/app_background.dart';
import 'package:kconnect_mobile/core/widgets/bottom_navigation_bar.dart';
import 'package:kconnect_mobile/features/post_creation/presentation/screens/post_creation_screen.dart';
import 'package:kconnect_mobile/features/post_creation/presentation/blocs/post_creation_bloc.dart';
import 'package:kconnect_mobile/features/messages/presentation/screens/create_chat_screen.dart';
import 'package:kconnect_mobile/injection.dart';

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
  late final ValueNotifier<bool> feedScrolledDown = ValueNotifier(false);
  late final ValueNotifier<bool> scrollToTopRequested = ValueNotifier(false);
  late final List<Widget> _pages;
  final ValueNotifier<MusicSection> _musicSectionController = ValueNotifier(MusicSection.home);
  final ValueNotifier<bool> _isMiniPlayerExpanded = ValueNotifier(false);


  @override
  void initState() {
    super.initState();
    _tabBarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Material 3 standard duration
    );


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



  void _onMusicArtistBack() {
    _onTabTapped(1);
    _musicSectionController.value = MusicSection.home;
  }

  void _onDynamicButtonPressed() {
    switch (_currentIndexNotifier.value) {
      case 0:
        // Профиль: редактирование
        _openProfileEditScreen();
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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BlocProvider.value(
                value: locator<PostCreationBloc>(),
                child: const PostCreationScreen(),
              ),
            ),
          );
        }
        break;
      case 3:
        // Сообщения: новый чат
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CreateChatScreen(),
          ),
        );
        break;
      case 4:
        // Меню: мульти-аккаунт +
        _showAccountMenu();
        break;
    }
  }

  void _onMusicSearchPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FullScreenSearch(),
      ),
    );
  }

  void _openProfileEditScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProfileEditScreen(),
      ),
    );
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

  void _openFullScreenPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FullScreenPlayer(),
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: this.context.read<NotificationsBloc>(),
          child: const NotificationsScreen(),
        ),
      ),
    );
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
              if (_currentIndexNotifier.value == 1 && _musicSectionController.value != MusicSection.home) {
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
                              isInMusicSearchSection: false,
                              onMusicSearchBack: null,
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
                            ),
                          ),
                        ),
                      ),
                    ),
                      // Унифицированная нижняя навигационная панель
                      ValueListenableBuilder<MusicSection>(
                        valueListenable: _musicSectionController,
                        builder: (context, section, child) {
                          // Скрываем навигацию в секции артиста
                          if (section == MusicSection.artist) {
                            return _buildArtistPlayButton();
                          }

                          return Positioned(
                            bottom: 16.0,
                            left: 0,
                            right: 0,
                            child: AppBottomNavigationBar(
                              onTabTapped: _onTabTapped,
                              onDynamicButtonPressed: _onDynamicButtonPressed,
                              onFeedScrollChanged: _onFeedScrollChanged,
                              currentIndex: _currentIndexNotifier,
                              feedScrolledDown: feedScrolledDown,
                              scrollToTopRequested: () => scrollToTopRequested.value = true,
                              onMusicTabTap: () => _onTabTapped(1),
                              onTabBarToggle: _onTabBarToggle,
                              onFullScreenTap: _openFullScreenPlayer,

                            ),
                          );
                        },
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
