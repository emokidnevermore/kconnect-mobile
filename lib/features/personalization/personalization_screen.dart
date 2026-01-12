/// Экран персонализации с настройками акцентного цвета
///
/// Позволяет пользователю настроить персонализацию интерфейса.
/// Поддерживает использование акцентного цвета из профиля пользователя.
/// Интегрируется с ThemeBloc и ProfileBloc для управления темами.
/// Экран персонализации с настройками акцентного цвета
///
/// Позволяет пользователю настроить персонализацию интерфейса.
/// Поддерживает использование акцентного цвета из профиля пользователя.
/// Интегрируется с ThemeBloc и ProfileBloc для управления темами.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import '../../core/theme/presentation/blocs/theme_bloc.dart';
import '../../core/theme/presentation/blocs/theme_event.dart';
import '../../core/theme/presentation/blocs/theme_state.dart';
import '../../features/profile/presentation/blocs/profile_bloc.dart';
import '../../features/profile/presentation/blocs/profile_event.dart';
import '../../features/profile/presentation/blocs/profile_state.dart';
import '../../services/storage_service.dart';
import '../../core/constants/tab_bar_glass_mode.dart';
import '../../routes/app_router.dart';
import '../../routes/route_names.dart';
import '../../features/profile/components/swipe_pop_container.dart';
import '../../shared/widgets/media_picker_modal.dart';
import '../../core/widgets/app_background.dart';
import 'widgets/accent_color_card.dart';
import 'widgets/tab_bar_style_card.dart';
import 'widgets/hide_tab_bar_card.dart';
import 'widgets/tab_bar_preview.dart';
import 'widgets/background_section.dart';
import 'dart:io';

