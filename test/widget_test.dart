import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/main.dart';
import 'package:ziesocial/viewmodel/chat_viewmodel.dart';
import 'package:ziesocial/viewmodel/create_post_viewmodel.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';
import 'package:ziesocial/viewmodel/register_viewmodel.dart';
import 'package:ziesocial/viewmodel/search_viewmodel.dart';
import 'package:ziesocial/viewmodel/story_viewmodel.dart';

void main() {
  testWidgets('App renders login view smoke test', (WidgetTester tester) async {
    final apiClient = ApiClient();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LoginViewModel(apiClient)),
          ChangeNotifierProvider(create: (_) => RegisterViewModel(apiClient)),
          ChangeNotifierProvider(create: (_) => CreatePostViewModel(apiClient)),
          ChangeNotifierProvider(create: (_) => PostViewModel(apiClient)),
          ChangeNotifierProvider(create: (_) => ProfileViewModel(apiClient)),
          ChangeNotifierProvider(create: (_) => SearchViewModel(apiClient)),
          ChangeNotifierProvider(create: (_) => StoryViewModel(apiClient)),
          ChangeNotifierProvider(create: (_) => ChatViewModel(apiClient)),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
