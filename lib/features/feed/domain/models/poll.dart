import 'poll_option.dart';

/// Модель опроса
///
/// Представляет опрос с вопросом, вариантами ответов и информацией о голосовании.
class Poll {
  /// Уникальный идентификатор опроса
  final int id;

  /// Вопрос опроса
  final String question;

  /// Список вариантов ответа
  final List<PollOption> options;

  /// Дата и время истечения опроса
  final String? expiresAt;

  /// Флаг, истек ли опрос
  final bool isExpired;

  /// Флаг, разрешен ли множественный выбор
  final bool isMultipleChoice;

  /// Флаг, является ли опрос анонимным
  final bool isAnonymous;

  /// Общее количество голосов
  final int totalVotes;

  /// Флаг, проголосовал ли текущий пользователь
  final bool userVoted;

  /// Список ID вариантов, за которые проголосовал пользователь
  final List<int> userVoteOptionIds;

  Poll({
    required this.id,
    required this.question,
    required this.options,
    this.expiresAt,
    required this.isExpired,
    required this.isMultipleChoice,
    required this.isAnonymous,
    required this.totalVotes,
    required this.userVoted,
    required this.userVoteOptionIds,
  });

  factory Poll.fromJson(Map<String, dynamic> json) {
    final optionsData = json['options'] as List<dynamic>? ?? [];
    final options = optionsData.map((optionJson) => PollOption.fromJson(optionJson)).toList();

    final userVoteOptionIdsData = json['user_vote_option_ids'] as List<dynamic>? ?? [];
    final userVoteOptionIds = userVoteOptionIdsData.map((id) => id as int).toList();

    return Poll(
      id: json['id'] ?? 0,
      question: json['question'] ?? '',
      options: options,
      expiresAt: json['expires_at'] as String?,
      isExpired: json['is_expired'] ?? false,
      isMultipleChoice: json['is_multiple_choice'] ?? false,
      isAnonymous: json['is_anonymous'] ?? false,
      totalVotes: json['total_votes'] ?? 0,
      userVoted: json['user_voted'] ?? false,
      userVoteOptionIds: userVoteOptionIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options.map((option) => option.toJson()).toList(),
      'expires_at': expiresAt,
      'is_expired': isExpired,
      'is_multiple_choice': isMultipleChoice,
      'is_anonymous': isAnonymous,
      'total_votes': totalVotes,
      'user_voted': userVoted,
      'user_vote_option_ids': userVoteOptionIds,
    };
  }

  Poll copyWith({
    int? id,
    String? question,
    List<PollOption>? options,
    String? expiresAt,
    bool? isExpired,
    bool? isMultipleChoice,
    bool? isAnonymous,
    int? totalVotes,
    bool? userVoted,
    List<int>? userVoteOptionIds,
  }) {
    return Poll(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      expiresAt: expiresAt ?? this.expiresAt,
      isExpired: isExpired ?? this.isExpired,
      isMultipleChoice: isMultipleChoice ?? this.isMultipleChoice,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      totalVotes: totalVotes ?? this.totalVotes,
      userVoted: userVoted ?? this.userVoted,
      userVoteOptionIds: userVoteOptionIds ?? this.userVoteOptionIds,
    );
  }
}
