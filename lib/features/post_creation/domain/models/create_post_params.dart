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

  /// Музыкальные треки
  final List<Track> musicTracks;

  const CreatePostParams({
    required this.content,
    required this.isNsfw,
    required this.imagePaths,
    required this.musicTracks,
  });

  @override
  List<Object?> get props => [content, isNsfw, imagePaths, musicTracks];
}
