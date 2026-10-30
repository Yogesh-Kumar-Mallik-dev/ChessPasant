import 'package:flutter/material.dart';
import 'audio/sounds.dart';
import 'api/api_client.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SoundEffects().init();
  await ApiClient().init();
  runApp(const ChessPasantApp());
}

class ChessPasantApp extends StatelessWidget {
  const ChessPasantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChessPasant',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
