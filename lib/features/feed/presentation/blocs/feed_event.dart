/// События для управления состоянием ленты новостей
///
/// Определяет все возможные события, которые могут быть отправлены в FeedBloc
/// для управления загрузкой постов, комментариев, лайков и других операций.
library;

import 'package:equatable/equatable.dart';
import '../../domain/models/comment.dart';

/// Базовый класс для всех событий ленты новостей
abstract class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => [];
}

/// Событие загрузки дополнительных постов (пагинация)
class FetchPostsEvent extends FeedEvent {
  const FetchPostsEvent();
}

/// Событие лайка поста
class LikePostEvent extends FeedEvent {
  final int postId;

  const LikePostEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

/// Событие загрузки списка онлайн-пользователей
class FetchOnlineUsersEvent extends FeedEvent {
  const FetchOnlineUsersEvent();
}

/// Событие обновления ленты новостей (pull-to-refresh)
class RefreshFeedEvent extends FeedEvent {
  const RefreshFeedEvent();
}

/// Событие инициализации ленты новостей
class InitFeedEvent extends FeedEvent {
  const InitFeedEvent();
}

/// Событие загрузки комментариев для поста
class LoadCommentsEvent extends FeedEvent {
  final int postId;

  const LoadCommentsEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

/// Событие добавления нового комментария к посту
class AddCommentEvent extends FeedEvent {
  /// ID поста, к которому добавляется комментарий
  final int postId;

  /// Текст комментария
  final String content;

  const AddCommentEvent(this.postId, this.content);

  @override
  List<Object?> get props => [postId, content];
}

/// Событие добавления ответа на комментарий
class AddReplyEvent extends FeedEvent {
  /// ID комментария, на который добавляется ответ
  final int commentId;

  /// Текст ответа
  final String content;

  /// ID родительского ответа (для вложенных ответов)
  final int? parentReplyId;

  const AddReplyEvent(this.commentId, this.content, {this.parentReplyId});

  @override
  List<Object?> get props => [commentId, content, parentReplyId];
}

/// Событие установки комментария для ответа
class SetReplyingToEvent extends FeedEvent {
  /// Комментарий, на который пользователь хочет ответить (null для отмены)
  final Comment? comment;

  const SetReplyingToEvent(this.comment);

  @override
  List<Object?> get props => [comment];
}

/// Событие отмены ответа
class ClearReplyingToEvent extends FeedEvent {
  const ClearReplyingToEvent();
}

/// Событие начала режима ответа
class StartReplyModeEvent extends FeedEvent {
  /// Комментарий, на который пользователь хочет ответить
  final Comment comment;

  const StartReplyModeEvent(this.comment);

  @override
  List<Object?> get props => [comment];
}

/// Событие отмены режима ответа
class CancelReplyModeEvent extends FeedEvent {
  const CancelReplyModeEvent();
}

/// Событие отправки ответа
class SendReplyEvent extends FeedEvent {
  /// Текст ответа
  final String text;

  const SendReplyEvent(this.text);

  @override
  List<Object?> get props => [text];
}

/// Событие удаления комментария
class DeleteCommentEvent extends FeedEvent {
  final int commentId;

  const DeleteCommentEvent(this.commentId);

  @override
  List<Object?> get props => [commentId];
}

/// Событие лайка комментария
class LikeCommentEvent extends FeedEvent {
  final int commentId;

  const LikeCommentEvent(this.commentId);

  @override
  List<Object?> get props => [commentId];
}

/// Событие голосования в опросе
class VotePollEvent extends FeedEvent {
  /// ID поста, содержащего опрос
  final int postId;

  /// ID опроса
  final int pollId;

  /// Список ID выбранных вариантов ответа
  final List<int> optionIds;

  /// Флаг множественного выбора
  final bool isMultipleChoice;

  /// Флаг наличия существующих голосов
  final bool hasExistingVotes;

  const VotePollEvent(this.postId, this.pollId, this.optionIds, {this.isMultipleChoice = false, this.hasExistingVotes = false});

  @override
  List<Object?> get props => [postId, pollId, optionIds, isMultipleChoice, hasExistingVotes];
}
