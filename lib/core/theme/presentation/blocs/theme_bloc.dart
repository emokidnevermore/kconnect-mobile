import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../services/storage_service.dart';
import '../../../../theme/app_colors.dart';
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

  static final Color _darkThemeSeedColor = const Color(0xFFD0BCFF);
  static final Color _lightThemeSeedColor = const Color(0xFF7b5cff);

  /// Геттер для доступа к дефолтному seed цвету
  static Color get defaultSeedColor => _darkThemeSeedColor;

  /// Создает ColorScheme из hex строки цвета используя seed цвет
  ///
  /// Генерирует полную цветовую схему из seed цвета, но заменяет primary цвет
  /// на исходный акцентный цвет профиля, чтобы сохранить именно тот цвет,
  /// который выбрал пользователь.
  ColorScheme _createColorSchemeFromSeed(String hexColor, Brightness brightness) {
    final hexColorSanitized = hexColor.replaceFirst('#', '');
    final colorInt = int.parse(hexColorSanitized, radix: 16);
    final seedColor = Color(colorInt | 0xFF000000);

    // Генерируем цветовую схему из seed цвета
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    // Заменяем primary цвет на исходный акцентный цвет профиля
    return generatedScheme.copyWith(
      primary: seedColor,
    );
  }



  /// Создает дефолтную ColorScheme с точными брендовыми цветами
  ///
  /// Использует точные брендовые цвета (#D0BCFF для темной, #C8BCF6 для светлой) вместо сгенерированных из seed
  /// для сохранения брендовой идентичности
  ColorScheme _createDefaultColorScheme(Brightness brightness) {
    final seedColor = brightness == Brightness.light ? _lightThemeSeedColor : _darkThemeSeedColor;

    // Создаем базовую схему из seed для получения остальных цветов
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    // Переопределяем primary цвет точным брендовым цветом
    // Это гарантирует, что _isDefaultTheme() в AppColors правильно определит дефолтную тему
    return baseScheme.copyWith(
      primary: seedColor,
    );
  }

  void _onLoadTheme(LoadThemeEvent event, Emitter<ThemeState> emit) async {
    try {
      debugPrint('ThemeBloc: LoadThemeEvent started');

      final useProfileAccent = await StorageService.getUseProfileAccentColor();
      final useLightTheme = await StorageService.getUseLightTheme();
      final brightness = useLightTheme ? Brightness.light : Brightness.dark;
      debugPrint('ThemeBloc: Personalization enabled: $useProfileAccent');
      debugPrint('ThemeBloc: Light theme enabled: $useLightTheme');

      String? accentColorHex;

      if (useProfileAccent) {
        accentColorHex = await StorageService.getSavedAccentColor();
        debugPrint('ThemeBloc: Saved accent color: $accentColorHex');
      } else {
        debugPrint('ThemeBloc: Personalization disabled, using default color');
      }

      ColorScheme colorScheme = _createDefaultColorScheme(brightness);
      if (accentColorHex != null && accentColorHex.isNotEmpty) {
        try {
          colorScheme = _createColorSchemeFromSeed(accentColorHex, brightness);
          debugPrint('ThemeBloc: Successfully created ColorScheme from $accentColorHex');
        } catch (e) {
          debugPrint('ThemeBloc: Failed to parse color $accentColorHex, using default');
          colorScheme = _createDefaultColorScheme(brightness);
        }
      } else {
        debugPrint('ThemeBloc: No accent color hex, using default color');
      }

      AppColors.updateFromColorScheme(colorScheme);
      debugPrint('ThemeBloc: Updated AppColors, emitting ThemeLoaded');

      emit(ThemeLoaded(colorScheme));
    } catch (e) {
      debugPrint('ThemeBloc: Error in LoadThemeEvent: $e');
      final fallbackScheme = _createDefaultColorScheme(Brightness.dark);
      AppColors.updateFromColorScheme(fallbackScheme);
      emit(ThemeLoaded(fallbackScheme));
    }
  }

  void _onUpdateAccentColor(UpdateAccentColorEvent event, Emitter<ThemeState> emit) async {
    if (state is! ThemeLoaded) {
      return;
    }

    final useLightTheme = await StorageService.getUseLightTheme();
    final brightness = useLightTheme ? Brightness.light : Brightness.dark;

    ColorScheme colorScheme = _createDefaultColorScheme(brightness);
    if (event.accentColor != null && event.accentColor!.isNotEmpty) {
      try {
        colorScheme = _createColorSchemeFromSeed(event.accentColor!, brightness);
        await StorageService.setSavedAccentColor(event.accentColor);
      } catch (e) {
        colorScheme = _createDefaultColorScheme(brightness);
        await StorageService.setSavedAccentColor(null);
      }
    } else {
      await StorageService.setSavedAccentColor(null);
    }

    AppColors.updateFromColorScheme(colorScheme);

    emit(ThemeLoaded(colorScheme));

    // Перезагрузка больше не нужна - все элементы обновляются динамически
  }

  void _onUpdateAccentColorState(UpdateAccentColorStateEvent event, Emitter<ThemeState> emit) async {
    final useLightTheme = await StorageService.getUseLightTheme();
    final brightness = useLightTheme ? Brightness.light : Brightness.dark;

    ColorScheme colorScheme = _createDefaultColorScheme(brightness);
    if (event.accentColor != null && event.accentColor!.isNotEmpty) {
      try {
        colorScheme = _createColorSchemeFromSeed(event.accentColor!, brightness);
        await StorageService.setSavedAccentColor(event.accentColor);
      } catch (e) {
        colorScheme = _createDefaultColorScheme(brightness);
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
    StorageService.setUseLightTheme(false);

    final defaultColorScheme = _createDefaultColorScheme(Brightness.dark);
    AppColors.updateFromColorScheme(defaultColorScheme);

    emit(ThemeLoaded(defaultColorScheme));
  }
}
