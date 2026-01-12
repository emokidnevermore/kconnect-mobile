/// Модель данных для жалоб на посты
///
/// Содержит информацию о жалобе, включая тип жалобы,
/// описание и данные поста для модераторов.
library;

import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

/// Перечисление типов жалоб
enum ComplaintType {
  spam('Спам', Icons.mail, 'Нежелательная реклама или повторяющиеся сообщения'),
  insult('Оскорбление', Icons.sentiment_very_dissatisfied, 'Обидные или унижающие высказывания'),
  inappropriate('Неприемлемый контент', Icons.visibility_off, 'Контент для взрослых или не подходящий для всех'),
  rulesViolation('Нарушение правил', Icons.gavel, 'Нарушение правил сообщества'),
  misinformation('Дезинформация', Icons.warning, 'Ложная информация или фейковые новости'),
  malicious('Вредоносный контент', Icons.security, 'Вредоносные ссылки или вредоносный код'),
  other('Другое', Icons.more_horiz, null);

  const ComplaintType(this.displayName, this.icon, this.description);

  final String displayName;
  final IconData icon;
  final String? description;

  /// Получить значение для API
  String get apiValue {
    switch (this) {
      case ComplaintType.spam:
        return 'Спам';
      case ComplaintType.insult:
        return 'Оскорбление';
      case ComplaintType.inappropriate:
        return 'Неприемлемый контент';
      case ComplaintType.rulesViolation:
        return 'Нарушение правил';
      case ComplaintType.misinformation:
        return 'Дезинформация';
      case ComplaintType.malicious:
        return 'Вредоносный контент';
      case ComplaintType.other:
        return 'Другое';
    }
  }
}

/// Запрос на создание жалобы
class ComplaintRequest extends Equatable {
  final String targetType;
  final int targetId;
  final String reason;
  final String? description;
  final String? evidence;

  const ComplaintRequest({
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
    this.evidence,
  });

  @override
  List<Object?> get props => [targetType, targetId, reason, description, evidence];

  /// Преобразовать в JSON для API
  Map<String, dynamic> toJson() {
    return {
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      if (description != null) 'description': description,
      if (evidence != null) 'evidence': evidence,
    };
  }

  /// Создать копию с изменениями
  ComplaintRequest copyWith({
    String? targetType,
    int? targetId,
    String? reason,
    String? description,
    String? evidence,
  }) {
    return ComplaintRequest(
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      reason: reason ?? this.reason,
      description: description,
      evidence: evidence ?? this.evidence,
    );
  }
}

/// Ответ API на создание жалобы
class ComplaintResponse extends Equatable {
  final int complaintId;
  final String message;
  final bool success;
  final int? ticketId;

  const ComplaintResponse({
    required this.complaintId,
    required this.message,
    required this.success,
    this.ticketId,
  });

  @override
  List<Object?> get props => [complaintId, message, success, ticketId];

  /// Создать из JSON ответа API
  factory ComplaintResponse.fromJson(Map<String, dynamic> json) {
    return ComplaintResponse(
      complaintId: json['complaint_id'] as int,
      message: json['message'] as String,
      success: json['success'] as bool,
      ticketId: json['ticket_id'] as int?,
    );
  }
}
