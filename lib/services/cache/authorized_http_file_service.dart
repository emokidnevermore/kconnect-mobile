/// Кастомный HttpFileService с поддержкой заголовков авторизации
///
/// Использует Dio для загрузки файлов с заголовками авторизации.
library;

import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import '../api_client/dio_client.dart';

/// Кастомный FileService для загрузки файлов с авторизацией
class AuthorizedHttpFileService extends FileService {
  /// Проверяет, требует ли URL аутентификационные заголовки
  ///
  /// S3 файлы не требуют авторизации, в отличие от API эндпоинтов
  /// [url] - URL файла для проверки
  /// Returns: true если требуется аутентификация
  bool _requiresAuth(String url) {
    // S3 файлы доступны публично без авторизации
    if (url.contains('s3.k-connect.ru')) return false;
    // API эндпоинты требуют авторизации
    return url.contains('k-connect.ru');
  }
  final DioClient _dioClient = DioClient();

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async {
    try {
      // Определяем, нужны ли заголовки авторизации
      final requiresAuth = _requiresAuth(url);

      // Получаем заголовки авторизации только если требуется
      final authHeaders = requiresAuth ? await _dioClient.getAuthHeaders() : <String, String>{};

      // Объединяем заголовки авторизации с переданными заголовками
      final allHeaders = <String, String>{...authHeaders};
      if (headers != null) {
        allHeaders.addAll(headers);
      }

      // Используем http пакет для создания правильного StreamedResponse
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(allHeaders);

      final streamedResponse = await request.send();

      return HttpGetResponse(
        streamedResponse,
      );
    } catch (e) {
      throw HttpException('Failed to download file: $e');
    }
  }

}
