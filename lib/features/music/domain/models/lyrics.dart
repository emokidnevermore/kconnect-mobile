/// Модели данных для работы с лирикой треков
///
/// Поддерживает как обычную лирику, так и синхронизированную
/// с привязкой к времени воспроизведения.
library;

/// Данные лирики для трека
class LyricsData {
  /// Есть ли обычная лирика (текст)
  final bool hasLyrics;

  /// Есть ли синхронизированная лирика (с временем)
  final bool hasSyncedLyrics;

  /// Обычная лирика в виде текста
  final String? lyrics;

  /// URL для загрузки лирики (если нужно)
  final String? lyricsUrl;

  /// Синхронизированная лирика с привязкой ко времени
  final List<SyncedLyricLine>? syncedLyrics;

  /// ID трека
  final int? trackId;

  const LyricsData({
    required this.hasLyrics,
    required this.hasSyncedLyrics,
    this.lyrics,
    this.lyricsUrl,
    this.syncedLyrics,
    this.trackId,
  });

  /// Создание из JSON ответа API
  factory LyricsData.fromJson(Map<String, dynamic> json) {
    return LyricsData(
      hasLyrics: json['has_lyrics'] as bool? ?? false,
      hasSyncedLyrics: json['has_synced_lyrics'] as bool? ?? false,
      lyrics: json['lyrics'] as String?,
      lyricsUrl: json['lyrics_url'] as String?,
      syncedLyrics: json['synced_lyrics'] != null
          ? (json['synced_lyrics'] as List)
              .map((item) => SyncedLyricLine.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      trackId: json['track_id'] as int?,
    );
  }

  /// Проверка наличия какой-либо лирики
  bool get hasAnyLyrics => hasLyrics || hasSyncedLyrics;

  /// Получение текущей строки синхронизированной лирики по времени
  SyncedLyricLine? getCurrentLine(int currentTimeMs) {
    if (syncedLyrics == null || syncedLyrics!.isEmpty) return null;

    // Находим строку, которая должна отображаться в данный момент
    return syncedLyrics!.lastWhere(
      (line) => line.startTimeMs <= currentTimeMs,
      orElse: () => syncedLyrics!.first,
    );
  }

  /// Получение следующей строки
  SyncedLyricLine? getNextLine(int currentTimeMs) {
    if (syncedLyrics == null || syncedLyrics!.isEmpty) return null;

    // Находим текущую строку тем же способом, что и getCurrentLine
    final currentLine = getCurrentLine(currentTimeMs);
    if (currentLine == null) return null;

    final currentIndex = syncedLyrics!.indexOf(currentLine);
    if (currentIndex == -1 || currentIndex >= syncedLyrics!.length - 1) {
      return null;
    }

    // Ищем следующую строку, пропуская пустые
    for (int i = currentIndex + 1; i < syncedLyrics!.length; i++) {
      if (!syncedLyrics![i].isEmpty) {
        return syncedLyrics![i];
      }
    }

    return null;
  }

  /// Получение предыдущей строки
  SyncedLyricLine? getPreviousLine(int currentTimeMs) {
    if (syncedLyrics == null || syncedLyrics!.isEmpty) return null;

    // Находим текущую строку тем же способом, что и getCurrentLine
    final currentLine = getCurrentLine(currentTimeMs);
    if (currentLine == null) return null;

    final currentIndex = syncedLyrics!.indexOf(currentLine);
    if (currentIndex <= 0) return null;

    // Ищем предыдущую строку, пропуская пустые
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (!syncedLyrics![i].isEmpty) {
        return syncedLyrics![i];
      }
    }

    return null;
  }
}

/// Одна строка синхронизированной лирики
class SyncedLyricLine {
  /// Уникальный ID строки
  final String lineId;

  /// Время начала отображения строки в миллисекундах
  final int startTimeMs;

  /// Текст строки
  final String text;

  const SyncedLyricLine({
    required this.lineId,
    required this.startTimeMs,
    required this.text,
  });

  /// Создание из JSON
  factory SyncedLyricLine.fromJson(Map<String, dynamic> json) {
    return SyncedLyricLine(
      lineId: json['lineId'] as String,
      startTimeMs: json['startTimeMs'] as int,
      text: json['text'] as String,
    );
  }

  /// Преобразование в JSON
  Map<String, dynamic> toJson() {
    return {
      'lineId': lineId,
      'startTimeMs': startTimeMs,
      'text': text,
    };
  }

  /// Проверка, является ли строка пустой (заголовок/подвал)
  bool get isEmpty => text.trim().isEmpty;

  /// Форматированное время для отладки
  String get formattedTime {
    final seconds = startTimeMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final ms = startTimeMs % 1000;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }

  @override
  String toString() {
    return '[$formattedTime] $text';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncedLyricLine && other.lineId == lineId;
  }

  @override
  int get hashCode => lineId.hashCode;
}
