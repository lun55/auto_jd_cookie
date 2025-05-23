import 'package:flutter/material.dart';
import 'package:auto_jd_cookie/pages/webview_page.dart';
import 'package:auto_jd_cookie/pages/first_setup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('first_launch') ?? true;
  runApp(MyApp(isFirstLaunch: isFirstLaunch));
}

class MyApp extends StatelessWidget {
  final bool isFirstLaunch;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  const MyApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '京东Cookie助手',
      theme: ThemeData(primarySwatch: Colors.red),
      home: isFirstLaunch 
          ? FirstSetupPage(
              onSetupComplete: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('first_launch', false);
                navigatorKey.currentState?.pushReplacement(
                  MaterialPageRoute(builder: (_) => const WebViewPage()),
                );
              },
            )
          : const WebViewPage(),
    );
  }
}