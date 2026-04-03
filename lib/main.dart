import 'package:flutter/material.dart';

import 'home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyTreeApp());
}

class MyTreeApp extends StatelessWidget {
  const MyTreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyTree',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF3F6F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C8D7C),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E5449),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Color(0xFF66756D),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Color(0xFF66756D),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}
