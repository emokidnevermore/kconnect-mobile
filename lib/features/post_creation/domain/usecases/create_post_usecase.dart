import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../feed/domain/models/post.dart';
import '../models/create_post_params.dart';
import '../repositories/post_repository.dart';

/// UseCase для создания поста
class CreatePostUsecase implements UseCase<Post, CreatePostParams> {
  final PostRepository repository;

  CreatePostUsecase(this.repository);

  @override
  Future<Either<Failure, Post>> call(CreatePostParams params) async {
    return repository.createPost(params);
  }
}
