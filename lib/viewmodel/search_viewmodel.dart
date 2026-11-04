import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/model/profile_model.dart';

class SearchViewModel extends ChangeNotifier {
  final ApiClient _apiClient;

  SearchViewModel(this._apiClient);

  List<SearchUserModel> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SearchUserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> searchUsers(String query, {int? currentUserId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final qParam = Uri.encodeComponent(query);
      final url = currentUserId != null && currentUserId > 0
          ? '${ApiConstants.searchUsers}?q=$qParam&current_user_id=$currentUserId'
          : '${ApiConstants.searchUsers}?q=$qParam';

      final response = await _apiClient.get(url);
      final data = (response['data'] as List<dynamic>?)
              ?.map((item) => SearchUserModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];

      // Filter out self if logged in
      if (currentUserId != null && currentUserId > 0) {
        _users = data.where((u) => u.id != currentUserId).toList();
      } else {
        _users = data;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleFollowUser({
    required int followerId,
    required SearchUserModel targetUser,
  }) async {
    final index = _users.indexWhere((u) => u.id == targetUser.id);
    if (index == -1) return false;

    final wasFollowing = targetUser.isFollowing;
    final currentFollowers = targetUser.followersCount;
    final newFollowing = !wasFollowing;
    final newCount = newFollowing
        ? currentFollowers + 1
        : (currentFollowers > 0 ? currentFollowers - 1 : 0);

    // Optimistic update
    _users[index] = targetUser.copyWith(
      isFollowing: newFollowing,
      followersCount: newCount,
    );
    notifyListeners();

    try {
      await _apiClient.post(
        ApiConstants.toggleFollow,
        body: {
          'follower_id': followerId,
          'following_id': targetUser.id,
        },
      );
      return true;
    } catch (e) {
      // Rollback
      _users[index] = targetUser.copyWith(
        isFollowing: wasFollowing,
        followersCount: currentFollowers,
      );
      notifyListeners();
      return false;
    }
  }
}
