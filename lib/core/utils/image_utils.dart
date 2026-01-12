// Утилиты для работы с изображениями
//
// Предоставляет функции для загрузки изображений с оптимизацией GIF,
// кэшированием и аутентификацией для защищенных ресурсов.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/api_client/dio_client.dart';

/// Утилиты для обработки загрузки изображений с оптимизацией GIF
class ImageUtils {
  /// Дополняет относительный URL до полного, добавляя базовый URL если необходимо
  ///
  /// [url] - URL изображения (может быть относительным или полным)
  /// Returns: Полный URL или null если входной URL пустой
  static String? getCompleteImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return 'https://k-connect.ru$url';
  }
  /// Создает виджет обложки альбома с предотвращением анимации GIF для оптимизации
  ///
  /// [imageUrl] - URL изображения обложки
  /// [width] - ширина виджета
  /// [height] - высота виджета
  /// [fit] - режим масштабирования изображения
  /// [placeholder] - виджет-заполнитель при загрузке
  /// [headers] - HTTP заголовки для запроса
  static Widget buildAlbumArt(
    String? imageUrl,
    BuildContext context, {
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Map<String, String>? headers,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.music_note,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    // For GIF images, add ?static=true parameter to force server to return static version
    // This changes the URL, clearing cache and potentially enabling server-side GIF->PNG conversion
    final String finalUrl = imageUrl.toLowerCase().contains('.gif')
        ? '$imageUrl?static=true'
        : imageUrl;
    
    // Determine if auth is required
    final requiresAuth = ImageUtils.requiresAuth(finalUrl);
    
    // If auth is required, we need to get headers asynchronously
    if (requiresAuth && headers == null) {
      return FutureBuilder<Map<String, String>>(
        future: DioClient().getImageAuthHeaders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: width,
              height: height,
              color: colorScheme.surfaceContainerHighest,
              child: placeholder ?? const CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return _buildCachedAlbumArt(
            finalUrl,
            context,
            width: width,
            height: height,
            fit: fit,
            placeholder: placeholder,
            headers: snapshot.data ?? {},
            colorScheme: colorScheme,
          );
        },
      );
    }
    
    return _buildCachedAlbumArt(
      finalUrl,
      context,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
      headers: headers ?? {},
      colorScheme: colorScheme,
    );
  }

  /// Вспомогательный метод для построения кэшированного изображения обложки
  static Widget _buildCachedAlbumArt(
    String imageUrl,
    BuildContext context, {
    required double width,
    required double height,
    required BoxFit fit,
    Widget? placeholder,
    required Map<String, String> headers,
    required ColorScheme colorScheme,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: fit,
          httpHeaders: headers.isNotEmpty ? headers : null,
          filterQuality: FilterQuality.low,
          memCacheWidth: width.toInt() * 2,
          memCacheHeight: height.toInt() * 2,
          placeholder: (context, url) => placeholder ??
              Container(
                color: colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          errorWidget: (context, url, error) => Icon(
            Icons.music_note,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Проверяет, требует ли URL аутентификационные заголовки
  ///
  /// Изображения на s3.k-connect.ru размещены на S3 и имеют собственный контроль доступа
  /// [url] - URL изображения для проверки
  /// Returns: true если требуется аутентификация
  static bool requiresAuth(String url) {
    if (url.contains('s3.k-connect.ru')) return false;
    return url.contains('k-connect.ru');
  }

  /// Создает виджет аватара чата с правильным кэшированием и аутентификацией для API изображений
  ///
  /// [imageUrl] - URL аватара
  /// [width] - ширина аватара
  /// [height] - высота аватара
  /// [fit] - режим масштабирования
  /// Returns: Future'<'Widget'>' настроенный виджет аватара
  static Future<Widget> buildChatAvatarImage(
    String imageUrl,
    BuildContext context, {
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;
    final headers = requiresAuth(imageUrl) ? await DioClient().getImageAuthHeaders() : <String, String>{};

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerHighest,
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: fit,
          filterQuality: FilterQuality.low,
          memCacheWidth: width.toInt() * 2,
          memCacheHeight: height.toInt() * 2,
          httpHeaders: headers,
          placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
          errorWidget: (context, url, error) => Icon(
            Icons.person,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Создает CachedNetworkImageProvider с аутентификационными заголовками при необходимости
  ///
  /// [url] - URL изображения
  /// Returns: Future'<'CachedNetworkImageProvider'>' с настроенными заголовками аутентификации
  static Future<CachedNetworkImageProvider> createAuthorizedImageProvider(String url) async {
    final headers = requiresAuth(url) ? await DioClient().getImageAuthHeaders() : <String, String>{};
    return CachedNetworkImageProvider(url, headers: headers);
  }
}
