/// Основные константы приложения K-Connect
///
/// Содержит глобальные константы, используемые во всем приложении.
/// Все изменения этих значений должны быть тщательно протестированы.
class AppConstants {
  /// Версия приложения
  ///
  /// Должна соответствовать версии в pubspec.yaml
  static const String appVersion = '1.1.1';

  /// URL плейсхолдера аватара для пользователей без аватаров
  ///
  /// Используется как запасной вариант при отсутствии аватара пользователя.
  static const String userAvatarPlaceholder = 'https://k-connect.ru/static/uploads/system/album_placeholder.jpg';
}
