import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../features/music/domain/models/track.dart';
import 'media_state_manager.dart';
import 'player_button.dart';
import 'expanded_player.dart';
import 'navigation_tab_bar.dart';
import 'dynamic_action_button.dart';


/// Унифицированная нижняя навигационная панель
class AppBottomNavigationBar extends StatefulWidget {
  /// Колбэк при нажатии на таб
  final Function(int) onTabTapped;

  /// Колбэк при нажатии на динамическую кнопку
  final VoidCallback onDynamicButtonPressed;

  /// Колбэк при изменении скролла в ленте
  final Function(bool) onFeedScrollChanged;

  /// Текущий индекс таба
  final ValueNotifier<int> currentIndex;

  /// Состояние скролла ленты
  final ValueNotifier<bool> feedScrolledDown;

  /// Колбэк для запроса прокрутки вверх
  final VoidCallback? scrollToTopRequested;

  /// Колбэк при нажатии на кнопку музыки
  final VoidCallback onMusicTabTap;

  /// Колбэк при переключении таб-бара
  final Function(bool)? onTabBarToggle;

  /// Колбэк при нажатии на полноэкранный плеер
  final VoidCallback? onFullScreenTap;

  const AppBottomNavigationBar({
    super.key,
    required this.onTabTapped,
    required this.onDynamicButtonPressed,
    required this.onFeedScrollChanged,
    required this.currentIndex,
    required this.feedScrolledDown,
    required this.scrollToTopRequested,
    required this.onMusicTabTap,
    this.onTabBarToggle,
    this.onFullScreenTap,
  });

  @override
  State<AppBottomNavigationBar> createState() => _AppBottomNavigationBarState();
}

class _AppBottomNavigationBarState extends State<AppBottomNavigationBar>
    with SingleTickerProviderStateMixin {
  late final MediaStateManager _mediaStateManager;
  late AnimationController _expansionController;
  late Animation<double> _expansionAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isPlayerExpanded = false;

  @override
  void initState() {
    super.initState();
    _mediaStateManager = MediaStateManager();

    _expansionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Material 3 standard duration
    );

    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeOutCubic, // Material 3 emphasized easing
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _expansionController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, 1.0), // Slide down
    ).animate(
      CurvedAnimation(
        parent: _expansionController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _expansionController.dispose();
    super.dispose();
  }

  /// Получить иконку для динамической кнопки
  IconData _getDynamicIcon(int currentIndex, bool feedScrolledDown) {
    switch (currentIndex) {
      case 0:
        return Icons.account_circle;
      case 1:
        return Icons.search;
      case 2:
        return feedScrolledDown ? Icons.arrow_upward : Icons.add;
      case 3:
        return Icons.edit;
      case 4:
        return Icons.person;
      default:
        return Icons.add;
    }
  }

  /// Переключить расширение плеера
  void _togglePlayerExpand() {
    setState(() {
      _isPlayerExpanded = !_isPlayerExpanded;
    });

    if (_isPlayerExpanded) {
      _expansionController.forward();
    } else {
      _expansionController.reverse();
    }

    widget.onTabBarToggle?.call(_isPlayerExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Адаптивные размеры на основе ширины экрана
        final screenWidth = constraints.maxWidth;
        final isSmallScreen = screenWidth < 360;
        final isLargeScreen = screenWidth > 480;

        final buttonSize = isSmallScreen ? 44.0 : 50.0;
        final tabBarHeight = isSmallScreen ? 44.0 : 50.0;

        // Адаптивные размеры компонентов
        final tabBarWidth = isSmallScreen
            ? screenWidth * 0.55  // 55% на маленьких экранах
            : isLargeScreen
                ? screenWidth * 0.70  // 70% на больших экранах
                : screenWidth * 0.65;  // 65% на средних экранах

        return FutureBuilder<bool>(
          future: StorageService.getHideTabBar(),
          builder: (context, snapshot) {
            final hideTabBar = snapshot.data ?? false;

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: StreamBuilder<({bool hasTrack, bool playing, double progress, Track? track, bool isBuffering})>(
                  stream: _mediaStateManager.combinedStream,
                  builder: (context, snapshot) {
                    final mediaState = snapshot.data ?? (hasTrack: false, playing: false, progress: 0.0, track: null, isBuffering: false);

                    return AnimatedBuilder(
                      animation: _expansionController,
                      builder: (context, child) {
                        return Stack(
                          children: [
                            // Regular navigation (fades out when expanded)
                            Opacity(
                              opacity: 1.0 - _expansionAnimation.value,
                              child: ValueListenableBuilder<int>(
                                valueListenable: widget.currentIndex,
                                builder: (context, currentIndex, child) => Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Левая кнопка - плеер
                                    PlayerButton(
                                      size: buttonSize,
                                      onPressed: () => _togglePlayerExpand(),
                                      onLongPress: widget.onFullScreenTap,
                                      mediaState: mediaState,
                                    ),

                                    // Центральный таб-бар
                                    SlideTransition(
                                      position: _slideAnimation,
                                      child: FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: NavigationTabBar(
                                          width: hideTabBar ? 0 : tabBarWidth,
                                          height: tabBarHeight,
                                          onTabTapped: widget.onTabTapped,
                                          currentIndex: currentIndex,
                                        ),
                                      ),
                                    ),

                                    // Правая динамическая кнопка
                                    SlideTransition(
                                      position: _slideAnimation,
                                      child: FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: ValueListenableBuilder<bool>(
                                          valueListenable: widget.feedScrolledDown,
                                          builder: (context, feedScrolledDown, child) => DynamicActionButton(
                                            size: buttonSize,
                                            onPressed: widget.onDynamicButtonPressed,
                                            icon: _getDynamicIcon(currentIndex, feedScrolledDown),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Expanded player (fades in when expanded)
                            if (_isPlayerExpanded && mediaState.hasTrack)
                              Opacity(
                                opacity: _expansionAnimation.value,
                                child: ExpandedPlayer(
                                  mediaState: mediaState,
                                  onFullScreenTap: widget.onFullScreenTap,
                                  onCollapse: () => _togglePlayerExpand(),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
