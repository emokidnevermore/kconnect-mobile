import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../feed/domain/models/post.dart';
import '../models/create_post_params.dart';

/// Репозиторий для работы с постами
abstract class PostRepository {
  /// Создает новый пост
  Future<Either<Failure, Post>> createPost(CreatePostParams params);
}
