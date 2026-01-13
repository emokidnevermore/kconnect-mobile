import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../auth/presentation/blocs/auth_state.dart';
import '../../domain/usecases/fetch_posts_usecase.dart';
import '../../domain/models/online_user.dart';
import '../../domain/models/post.dart';
import '../../domain/models/comment.dart';
import 'feed_event.dart';
import 'feed_state.dart';

/// BLoC для управления состоянием ленты новостей
///
/// Отвечает за загрузку постов, комментариев, обработку лайков,
/// пагинацию и взаимодействие с системой аутентификации.
/// Управляет состоянием UI ленты новостей в реальном времени.
class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final FetchPostsUseCase _fetchPostsUseCase;
  final LikePostUseCase _likePostUseCase;

  final FetchOnlineUsersUseCase _fetchOnlineUsersUseCase;

  final FetchCommentsUseCase _fetchCommentsUseCase;
  final AddCommentUseCase _addCommentUseCase;
  final AddReplyUseCase _addReplyUseCase;
  final DeleteCommentUseCase _deleteCommentUseCase;
  final LikeCommentUseCase _likeCommentUseCase;
  final VotePollUseCase _votePollUseCase;

  /// BLoC аутентификации для отслеживания изменений пользователя
  final AuthBloc _authBloc;

  /// Конструктор FeedBloc
  FeedBloc(
    this._fetchPostsUseCase,
    this._likePostUseCase,
    this._fetchOnlineUsersUseCase,
    this._fetchCommentsUseCase,
    this._addCommentUseCase,
    this._addReplyUseCase,
    this._deleteCommentUseCase,
    this._likeCommentUseCase,
    this._votePollUseCase,
    this._authBloc,
  ) : super(const FeedState()) {
    // Подписка на изменения состояния аутентификации для перезагрузки ленты
    _authBloc.stream.listen(_onAuthStateChanged);

    // Регистрация обработчиков событий
    on<InitFeedEvent>(_onInitFeed);
    on<FetchPostsEvent>(_onFetchPosts);
    on<LikePostEvent>(_onLikePost);
    on<FetchOnlineUsersEvent>(_onFetchOnlineUsers);
    on<RefreshFeedEvent>(_onRefreshFeed);
    on<LoadCommentsEvent>(_onLoadComments);
    on<AddCommentEvent>(_onAddComment);
    on<AddReplyEvent>(_onAddReply);
    on<SetReplyingToEvent>(_onSetReplyingTo);
    on<ClearReplyingToEvent>(_onClearReplyingTo);
    on<StartReplyModeEvent>(_onStartReplyMode);
    on<CancelReplyModeEvent>(_onCancelReplyMode);
    on<SendReplyEvent>(_onSendReply);
    on<DeleteCommentEvent>(_onDeleteComment);
    on<LikeCommentEvent>(_onLikeComment);
    on<VotePollEvent>(_onVotePoll);
  }

  /// Обработчик изменений состояния аутентификации
  ///
  /// Следит за изменениями пользователя и перезагружает ленту при необходимости.
  /// При смене пользователя перезагружает ленту для отображения актуального контента.
  void _onAuthStateChanged(AuthState authState) {
    debugPrint('FeedBloc: Auth state changed: $authState');

    if (authState is AuthAuthenticated) {
      if (state.posts.isNotEmpty) {
        debugPrint('FeedBloc: Reloading feed for new user');
        add(const InitFeedEvent());
      }
    } else if (authState is AuthUnauthenticated || authState is AuthInitial) {
      debugPrint('FeedBloc: User logged out, clearing feed');
    }
  }

  /// Обработчик инициализации ленты новостей
  ///
  /// Загружает первую страницу постов и список онлайн-пользователей.
  /// При наличии существующих постов показывает индикатор обновления,
  /// иначе полностью сбрасывает состояние.
  Future<void> _onInitFeed(
    InitFeedEvent event,
    Emitter<FeedState> emit,
  ) async {
    final hasExistingPosts = state.posts.isNotEmpty;
    if (hasExistingPosts) {
      emit(state.copyWith(
        isRefreshing: true,
        status: FeedStatus.loading,
        error: null,
      ));
    } else {
      emit(const FeedState());
    }

    try {
      final posts = await _fetchPostsUseCase(page: 1);
      emit(state.copyWith(
        posts: posts,
        status: FeedStatus.success,
        page: 1,
        isRefreshing: false,
        error: null,
      ));
    } catch (e) {
      if (hasExistingPosts) {
        emit(state.copyWith(
          status: FeedStatus.success,
          isRefreshing: false,
          error: e.toString(),
        ));
      } else {
        emit(state.copyWith(
          status: FeedStatus.failure,
          isRefreshing: false,
          error: e.toString(),
        ));
      }
    }
    add(FetchOnlineUsersEvent());
  }

  Future<void> _onFetchPosts(
    FetchPostsEvent event,
    Emitter<FeedState> emit,
  ) async {
    try {
      if (!state.hasNext) return;

      emit(state.copyWith(
        isLoadingMore: state.posts.isNotEmpty,
        status: state.posts.isEmpty ? FeedStatus.loading : state.status,
        paginationStatus: PaginationStatus.loading,
      ));

      final newPosts = await _fetchPostsUseCase(page: state.page + 1);

      if (newPosts.isEmpty) {
        emit(state.copyWith(
          hasNext: false,
          isLoadingMore: false,
          paginationStatus: PaginationStatus.idle,
        ));
        return;
      }

      // Фильтруем дубликаты: исключаем посты, которые уже есть в списке
      final existingPostIds = state.posts.map((post) => post.id).toSet();
      final uniqueNewPosts = newPosts.where((post) => !existingPostIds.contains(post.id)).toList();

      final allPosts = [...state.posts, ...uniqueNewPosts];
      final nextPage = state.page + 1;

      emit(state.copyWith(
        posts: allPosts,
        page: nextPage,
        status: FeedStatus.success,
        isLoadingMore: false,
        paginationStatus: PaginationStatus.idle,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: state.posts.isEmpty ? FeedStatus.failure : state.status,
        error: e.toString(),
        isLoadingMore: false,
        paginationStatus: PaginationStatus.failed,
      ));
    }
  }

  Future<void> _onLikePost(
    LikePostEvent event,
    Emitter<FeedState> emit,
  ) async {
    if (state.processingPostLikes.contains(event.postId)) {
      return;
    }

    final postIndex = state.posts.indexWhere((post) => post.id == event.postId);
    if (postIndex == -1) return;

    final post = state.posts[postIndex];

    final processingLikes = {...state.processingPostLikes, event.postId};
    emit(state.copyWith(processingPostLikes: processingLikes));

    try {
      final optimisticPost = post.copyWith(
        isLiked: !post.isLiked,
        likesCount: post.isLiked ? post.likesCount - 1 : post.likesCount + 1,
      );
      final optimisticPosts = state.posts.map((p) => p.id == event.postId ? optimisticPost : p).toList();
      emit(state.copyWith(posts: optimisticPosts));

      final serverPost = await _likePostUseCase(event.postId);

      final serverUpdatedPost = post.copyWith(
        isLiked: !post.isLiked,
        likesCount: serverPost.likesCount,
        dislikesCount: serverPost.dislikesCount,
      );

      final finalPosts = state.posts.map((p) => p.id == event.postId ? serverUpdatedPost : p).toList();

      emit(state.copyWith(
        posts: finalPosts,
        processingPostLikes: state.processingPostLikes.where((id) => id != event.postId).toSet(),
      ));
    } catch (e) {
      final revertedPost = post.copyWith(
        isLiked: !post.isLiked,
        likesCount: post.isLiked ? post.likesCount - 1 : post.likesCount + 1,
      );
      final revertedPosts = state.posts.map((p) => p.id == event.postId ? revertedPost : p).toList();

      emit(state.copyWith(
        posts: revertedPosts,
        processingPostLikes: state.processingPostLikes.where((id) => id != event.postId).toSet(),
      ));
    }
  }

  Future<void> _onFetchOnlineUsers(
    FetchOnlineUsersEvent event,
    Emitter<FeedState> emit,
  ) async {
    if (state.onlineUsers.isNotEmpty) return;

    try {
      final onlineUsersData = await _fetchOnlineUsersUseCase();
      final onlineUsers = onlineUsersData.map((userJson) => OnlineUser.fromJson(userJson)).toList();
      emit(state.copyWith(onlineUsers: onlineUsers));
    } catch (e) {
      //Ошибка
    }
  }

  Future<void> _onRefreshFeed(
    RefreshFeedEvent event,
    Emitter<FeedState> emit,
  ) async {
    final hasExistingPosts = state.posts.isNotEmpty;
    
    if (hasExistingPosts) {
      emit(state.copyWith(
        isRefreshing: true,
        status: FeedStatus.loading,
        error: null,
      ));
    } else {
      emit(state.copyWith(
        status: FeedStatus.loading,
        isRefreshing: false,
        error: null,
      ));
    }

    try {
      final posts = await _fetchPostsUseCase(page: 1);
      final onlineUsersData = await _fetchOnlineUsersUseCase();
      final onlineUsers = onlineUsersData.map((userJson) => OnlineUser.fromJson(userJson)).toList();

      emit(state.copyWith(
        posts: posts,
        onlineUsers: onlineUsers,
        status: FeedStatus.success,
        page: 1,
        isRefreshing: false,
        error: null,
      ));
    } catch (e) {
      if (hasExistingPosts) {
        emit(state.copyWith(
          status: FeedStatus.success,
          isRefreshing: false,
          error: e.toString(),
        ));
      } else {
        emit(state.copyWith(
          status: FeedStatus.failure,
          isRefreshing: false,
          error: e.toString(),
        ));
      }
    }
  }

  Future<void> _onLoadComments(
    LoadCommentsEvent event,
    Emitter<FeedState> emit,
  ) async {
    try {
      emit(state.copyWith(
        commentsPostId: event.postId,
        comments: [],
        commentsStatus: CommentsStatus.loading,
        commentsPage: 1,
        commentsHasNext: false,
        commentsIsLoadingMore: false,
        commentsError: null,
      ));

      final comments = await _fetchCommentsUseCase(event.postId, page: 1);

      emit(state.copyWith(
        comments: comments,
        commentsPage: 1,
        commentsHasNext: false,
        commentsStatus: CommentsStatus.success,
        commentsIsLoadingMore: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        commentsStatus: CommentsStatus.failure,
        commentsError: e.toString(),
        commentsIsLoadingMore: false,
      ));
    }
  }

  Future<void> _onAddComment(
    AddCommentEvent event,
    Emitter<FeedState> emit,
  ) async {
    try {
      final newComment = await _addCommentUseCase(event.postId, event.content);
      final updatedComments = [newComment, ...state.comments];
      emit(state.copyWith(comments: updatedComments));

      final updatedPosts = state.posts.map((post) {
        if (post.id == event.postId) {
          return post.copyWith(commentsCount: post.commentsCount + 1);
        }
        return post;
      }).toList();
      emit(state.copyWith(posts: updatedPosts));
    } catch (e) {
      emit(state.copyWith(
        commentsError: e.toString(),
      ));
    }
  }

  Future<void> _onDeleteComment(
    DeleteCommentEvent event,
    Emitter<FeedState> emit,
  ) async {
    try {
      await _deleteCommentUseCase(event.commentId);
      final updatedComments = state.comments.where((c) => c.id != event.commentId).toList();
      emit(state.copyWith(comments: updatedComments));

      // Update post's comments count
      if (state.commentsPostId != null) {
        final updatedPosts = state.posts.map((post) {
          if (post.id == state.commentsPostId) {
            return post.copyWith(commentsCount: post.commentsCount - 1);
          }
          return post;
        }).toList();
        emit(state.copyWith(posts: updatedPosts));
      }
    } catch (e) {
      emit(state.copyWith(
        commentsError: e.toString(),
      ));
    }
  }

  Future<void> _onLikeComment(
    LikeCommentEvent event,
    Emitter<FeedState> emit,
  ) async {
    if (state.processingCommentLikes.contains(event.commentId)) {
      return;
    }

    final processingLikes = {...state.processingCommentLikes, event.commentId};
    emit(state.copyWith(processingCommentLikes: processingLikes));

    try {
      await _likeCommentUseCase(event.commentId);

      final updatedComments = state.comments.map((c) {
        if (c.id == event.commentId) {
          return c.copyWith(
            userLiked: !c.userLiked,
            likesCount: c.userLiked ? c.likesCount - 1 : c.likesCount + 1,
          );
        }
        return c;
      }).toList();

      emit(state.copyWith(
        comments: updatedComments,
        processingCommentLikes: state.processingCommentLikes.where((id) => id != event.commentId).toSet(),
      ));
    } catch (e) {
      emit(state.copyWith(
        processingCommentLikes: state.processingCommentLikes.where((id) => id != event.commentId).toSet(),
      ));
    }
  }

  Future<void> _onAddReply(
    AddReplyEvent event,
    Emitter<FeedState> emit,
  ) async {
    try {
      final newReply = await _addReplyUseCase(event.commentId, event.content, parentReplyId: event.parentReplyId);

      // Find the parent comment and add the reply to its replies list
      final updatedComments = state.comments.map((comment) {
        if (comment.id == event.commentId) {
          return comment.copyWith(
            replies: [...comment.replies, newReply],
          );
        }
        return comment;
      }).toList();

      emit(state.copyWith(comments: updatedComments, replyingTo: null));

      // Update post's comments count (replies also count as comments)
      if (state.commentsPostId != null) {
        final updatedPosts = state.posts.map((post) {
          if (post.id == state.commentsPostId) {
            return post.copyWith(commentsCount: post.commentsCount + 1);
          }
          return post;
        }).toList();
        emit(state.copyWith(posts: updatedPosts));
      }
    } catch (e) {
      emit(state.copyWith(
        commentsError: e.toString(),
      ));
    }
  }

  Future<void> _onSetReplyingTo(
    SetReplyingToEvent event,
    Emitter<FeedState> emit,
  ) async {
    emit(state.copyWith(replyingTo: event.comment));
  }

  void _onClearReplyingTo(
    ClearReplyingToEvent event,
    Emitter<FeedState> emit,
  ) {
    emit(state.copyWith(replyingTo: null));
  }

  void _onStartReplyMode(
    StartReplyModeEvent event,
    Emitter<FeedState> emit,
  ) {
    emit(state.copyWith(
      replyingTo: event.comment,
      replyMode: true,
    ));
  }

  void _onCancelReplyMode(
    CancelReplyModeEvent event,
    Emitter<FeedState> emit,
  ) {
    debugPrint('_onCancelReplyMode called - clearing reply mode');
    debugPrint('Before: replyingTo=${state.replyingTo?.id}, replyMode=${state.replyMode}');
    emit(state.copyWith(
      replyingTo: null,
      replyMode: false,
    ));
    debugPrint('After: replyingTo=${state.replyingTo}, replyMode=false');
  }

  Future<void> _onSendReply(
    SendReplyEvent event,
    Emitter<FeedState> emit,
  ) async {
    if (state.replyingTo == null) return;

    try {
      // Find the root comment that contains the replyingTo comment
      Comment? rootComment;
      int? parentReplyId;

      // Check if replyingTo is a root comment
      try {
        rootComment = state.comments.firstWhere((comment) => comment.id == state.replyingTo!.id);
      } catch (e) {
        rootComment = null;
      }

      if (rootComment != null) {
        // Replying to a root comment
        parentReplyId = null;
      } else {
        // Replying to a reply, find the root comment that contains this reply
        for (final comment in state.comments) {
          if (comment.replies.any((reply) => reply.id == state.replyingTo!.id)) {
            rootComment = comment;
            parentReplyId = state.replyingTo!.id;
            break;
          }
        }
      }

      if (rootComment != null) {
        final newReply = await _addReplyUseCase(rootComment.id, event.text, parentReplyId: parentReplyId);

        // Find the parent comment and add the reply to its replies list
        final updatedComments = state.comments.map((comment) {
          if (comment.id == rootComment!.id) {
            return comment.copyWith(
              replies: [...comment.replies, newReply],
            );
          }
          return comment;
        }).toList();

        emit(state.copyWith(
          comments: updatedComments,
          replyingTo: null,
          replyMode: false,
        ));

        // Update post's comments count (replies also count as comments)
        if (state.commentsPostId != null) {
          final updatedPosts = state.posts.map((post) {
            if (post.id == state.commentsPostId) {
              return post.copyWith(commentsCount: post.commentsCount + 1);
            }
            return post;
          }).toList();
          emit(state.copyWith(posts: updatedPosts));
        }
      }
    } catch (e) {
      emit(state.copyWith(
        commentsError: e.toString(),
      ));
    }
  }

  Future<void> _onVotePoll(
    VotePollEvent event,
    Emitter<FeedState> emit,
  ) async {
    final postIndex = state.posts.indexWhere((post) => post.id == event.postId);
    if (postIndex == -1) return;

    final post = state.posts[postIndex];
    
    // Проверяем, есть ли опрос в посте или в оригинальном посте (для репостов)
    final poll = post.poll ?? post.originalPost?.poll;
    if (poll == null || poll.id != event.pollId) return;

    try {
      // Оптимистичное обновление
      // Если пользователь уже проголосовал и меняет голос, обновляем существующий
      final optimisticPoll = poll.copyWith(
        userVoted: event.optionIds.isNotEmpty,
        userVoteOptionIds: event.optionIds,
      );
      
      Post updatedPost;
      if (post.poll != null) {
        // Обычный пост с опросом
        updatedPost = post.copyWith(poll: optimisticPoll);
      } else if (post.originalPost != null && post.originalPost!.poll != null) {
        // Репост с опросом в оригинальном посте
        updatedPost = post.copyWith(
          originalPost: post.originalPost!.copyWith(poll: optimisticPoll),
        );
      } else {
        return;
      }

      final optimisticPosts = state.posts.map((p) => p.id == event.postId ? updatedPost : p).toList();
      emit(state.copyWith(posts: optimisticPosts));

      // Получаем обновленные данные с сервера
      final serverPoll = await _votePollUseCase(event.pollId, event.optionIds, isMultipleChoice: event.isMultipleChoice, hasExistingVotes: event.hasExistingVotes);

      // Обновляем пост с данными с сервера
      Post finalPost;
      if (post.poll != null) {
        finalPost = post.copyWith(poll: serverPoll);
      } else if (post.originalPost != null) {
        finalPost = post.copyWith(
          originalPost: post.originalPost!.copyWith(poll: serverPoll),
        );
      } else {
        return;
      }

      final finalPosts = state.posts.map((p) => p.id == event.postId ? finalPost : p).toList();
      emit(state.copyWith(posts: finalPosts));
    } catch (e) {
      // В случае ошибки возвращаем исходное состояние
      final revertedPosts = state.posts.map((p) => p.id == event.postId ? post : p).toList();
      emit(state.copyWith(posts: revertedPosts));
    }
  }
}
