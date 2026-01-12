/// Модель варианта опроса
///
/// Представляет один вариант ответа в опросе с информацией о количестве голосов и проценте.
class PollOption {
  /// Уникальный идентификатор варианта
  final int id;

  /// Текст варианта ответа
  final String text;

  /// Количество голосов за этот вариант
  final int votesCount;

  /// Процент голосов (0-100)
  final double percentage;

  PollOption({
    required this.id,
    required this.text,
    required this.votesCount,
    required this.percentage,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] ?? 0,
      text: json['text'] ?? '',
      votesCount: json['votes_count'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'votes_count': votesCount,
      'percentage': percentage,
    };
  }

  PollOption copyWith({
    int? id,
    String? text,
    int? votesCount,
    double? percentage,
  }) {
    return PollOption(
      id: id ?? this.id,
      text: text ?? this.text,
      votesCount: votesCount ?? this.votesCount,
      percentage: percentage ?? this.percentage,
    );
  }
}
