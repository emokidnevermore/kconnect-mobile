/// Виджет для отображения фона приложения
///
/// Отображает выбранный пользователем фон (фото или видео) под всеми элементами интерфейса.
/// Применяет эффекты блюра и затемнения для лучшей читаемости контента.
///
/// Планирование:
/// - Виджет загружает фон из StorageService
/// - Отображает фото через Image.file или видео через VideoPlayer
/// - Применяет BackdropFilter для блюра
/// - Добавляет затемняющий overlay
/// - Интегрируется в main_tabs.dart через Stack
library;

import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import '../../services/storage_service.dart';

/// Виджет фона приложения
///
/// Отображает выбранный фон с эффектами блюра и затемнения.
/// Используется как нижний слой в Stack для отображения под всем контентом.
class AppBackground extends StatefulWidget {
  /// Цвет заглушки, который будет показан если фона нет
  final Color? fallbackColor;

  const AppBackground({super.key, this.fallbackColor});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  String? _backgroundPath;
  String? _backgroundType;
  String? _backgroundThumbnailPath;

  @override
  void initState() {
    super.initState();
    // Загружаем фон и инициализируем ValueNotifier
    _loadBackground().then((_) {
      if (mounted) {
        StorageService.appBackgroundPathNotifier.value = _backgroundPath;
      }
    });
  }

  Future<void> _loadBackground() async {
    final path = await StorageService.getAppBackgroundPath();
    final type = await StorageService.getAppBackgroundType();
    final thumbnailPath = await StorageService.getAppBackgroundThumbnailPath();
    if (mounted) {
      setState(() {
        _backgroundPath = path;
        _backgroundType = type;
        _backgroundThumbnailPath = thumbnailPath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Используем ValueListenableBuilder для отслеживания изменений фона
    return ValueListenableBuilder<String?>(
      valueListenable: StorageService.appBackgroundPathNotifier,
      builder: (context, updatedPath, child) {
        // Если есть обновление, перезагружаем фон
        if (updatedPath != _backgroundPath && mounted) {
          // Используем addPostFrameCallback чтобы избежать изменений во время build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadBackground();
            }
          });
        }
        
        if (_backgroundPath == null || (_backgroundPath != null && !File(_backgroundPath!).existsSync())) {
          if (widget.fallbackColor != null) {
            return Container(color: widget.fallbackColor);
          }
          return const SizedBox.shrink();
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // Фоновое изображение/видео
            _buildBackgroundContent(),
            // Затемняющий overlay
            Container(
              color: Colors.black.withValues(alpha: 0.4),
            ),
            // Блюр эффект
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackgroundContent() {
    if (_backgroundType == 'video') {
      // Для видео используем thumbnail если есть, иначе сам видеофайл
      if (_backgroundThumbnailPath != null && File(_backgroundThumbnailPath!).existsSync()) {
        return Image.file(
          File(_backgroundThumbnailPath!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback на сам видеофайл если thumbnail не загрузился
            return _backgroundPath != null && File(_backgroundPath!).existsSync()
                ? Image.file(
                    File(_backgroundPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  )
                : const SizedBox.shrink();
          },
        );
      } else if (_backgroundPath != null && File(_backgroundPath!).existsSync()) {
        return Image.file(
          File(_backgroundPath!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        );
      }
      return const SizedBox.shrink();
    } else {
      // Для изображений
      return _backgroundPath != null && File(_backgroundPath!).existsSync()
          ? Image.file(
              File(_backgroundPath!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            )
          : const SizedBox.shrink();
    }
  }
}

