import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../feed/domain/models/post.dart';
import '../../domain/models/create_post_params.dart';
import '../../domain/repositories/post_repository.dart';
import '../../../../services/posts_service.dart';

/// Реализация репозитория постов
class PostRepositoryImpl implements PostRepository {
  final PostsService _postsService;

  PostRepositoryImpl(this._postsService);

  @override
  Future<Either<Failure, Post>> createPost(CreatePostParams params) async {
    try {
      final response = await _postsService.createPost(
        content: params.content,
        isNsfw: params.isNsfw,
        imagePaths: params.imagePaths,
        musicTracks: params.musicTracks,
      );

      final post = Post.fromJson(response);
      return Right(post);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
