class ApiConstants {
  static String get baseUrl {
    return 'https://trickle-curling-conceal.ngrok-free.dev/ziesocial/api';
  }

  static String get serverUrl => baseUrl.replaceAll('/api', '');

  static String get login => '$baseUrl/auth/login.php';
  static String get register => '$baseUrl/auth/register.php';
  static String get createPost => '$baseUrl/posts/create.php';
  static String get getPosts => '$baseUrl/posts/read.php';
  static String get deletePost => '$baseUrl/posts/delete.php';
  static String get toggleLike => '$baseUrl/likes/toggle.php';
  static String get getComments => '$baseUrl/comments/read.php';
  static String get addComment => '$baseUrl/comments/create.php';
  static String get deleteComment => '$baseUrl/comments/delete.php';
  static String get editComment => '$baseUrl/comments/update.php';
  static String get updateAvatar => '$baseUrl/users/update_avatar.php';
  static String get updateProfile => '$baseUrl/users/update_profile.php';
  static String get toggleFollow => '$baseUrl/follows/toggle.php';
  static String get profile => '$baseUrl/users/profile.php';
  static String get searchUsers => '$baseUrl/users/search.php';
}
