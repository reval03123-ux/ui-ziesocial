import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/model/post_model.dart';

class PostViewModel extends ChangeNotifier {
  final ApiClient _apiClient;

  PostViewModel(this._apiClient);

  List<PostModel> _posts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchPosts({int? currentUserId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = currentUserId != null && currentUserId > 0
          ? '${ApiConstants.getPosts}?user_id=$currentUserId'
          : ApiConstants.getPosts;
      final response = await _apiClient.get(url);
      final postResponse = PostResponse.fromJson(response);
      _posts = postResponse.data;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleLike({required PostModel post, required int userId}) async {
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index == -1) return false;

    final wasLiked = post.isLiked;
    final originalCount = post.likeCount;

    // Optimistic update
    final newLiked = !wasLiked;
    final newCount = newLiked ? originalCount + 1 : (originalCount > 0 ? originalCount - 1 : 0);
    _posts[index] = post.copyWith(isLiked: newLiked, likeCount: newCount);
    notifyListeners();

    try {
      await _apiClient.post(
        ApiConstants.toggleLike,
        body: {'user_id': userId, 'post_id': post.id},
      );
      return true;
    } catch (e) {
      // Rollback jika gagal
      _posts[index] = post.copyWith(isLiked: wasLiked, likeCount: originalCount);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePost({
    required int postId,
    required int userId,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.deletePost,
        body: {'post_id': postId, 'user_id': userId},
      );

      if (response['status'] == true || response['message'] != null) {
        _posts.removeWhere((p) => p.id == postId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }

  Future<List<CommentModel>> getComments(int postId) async {
    try {
      final response = await _apiClient.get('${ApiConstants.getComments}?post_id=$postId');
      final list = (response['data'] as List<dynamic>?)
              ?.map((item) => CommentModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<bool> addComment({
    required int postId,
    required int userId,
    required String text,
  }) async {
    try {
      await _apiClient.post(
        ApiConstants.addComment,
        body: {'post_id': postId, 'user_id': userId, 'text': text},
      );

      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _posts[index] = _posts[index].copyWith(
          commentCount: _posts[index].commentCount + 1,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteComment({
    required int commentId,
    required int postId,
    required int userId,
  }) async {
    try {
      await _apiClient.post(
        ApiConstants.deleteComment,
        body: {'comment_id': commentId, 'user_id': userId},
      );

      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final currentCount = _posts[index].commentCount;
        _posts[index] = _posts[index].copyWith(
          commentCount: currentCount > 0 ? currentCount - 1 : 0,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> editComment({
    required int commentId,
    required int userId,
    required String text,
  }) async {
    try {
      await _apiClient.post(
        ApiConstants.editComment,
        body: {
          'comment_id': commentId,
          'user_id': userId,
          'text': text,
        },
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
