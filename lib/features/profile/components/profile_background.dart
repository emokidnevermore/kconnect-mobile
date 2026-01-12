/// Компонент фонового изображения профиля
///
/// Отображает баннер профиля пользователя с авторизацией.
/// Использует DioClient для получения заголовков аутентификации.
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api_client/dio_client.dart';

/// Виджет фонового изображения профиля
///
/// Показывает баннер профиля с поддержкой аутентифицированной загрузки.
/// Если фонового изображения нет, показывает цвет из ColorScheme профиля.
/// Используется в заголовке профиля для отображения фонового изображения или цвета.
class ProfileBackground extends StatelessWidget {
  final String? backgroundUrl;
  final ColorScheme? profileColorScheme;

  const ProfileBackground({
    super.key,
    required this.backgroundUrl,
    this.profileColorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // Если есть фоновое изображение, показываем его
    if (backgroundUrl != null) {
      return FutureBuilder<Map<String, String>>(
        future: DioClient().getImageAuthHeaders(),
        builder: (context, snapshot) {
          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: CachedNetworkImageProvider(
                  backgroundUrl!,
                  headers: snapshot.data,
                ),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      );
    }

    // Если нет изображения, но есть ColorScheme, показываем цвет из схемы
    if (profileColorScheme != null) {
      return Container(
        color: profileColorScheme!.surface,
      );
    }

    // Если ничего нет, возвращаем пустой виджет
    return const SizedBox.shrink();
  }
}
