/// Режимы отображения таб-бара и кнопок
///
/// Определяет три варианта стилизации:
/// - glass: полный эффект жидкого стекла
/// - fakeGlass: легковесный эффект стекла
/// - solid: темный фон с прозрачностью
library;

enum TabBarGlassMode {
  /// Полный эффект жидкого стекла через LiquidGlass
  glass,

  /// Легковесный эффект стекла через FakeGlass
  fakeGlass,

  /// Темный фон с прозрачностью
  solid;

  /// Преобразует строку в enum
  static TabBarGlassMode fromString(String value) {
    return TabBarGlassMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => TabBarGlassMode.solid, // По умолчанию solid
    );
  }

  /// Преобразует enum в строку для хранения
  String toStorageString() => name;
}

