/// Компонент редактирования обложки профиля
///
/// Позволяет пользователю выбрать и изменить обложку (баннер) профиля.
/// Использует MediaPickerModal для выбора изображения.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/services/storage_service.dart';
import 'package:kconnect_mobile/services/api_client/dio_client.dart';

/// Виджет секции редактирования обложки
class CoverEditSection extends StatelessWidget {
  final String? selectedBannerUrl;
  final VoidCallback onPickCover;
  final VoidCallback? onDeleteCover;

  const CoverEditSection({
    super.key,
    required this.selectedBannerUrl,
    required this.onPickCover,
    this.onDeleteCover,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: StorageService.appBackgroundPathNotifier,
      builder: (context, backgroundPath, child) {
        final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
        final cardColor = hasBackground
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
            : Theme.of(context).colorScheme.surfaceContainerLow;

        return Card(
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Обложка профиля',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onPickCover,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      image: null, // Will be handled by the FutureBuilder below
                    ),
                    child: selectedBannerUrl == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 32,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Добавить обложку',
                                  style: AppTextStyles.bodySecondary,
                                ),
                              ],
                            ),
                          )
                        : Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: selectedBannerUrl!.startsWith('http')
                                      ? FutureBuilder<Map<String, String>>(
                                          future: DioClient().getImageAuthHeaders(),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                              return const Center(child: CircularProgressIndicator());
                                            }

                                            final headers = snapshot.data ?? {};
                                            return CachedNetworkImage(
                                              imageUrl: selectedBannerUrl!,
                                              fit: BoxFit.cover,
                                              httpHeaders: headers,
                                              placeholder: (context, url) => Container(
                                                color: Theme.of(context).colorScheme.surface,
                                                child: const Center(child: CircularProgressIndicator()),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                color: Theme.of(context).colorScheme.surface,
                                                child: const Center(
                                                  child: Icon(Icons.error),
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : Image.file(
                                          File(selectedBannerUrl!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: Theme.of(context).colorScheme.surface,
                                            child: const Center(
                                              child: Icon(Icons.error),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                // Кнопка удаления обложки
                if (selectedBannerUrl != null && selectedBannerUrl!.isNotEmpty && onDeleteCover != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onDeleteCover,
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 18,
                      ),
                      label: Text(
                        'Удалить обложку',
                        style: AppTextStyles.body.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 14,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        backgroundColor: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // Информация о размерах и форматах
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Рекомендуемый размер: 1200×300 пикселей',
                        style: AppTextStyles.bodySecondary.copyWith(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Форматы: JPG, PNG, GIF',
                        style: AppTextStyles.bodySecondary.copyWith(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Максимальный размер: 10 МБ',
                        style: AppTextStyles.bodySecondary.copyWith(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
