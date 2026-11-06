import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/model/story_model.dart';

class StoryViewModel extends ChangeNotifier {
  final ApiClient _apiClient;

  StoryViewModel(this._apiClient);

  List<UserStory> _userStories = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;

  List<UserStory> get userStories => _userStories;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get errorMessage => _errorMessage;

  UserStory? getMyStory(int userId) {
    try {
      return _userStories.firstWhere(
        (s) => (s.isCurrentUser || s.userId == userId) && s.stories.isNotEmpty,
      );
    } catch (_) {
      return null;
    }
  }

  bool hasActiveStory(int userId) {
    if (userId <= 0) return false;
    return _userStories.any(
      (s) => s.userId == userId && s.stories.isNotEmpty,
    );
  }

  UserStory? getUserStory(int userId) {
    if (userId <= 0) return null;
    try {
      return _userStories.firstWhere(
        (s) => s.userId == userId && s.stories.isNotEmpty,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchStories({int? currentUserId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = currentUserId != null && currentUserId > 0
          ? '${ApiConstants.getStories}?user_id=$currentUserId'
          : ApiConstants.getStories;

      final response = await _apiClient.get(url);
      final rawList = response['data'] as List<dynamic>? ?? [];
      _userStories = rawList
          .map((item) => UserStory.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadStory({
    required int userId,
    required Uint8List bytes,
    required String filename,
    String? caption,
  }) async {
    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fields = <String, String>{
        'user_id': userId.toString(),
      };
      if (caption != null && caption.trim().isNotEmpty) {
        fields['caption'] = caption.trim();
      }

      final response = await _apiClient.uploadBytes(
        ApiConstants.createStory,
        bytes: bytes,
        filename: filename,
        fieldName: 'image',
        fields: fields,
      );

      if (response['status'] == true || response['data'] != null) {
        await fetchStories(currentUserId: userId);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteStory({
    required int storyId,
    required int userId,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.deleteStory,
        body: {'story_id': storyId, 'user_id': userId},
      );

      if (response['status'] == true) {
        await fetchStories(currentUserId: userId);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }
}