/// Экран настроек персонализации
///
/// Предоставляет интерфейс для настройки персональных предпочтений:
/// акцентный цвет из профиля, темы и другие визуальные настройки.
class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  bool _useProfileAccentColor = false;
  TabBarGlassMode _tabBarGlassMode = TabBarGlassMode.glass;
  bool _hideTabBar = false;
  String? _appBackgroundPath;
  String? _appBackgroundType;
  String? _appBackgroundName;
  int? _appBackgroundSize;
  String? _appBackgroundThumbnailPath;
  
  // Начальные значения для отслеживания изменений
  bool _initialUseProfileAccentColor = false;
  TabBarGlassMode _initialTabBarGlassMode = TabBarGlassMode.glass;
  bool _initialHideTabBar = false;
  String? _initialAppBackgroundPath;
  String? _initialAppBackgroundType;
  String? _initialAppBackgroundName;
  int? _initialAppBackgroundSize;
  
  // Флаг для отслеживания, нужно ли применить цвет профиля после загрузки
  bool _pendingProfileColorApply = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    _useProfileAccentColor = await StorageService.getUseProfileAccentColor();
    _tabBarGlassMode = await StorageService.getTabBarGlassMode();
    _hideTabBar = await StorageService.getHideTabBar();
    _appBackgroundPath = await StorageService.getAppBackgroundPath();
    _appBackgroundType = await StorageService.getAppBackgroundType();
    _appBackgroundThumbnailPath = await StorageService.getAppBackgroundThumbnailPath();
    final metadata = await StorageService.getAppBackgroundMetadata();
    _appBackgroundName = metadata?['name'];
    _appBackgroundSize = metadata?['size'];
    
    _initialUseProfileAccentColor = _useProfileAccentColor;
    _initialTabBarGlassMode = _tabBarGlassMode;
    _initialHideTabBar = _hideTabBar;
    _initialAppBackgroundPath = _appBackgroundPath;
    _initialAppBackgroundType = _appBackgroundType;
    _initialAppBackgroundName = _appBackgroundName;
    _initialAppBackgroundSize = _appBackgroundSize;
    setState(() {});
  }

  bool get _hasUnsavedChanges {
    return _useProfileAccentColor != _initialUseProfileAccentColor ||
           _tabBarGlassMode != _initialTabBarGlassMode ||
           _hideTabBar != _initialHideTabBar ||
           _appBackgroundPath != _initialAppBackgroundPath ||
           _appBackgroundType != _initialAppBackgroundType ||
           _appBackgroundName != _initialAppBackgroundName ||
           _appBackgroundSize != _initialAppBackgroundSize;
  }

  Future<void> _applyChanges() async {
    if (!mounted) return;
    
    // Сохраняем bloc'и до async операций
    final profileBloc = context.read<ProfileBloc>();
    final themeBloc = context.read<ThemeBloc>();
    
    // Сохраняем все изменения
    await StorageService.setUseProfileAccentColor(_useProfileAccentColor);
    await StorageService.setTabBarGlassMode(_tabBarGlassMode);
    await StorageService.setHideTabBar(_hideTabBar);
    await StorageService.setAppBackgroundPath(_appBackgroundPath);
    await StorageService.setAppBackgroundType(_appBackgroundType);
    await StorageService.setAppBackgroundMetadata(_appBackgroundName, _appBackgroundSize);
    await StorageService.setAppBackgroundThumbnailPath(_appBackgroundThumbnailPath);

    if (!mounted) return;

    // Обновляем начальные значения перед применением изменений
    _initialUseProfileAccentColor = _useProfileAccentColor;
    _initialTabBarGlassMode = _tabBarGlassMode;
    _initialHideTabBar = _hideTabBar;
    _initialAppBackgroundPath = _appBackgroundPath;
    _initialAppBackgroundType = _appBackgroundType;
    _initialAppBackgroundName = _appBackgroundName;
    _initialAppBackgroundSize = _appBackgroundSize;

    // Применяем изменения акцентного цвета
    if (_useProfileAccentColor) {
      // Устанавливаем флаг, что нужно применить цвет после загрузки профиля
      setState(() {
        _pendingProfileColorApply = true;
      });
      // Загружаем профиль, чтобы получить цвет
      profileBloc.add(LoadCurrentProfileEvent(forceRefresh: true));
    } else {
      // Reset to default
      themeBloc.add(UpdateAccentColorEvent(null));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ProfileBloc, ProfileState>(
          listener: (context, state) {
            // Применяем цвет профиля после загрузки, если был установлен флаг
            if (_pendingProfileColorApply && state is ProfileLoaded) {
              final profileColor = state.profile.profileColor;
              final themeBloc = context.read<ThemeBloc>();
              
              setState(() {
                _pendingProfileColorApply = false;
              });
              
              if (profileColor != null && profileColor.isNotEmpty) {
                themeBloc.add(UpdateAccentColorEvent(profileColor));
              } else {
                themeBloc.add(UpdateAccentColorEvent(null));
              }
            }
          },
        ),
        BlocListener<ThemeBloc, ThemeState>(
          listener: (context, state) {
          },
        ),
      ],
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppBackground(fallbackColor: Theme.of(context).colorScheme.surface),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: SwipePopContainer(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 72, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                            Text(
                              'Акцентный цвет',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AccentColorCard(
                              useProfileAccentColor: _useProfileAccentColor,
                              onChanged: (value) {
                                setState(() {
                                  _useProfileAccentColor = value;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Стиль таб-бара и кнопок',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TabBarStyleCard(
                              selectedMode: _tabBarGlassMode,
                              onModeChanged: (mode) {
                                setState(() {
                                  _tabBarGlassMode = mode;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            HideTabBarCard(
                              hideTabBar: _hideTabBar,
                              onChanged: (value) {
                                setState(() {
                                  _hideTabBar = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            TabBarPreview(
                              mode: _tabBarGlassMode,
                              hideTabBar: _hideTabBar,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Фон приложения',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            BackgroundSection(
                              backgroundPath: _appBackgroundPath,
                              backgroundType: _appBackgroundType,
                              backgroundName: _appBackgroundName,
                              backgroundSize: _appBackgroundSize,
                              backgroundThumbnailPath: _appBackgroundThumbnailPath,
                              onPickBackground: _showBackgroundPicker,
                              onRemoveBackground: _removeBackground,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ),
          // Кастомный хедер с карточками (поверх всего)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: ValueListenableBuilder<String?>(
                valueListenable: StorageService.appBackgroundPathNotifier,
                builder: (context, backgroundPath, child) {
                  final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
                  final cardColor = hasBackground 
                      ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                      : Theme.of(context).colorScheme.surfaceContainerLow;
                  
                  return Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.transparent,
                    child: Row(
                    children: [
                      // Карточка слева: кнопка назад и название
                      Card(
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
                                'Персонализация',
                                style: AppTextStyles.postAuthor.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Карточка справа: кнопка сохранения (галочка)
                      Card(
                        margin: EdgeInsets.zero,
                        color: cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _hasUnsavedChanges ? () async {
                              final accentColorChanged = _useProfileAccentColor != _initialUseProfileAccentColor;
                              final tabBarModeChanged = _tabBarGlassMode != _initialTabBarGlassMode;
                              final hideTabBarChanged = _hideTabBar != _initialHideTabBar;
                              final onlyBackgroundChanged = !accentColorChanged && 
                                                            !tabBarModeChanged && 
                                                            !hideTabBarChanged &&
                                                            (_appBackgroundPath != _initialAppBackgroundPath || 
                                                             _appBackgroundType != _initialAppBackgroundType);
                              
                              await _applyChanges();

                              // UpdateAccentColorEvent уже вызывает перезагрузку приложения,
                              // но если изменения только в режиме таб-бара, нужно перезагрузить вручную
                              // Фон обновляется автоматически через ValueNotifier, перезагрузка не нужна
                              if (!mounted) return;

                              if (!accentColorChanged && !onlyBackgroundChanged) {
                                AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
                                  RouteNames.splash,
                                  (route) => false,
                                );
                              } else if (onlyBackgroundChanged) {
                                // Если изменился только фон, просто закрываем экран
                                Navigator.of(context).pop();
                              }
                            } : null,
                            icon: Icon(
                              Icons.check,
                              color: _hasUnsavedChanges
                                  ? context.dynamicPrimaryColor
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _showBackgroundPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => MediaPickerModal(
        photoOnly: true,
        singleSelection: true,
        onMediaSelected: (imagePaths, videoPath, videoThumbnailPath, tracks) async {
          String? selectedPath;
          String? selectedType;
          String? selectedName;
          int? selectedSize;
          String? selectedThumbnailPath;

          if (videoPath != null) {
            selectedPath = videoPath;
            selectedType = 'video';
            selectedThumbnailPath = videoThumbnailPath;
            final file = File(videoPath);
            if (await file.exists()) {
              selectedName = file.path.split('/').last;
              selectedSize = await file.length();
            }
          } else if (imagePaths.isNotEmpty) {
            selectedPath = imagePaths.first;
            selectedType = 'image';
            final file = File(imagePaths.first);
            if (await file.exists()) {
              selectedName = file.path.split('/').last;
              selectedSize = await file.length();
            }
          }

          setState(() {
            _appBackgroundPath = selectedPath;
            _appBackgroundType = selectedType;
            _appBackgroundName = selectedName;
            _appBackgroundSize = selectedSize;
            _appBackgroundThumbnailPath = selectedThumbnailPath;
          });
        },
      ),
    );
  }

  void _removeBackground() {
    setState(() {
      _appBackgroundPath = null;
      _appBackgroundType = null;
      _appBackgroundName = null;
      _appBackgroundSize = null;
      _appBackgroundThumbnailPath = null;
    });
  }

}
