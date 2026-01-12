import 'package:equatable/equatable.dart';
import '../../../music/domain/models/track.dart';

/// Параметры для создания поста
class CreatePostParams extends Equatable {
  /// Текст поста (markdown)
  final String content;

  /// Флаг NSFW контента
  final bool isNsfw;

  /// Пути к изображениям
  final List<String> imagePaths;

  /// Путь к видео файлу
  final String? videoPath;

  /// Путь к превью видео (thumbnail)
  final String? videoThumbnailPath;

  /// Музыкальные треки
  final List<Track> musicTracks;

  /// Вопрос опроса
  final String? pollQuestion;

  /// Варианты ответов опроса
  final List<String> pollOptions;

  /// Флаг анонимности опроса
  final bool pollIsAnonymous;

  /// Флаг множественного выбора
  final bool pollIsMultiple;

  /// Срок окончания опроса в днях
  final int? pollExpiresInDays;

  const CreatePostParams({
    required this.content,
    required this.isNsfw,
    required this.imagePaths,
    this.videoPath,
    this.videoThumbnailPath,
    required this.musicTracks,
    this.pollQuestion,
    this.pollOptions = const [],
    this.pollIsAnonymous = false,
    this.pollIsMultiple = false,
    this.pollExpiresInDays,
  });

  @override
  List<Object?> get props => [
    content,
    isNsfw,
    imagePaths,
    videoPath,
    videoThumbnailPath,
    musicTracks,
    pollQuestion,
    pollOptions,
    pollIsAnonymous,
    pollIsMultiple,
    pollExpiresInDays,
  ];
}
