import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../services/storage_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../routes/route_names.dart';
import 'theme_event.dart';
import 'theme_state.dart';

/// BLoC для управления темой приложения
///
/// Отвечает за все операции управления темой: загрузка, обновление акцентного цвета,
/// сброс к настройкам по умолчанию. Обеспечивает синхронизацию с хранилищем и UI.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(ThemeInitial()) {
    on<LoadThemeEvent>(_onLoadTheme);
    on<UpdateAccentColorEvent>(_onUpdateAccentColor);
    on<UpdateAccentColorStateEvent>(_onUpdateAccentColorState);
    on<ResetThemeEvent>(_onResetTheme);
  }

  static final Color _defaultSeedColor = const Color(0xFFD0BCFF);

  /// Геттер для доступа к дефолтному seed цвету
  static Color get defaultSeedColor => _defaultSeedColor;

  /// Создает ColorScheme из hex строки цвета используя seed цвет
  /// 
  /// Обрабатывает особый случай белых/очень светлых цветов, для которых
  /// стандартная генерация ColorScheme.fromSeed может давать нежелательные зеленоватые оттенки.
  /// Для таких цветов создается полностью монохромная (черно-белая) тема.
  ColorScheme _createColorSchemeFromSeed(String hexColor) {
    final hexColorSanitized = hexColor.replaceFirst('#', '');
    final colorInt = int.parse(hexColorSanitized, radix: 16);
    final seedColor = Color(colorInt | 0xFF000000);
    
    final luminance = seedColor.computeLuminance();
    
    // Если цвет очень светлый (почти белый), создаем полностью монохромную черно-белую схему
    // чтобы избежать любых цветовых оттенков во всей палитре
    if (luminance > 0.85) {
      return _createMonochromeColorScheme(seedColor);
    }
    
    // Для обычных цветов используем стандартную генерацию
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
  }

  /// Создает полностью монохромную (черно-белую) ColorScheme для светлых цветов
  ///
  /// Все цвета используют только серые оттенки без какой-либо цветности,
  /// что гарантирует отсутствие зеленоватых или других нежелательных оттенков.
  ColorScheme _createMonochromeColorScheme(Color lightColor) {
    return ColorScheme.dark(
      primary: lightColor,
      onPrimary: Colors.black,
      primaryContainer: const Color(0xFF2C2C2C),
      onPrimaryContainer: Colors.white,
      secondary: const Color(0xFFB0B0B0),
      onSecondary: Colors.black,
      secondaryContainer: const Color(0xFF3A3A3A),
      onSecondaryContainer: const Color(0xFFE0E0E0),
      tertiary: const Color(0xFF909090),
      onTertiary: Colors.black,
      tertiaryContainer: const Color(0xFF3A3A3A),
      onTertiaryContainer: const Color(0xFFE0E0E0),
      error: const Color(0xFFCF6679),
      onError: Colors.black,
      errorContainer: const Color(0xFF4A2A2F),
      onErrorContainer: const Color(0xFFF9DEDC),
      surface: const Color(0xFF1C1C1C),
      onSurface: Colors.white,
      surfaceContainerLowest: const Color(0xFF0F0F0F),
      surfaceContainerLow: const Color(0xFF282828),
      surfaceContainer: const Color(0xFF2C2C2C),
      surfaceContainerHigh: const Color(0xFF363636),
      surfaceContainerHighest: const Color(0xFF414141),
      outline: const Color(0xFF6C6C6C),
      outlineVariant: const Color(0xFF444444),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFFE0E0E0),
      onInverseSurface: Colors.black,
      inversePrimary: Colors.black,
    );
  }

  /// Создает дефолтную ColorScheme с точными брендовыми цветами
  /// 
  /// Использует точные брендовые цвета (#D0BCFF) вместо сгенерированных из seed
  /// для сохранения брендовой идентичности
  ColorScheme _createDefaultColorScheme() {
    // Создаем базовую схему из seed для получения остальных цветов
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _defaultSeedColor,
      brightness: Brightness.dark,
    );
    
    // Переопределяем primary цвет точным брендовым цветом
    // Это гарантирует, что _isDefaultTheme() в AppColors правильно определит дефолтную тему
    return baseScheme.copyWith(
      primary: _defaultSeedColor, // Точный брендовый цвет #D0BCFF
    );
  }

  void _onLoadTheme(LoadThemeEvent event, Emitter<ThemeState> emit) async {
    try {
      debugPrint('ThemeBloc: LoadThemeEvent started');

      final useProfileAccent = await StorageService.getUseProfileAccentColor();
      debugPrint('ThemeBloc: Personalization enabled: $useProfileAccent');

      String? accentColorHex;

      if (useProfileAccent) {
        accentColorHex = await StorageService.getSavedAccentColor();
        debugPrint('ThemeBloc: Saved accent color: $accentColorHex');
      } else {
        debugPrint('ThemeBloc: Personalization disabled, using default color');
      }

      ColorScheme colorScheme = _createDefaultColorScheme();
      if (accentColorHex != null && accentColorHex.isNotEmpty) {
        try {
          colorScheme = _createColorSchemeFromSeed(accentColorHex);
          debugPrint('ThemeBloc: Successfully created ColorScheme from $accentColorHex');
        } catch (e) {
          debugPrint('ThemeBloc: Failed to parse color $accentColorHex, using default');
          colorScheme = _createDefaultColorScheme();
        }
      } else {
        debugPrint('ThemeBloc: No accent color hex, using default color');
      }

      AppColors.updateFromColorScheme(colorScheme);
      debugPrint('ThemeBloc: Updated AppColors, emitting ThemeLoaded');

      emit(ThemeLoaded(colorScheme));
    } catch (e) {
      debugPrint('ThemeBloc: Error in LoadThemeEvent: $e');
      AppColors.updateFromColorScheme(_createDefaultColorScheme());
      emit(ThemeLoaded(_createDefaultColorScheme()));
    }
  }

  void _onUpdateAccentColor(UpdateAccentColorEvent event, Emitter<ThemeState> emit) async {
    if (state is! ThemeLoaded) {
      return;
    }

    ColorScheme colorScheme = _createDefaultColorScheme();
    if (event.accentColor != null && event.accentColor!.isNotEmpty) {
      try {
        colorScheme = _createColorSchemeFromSeed(event.accentColor!);
        await StorageService.setSavedAccentColor(event.accentColor);
      } catch (e) {
        colorScheme = _createDefaultColorScheme();
        await StorageService.setSavedAccentColor(null);
      }
    } else {
      await StorageService.setSavedAccentColor(null);
    }

    AppColors.updateFromColorScheme(colorScheme);

    emit(ThemeLoaded(colorScheme));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          RouteNames.splash, (route) => false);
    });
  }

  void _onUpdateAccentColorState(UpdateAccentColorStateEvent event, Emitter<ThemeState> emit) async {
    ColorScheme colorScheme = _createDefaultColorScheme();
    if (event.accentColor != null && event.accentColor!.isNotEmpty) {
      try {
        colorScheme = _createColorSchemeFromSeed(event.accentColor!);
        await StorageService.setSavedAccentColor(event.accentColor);
      } catch (e) {
        colorScheme = _createDefaultColorScheme();
        await StorageService.setSavedAccentColor(null);
      }
    } else {
      await StorageService.setSavedAccentColor(null);
    }

    AppColors.updateFromColorScheme(colorScheme);

    emit(ThemeLoaded(colorScheme));
  }

  void _onResetTheme(ResetThemeEvent event, Emitter<ThemeState> emit) {
    StorageService.setUseProfileAccentColor(false);
    StorageService.setSavedAccentColor(null);

    final defaultColorScheme = _createDefaultColorScheme();
    AppColors.updateFromColorScheme(defaultColorScheme);

    emit(ThemeLoaded(defaultColorScheme));
  }
}
