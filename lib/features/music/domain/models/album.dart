/// Модель альбома
///
/// Представляет музыкальный альбом с информацией о треках,
/// обложке, жанре и других метаданных.
library;

import 'package:equatable/equatable.dart';
import 'track.dart';

/// Модель альбома
class Album extends Equatable {
  final int id;
  final String title;
  final String? coverUrl;
  final String? coverPath;
  final String albumType;
  final int artistId;
  final String artistName;
  final int duration;
  final String? genre;
  final String? description;
  final DateTime? releaseDate;
  final int tracksCount;
  final List<Track> previewTracks;
  final bool autoCreated;

  const Album({
    required this.id,
    required this.title,
    this.coverUrl,
    this.coverPath,
    required this.albumType,
    required this.artistId,
    required this.artistName,
    required this.duration,
    this.genre,
    this.description,
    this.releaseDate,
    required this.tracksCount,
    required this.previewTracks,
    required this.autoCreated,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    final previewTracksData = json['preview_tracks'] as List<dynamic>? ?? [];
    final previewTracks = <Track>[];
    
    for (final trackData in previewTracksData) {
      try {
        if (trackData is Map<String, dynamic>) {
          // Preview tracks могут иметь упрощенную структуру, создаем минимальный Track
          final track = Track(
            id: trackData['id'] as int? ?? 0,
            title: trackData['title'] as String? ?? '',
            artist: json['artist_name'] as String? ?? '',
            durationMs: (trackData['duration'] as int? ?? 0) * 1000, // конвертируем секунды в миллисекунды
            coverPath: trackData['cover_path'] as String?,
            filePath: '',
            isLiked: false,
            playsCount: 0,
            likesCount: 0,
          );
          previewTracks.add(track);
        }
      } catch (e) {
        // Пропускаем треки, которые не удалось распарсить
        continue;
      }
    }

    DateTime? releaseDate;
    if (json['release_date'] != null) {
      try {
        releaseDate = DateTime.parse(json['release_date'] as String);
      } catch (e) {
        releaseDate = null;
      }
    }

    return Album(
      id: json['id'] as int,
      title: json['title'] as String,
      coverUrl: json['cover_url'] as String?,
      coverPath: json['cover_path'] as String?,
      albumType: json['album_type'] as String? ?? 'album',
      artistId: json['artist_id'] as int,
      artistName: json['artist_name'] as String,
      duration: json['duration'] as int? ?? 0,
      genre: json['genre'] as String?,
      description: json['description'] as String?,
      releaseDate: releaseDate,
      tracksCount: json['tracks_count'] as int? ?? 0,
      previewTracks: previewTracks,
      autoCreated: json['auto_created'] as bool? ?? false,
    );
  }

  String? get coverImageUrl => coverUrl ?? coverPath;

  @override
  List<Object?> get props => [
        id,
        title,
        coverUrl,
        coverPath,
        albumType,
        artistId,
        artistName,
        duration,
        genre,
        description,
        releaseDate,
        tracksCount,
        previewTracks,
        autoCreated,
      ];
}
