import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/model/post_model.dart';
import 'package:ziesocial/model/profile_model.dart';
import 'package:ziesocial/model/user_model.dart';

class ProfileViewModel extends ChangeNotifier {
  final ApiClient _apiClient;

  ProfileViewModel(this._apiClient);

  final Map<int, ProfileModel> _profiles = {};
  ProfileModel? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  ProfileModel? get profile => _profile;
  ProfileModel? getProfile(int userId) => _profiles[userId];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchProfile(int userId, {int? currentUserId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = currentUserId != null && currentUserId > 0
          ? '${ApiConstants.profile}?user_id=$userId&current_user_id=$currentUserId'
          : '${ApiConstants.profile}?user_id=$userId';

      final response = await _apiClient.get(url);
      if (response['data'] != null) {
        final profileModel =
            ProfileModel.fromJson(response['data'] as Map<String, dynamic>);
        _profiles[userId] = profileModel;
        _profile = profileModel;
      } else {
        _errorMessage = 'Profil tidak ditemukan.';
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> updateAvatar({
    required int userId,
    required Uint8List bytes,
    required String filename,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.uploadBytes(
        ApiConstants.updateAvatar,
        bytes: bytes,
        filename: filename,
        fieldName: 'avatar',
        fields: {'user_id': userId.toString()},
      );

      final newAvatar = response['avatar'] as String?;
      if (newAvatar != null) {
        if (_profiles.containsKey(userId)) {
          final current = _profiles[userId]!;
          _profiles[userId] = current.copyWith(
            user: current.user.copyWith(avatar: newAvatar),
          );
        }
        if (_profile != null && _profile!.user.id == userId.toString()) {
          _profile = _profile!.copyWith(
            user: _profile!.user.copyWith(avatar: newAvatar),
          );
        }
      }
      return newAvatar;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserModel?> updateProfile({
    required int userId,
    required String name,
    required String username,
    String? bio,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        ApiConstants.updateProfile,
        body: {
          'user_id': userId,
          'name': name,
          'username': username,
          'bio': ?bio,
        },
      );

      if (response['user'] != null) {
        final updatedUser =
            UserModel.fromJson(response['user'] as Map<String, dynamic>);
        if (_profiles.containsKey(userId)) {
          final current = _profiles[userId]!;
          _profiles[userId] = current.copyWith(user: updatedUser);
        }
        if (_profile != null && _profile!.user.id == userId.toString()) {
          _profile = _profile!.copyWith(user: updatedUser);
        }
        return updatedUser;
      }
      _errorMessage = response['message'] ?? 'Gagal memperbarui profil.';
      return null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleFollow({
    required int followerId,
    required int followingId,
  }) async {
    final targetProfile = _profiles[followingId] ?? _profile;
    if (targetProfile == null) return false;

    final wasFollowing = targetProfile.stats.isFollowing;
    final currentFollowers = targetProfile.stats.followersCount;

    // Optimistic Update
    final newFollowing = !wasFollowing;
    final newCount = newFollowing
        ? currentFollowers + 1
        : (currentFollowers > 0 ? currentFollowers - 1 : 0);

    final updated = targetProfile.copyWith(
      stats: targetProfile.stats.copyWith(
        isFollowing: newFollowing,
        followersCount: newCount,
      ),
    );

    _profiles[followingId] = updated;
    if (_profile != null && _profile!.user.id == followingId.toString()) {
      _profile = updated;
    }
    notifyListeners();

    try {
      await _apiClient.post(
        ApiConstants.toggleFollow,
        body: {
          'follower_id': followerId,
          'following_id': followingId,
        },
      );
      return true;
    } catch (e) {
      // Rollback
      final rollback = targetProfile.copyWith(
        stats: targetProfile.stats.copyWith(
          isFollowing: wasFollowing,
          followersCount: currentFollowers,
        ),
      );
      _profiles[followingId] = rollback;
      if (_profile != null && _profile!.user.id == followingId.toString()) {
        _profile = rollback;
      }
      notifyListeners();
      return false;
    }
  }

  void removePost(int postId) {
    bool changed = false;
    _profiles.forEach((key, prof) {
      final index = prof.posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final updatedPosts = List<PostModel>.from(prof.posts)..removeAt(index);
        final newStats = prof.stats.copyWith(
          postsCount: prof.stats.postsCount > 0 ? prof.stats.postsCount - 1 : 0,
        );
        _profiles[key] = prof.copyWith(posts: updatedPosts, stats: newStats);
        if (_profile != null && _profile!.user.id == prof.user.id) {
          _profile = _profiles[key];
        }
        changed = true;
      }
    });
    if (changed) {
      notifyListeners();
    }
  }

  void clearCache() {
    _profiles.clear();
    _profile = null;
    notifyListeners();
  }

  /// Mengambil daftar Pengikut atau Mengikuti dari server
  Future<List<FollowUserModel>> fetchFollowsList({
    required int userId,
    required String type, // 'followers' atau 'following'
    int? currentUserId,
    String? query,
  }) async {
    try {
      var url = '${ApiConstants.getFollows}?user_id=$userId&type=$type';
      if (currentUserId != null && currentUserId > 0) {
        url += '&current_user_id=$currentUserId';
      }
      if (query != null && query.trim().isNotEmpty) {
        url += '&q=${Uri.encodeComponent(query.trim())}';
      }

      final response = await _apiClient.get(url);
      final rawList = response['data'] as List<dynamic>? ?? [];
      return rawList
          .map((item) => FollowUserModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ProfileViewModel] Gagal mengambil daftar follows: $e');
      return [];
    }
  }

  /// Toggle Follow pengguna dari daftar
  Future<bool> toggleFollowUser({
    required int followerId,
    required int followingId,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.toggleFollow,
        body: {
          'follower_id': followerId,
          'following_id': followingId,
        },
      );
      return response['status'] == 'followed' || response['is_following'] == true;
    } catch (_) {
      return false;
    }
  }
}
