import 'package:flutter/material.dart';
import 'audio/sounds.dart';
import 'api/api_client.dart';
import 'screens/home_screen.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141518),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF69884A),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E2024),
          primary: const Color(0xFF69884A),
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}
