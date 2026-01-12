/// Модель детальной информации об исполнителе
///
/// Представляет полную информацию об исполнителе включая
/// социальные сети, биографию, жанры и список треков.
library;

import 'package:equatable/equatable.dart';
import 'track.dart';

/// Детальная модель исполнителя
class ArtistDetail extends Equatable {
  final int id;
  final String name;
  final String avatarUrl;
  final String bio;
  final List<String> genres;
  final bool verified;
  final String? instagram;
  final String? facebook;
  final String? twitter;
  final String? website;
  final List<Track> tracks;
  final int currentPage;
  final int tracksPages;
  final int tracksCount;

  const ArtistDetail({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.genres,
    required this.verified,
    this.instagram,
    this.facebook,
    this.twitter,
    this.website,
    required this.tracks,
    required this.currentPage,
    required this.tracksPages,
    required this.tracksCount,
  });

  factory ArtistDetail.fromJson(Map<String, dynamic> json) {
    final artistData = json['artist'] as Map<String, dynamic>;
    
    // Парсинг жанров - может быть массивом строк или массивом с одним элементом "[]"
    List<String> genres = [];
    if (artistData['genres'] != null) {
      final genresData = artistData['genres'] as List<dynamic>;
      genres = genresData
          .where((g) => g is String && g != '[]' && g.isNotEmpty)
          .map((g) => g as String)
          .toList();
    }

    // Парсинг треков
    final tracksData = artistData['tracks'] as List<dynamic>? ?? [];
    final tracks = tracksData
        .map((trackJson) => Track.fromJson(trackJson as Map<String, dynamic>))
        .toList();

    return ArtistDetail(
      id: artistData['id'] as int,
      name: artistData['name'] as String,
      avatarUrl: artistData['avatar_url'] as String? ?? '',
      bio: artistData['bio'] as String? ?? '',
      genres: genres,
      verified: artistData['verified'] as bool? ?? false,
      instagram: artistData['instagram'] as String?,
      facebook: artistData['facebook'] as String?,
      twitter: artistData['twitter'] as String?,
      website: artistData['website'] as String?,
      tracks: tracks,
      currentPage: artistData['current_page'] as int? ?? 1,
      tracksPages: artistData['tracks_pages'] as int? ?? 1,
      tracksCount: artistData['tracks_count'] as int? ?? 0,
    );
  }

  ArtistDetail copyWith({
    int? id,
    String? name,
    String? avatarUrl,
    String? bio,
    List<String>? genres,
    bool? verified,
    String? instagram,
    String? facebook,
    String? twitter,
    String? website,
    List<Track>? tracks,
    int? currentPage,
    int? tracksPages,
    int? tracksCount,
  }) {
    return ArtistDetail(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      genres: genres ?? this.genres,
      verified: verified ?? this.verified,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      twitter: twitter ?? this.twitter,
      website: website ?? this.website,
      tracks: tracks ?? this.tracks,
      currentPage: currentPage ?? this.currentPage,
      tracksPages: tracksPages ?? this.tracksPages,
      tracksCount: tracksCount ?? this.tracksCount,
    );
  }

  /// Проверяет, есть ли следующая страница треков
  bool get hasNextPage => currentPage < tracksPages;

  @override
  List<Object?> get props => [
        id,
        name,
        avatarUrl,
        bio,
        genres,
        verified,
        instagram,
        facebook,
        twitter,
        website,
        tracks,
        currentPage,
        tracksPages,
        tracksCount,
      ];
}
