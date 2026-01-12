/// Компонент бейджа достижения профиля
///
/// Отображает только иконку достижения пользователя.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import '../../../services/api_client/dio_client.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/authorized_cached_network_image.dart';
import '../domain/models/achievement_info.dart';

/// Виджет бейджа достижения (только иконка)
///
/// Компактная иконка для отображения достижения пользователя.
/// Поддерживает загрузку SVG и других форматов изображений (GIF, PNG, JPG) с авторизацией.
class ProfileAchievementBadge extends StatelessWidget {
  final AchievementInfo achievement;

  const ProfileAchievementBadge({
    super.key,
    required this.achievement,
  });

  /// Определяет формат изображения по URL
  bool _isSvgFormat(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.svg');
  }

  /// Загружает изображение как строку (для SVG)
  Future<String> _loadImageString(String url, Map<String, String> headers) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.plain,
        ),
      );
      return response.data.toString();
    } catch (e) {
      throw Exception('Failed to load image: $e');
    }
  }

  /// Виджет для отображения бейджа (SVG или изображение)
  Widget _buildBadgeImage(String url, BuildContext context, {Map<String, String>? headers}) {
    final fallbackIcon = Icon(
      Icons.emoji_events,
      size: 20,
      color: Theme.of(context).colorScheme.primary,
    );

    if (_isSvgFormat(url)) {
      // Для SVG используем SvgPicture
      if (headers != null) {
        // SVG с авторизацией - загружаем как строку
        return FutureBuilder<String>(
          future: _loadImageString(url, headers),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return fallbackIcon;
            }

            return SizedBox(
              width: 24,
              height: 24,
              child: SvgPicture.string(
                snapshot.data!,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                placeholderBuilder: (context) => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        );
      } else {
        // SVG без авторизации
        return SizedBox(
          width: 24,
          height: 24,
          child: SvgPicture.network(
            url,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            placeholderBuilder: (context) => const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
    } else {
      // Для GIF/PNG/JPG используем CachedNetworkImage
      if (headers != null) {
        // Изображение с авторизацией
        return SizedBox(
          width: 24,
          height: 24,
          child: AuthorizedCachedNetworkImage(
            imageUrl: url,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            placeholder: (context, url) => const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (context, url, error) => fallbackIcon,
          ),
        );
      } else {
        // Изображение без авторизации
        return SizedBox(
          width: 24,
          height: 24,
          child: CachedNetworkImage(
            imageUrl: url,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            placeholder: (context, url) => const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (context, url, error) => fallbackIcon,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (achievement.imagePath.isEmpty) {
      return const SizedBox.shrink();
    }

    final requiresAuth = ImageUtils.requiresAuth(achievement.imagePath);

    if (requiresAuth) {
      return FutureBuilder<Map<String, String>>(
        future: DioClient().getImageAuthHeaders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (!snapshot.hasData) {
            return Icon(
              Icons.emoji_events,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            );
          }

          return _buildBadgeImage(achievement.imagePath, context, headers: snapshot.data!);
        },
      );
    } else {
      return _buildBadgeImage(achievement.imagePath, context);
    }
  }
}
