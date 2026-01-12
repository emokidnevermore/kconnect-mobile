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
  final DioClient _dioClient = DioClient();

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async {
    try {
      // Получаем заголовки авторизации
      final authHeaders = await _dioClient.getAuthHeaders();
      
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
