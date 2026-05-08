import 'package:flutter/material.dart';
import 'package:music_reproductor/Home/home.dart';

void main() {
  runApp(const ReproductorApp());
}

class ReproductorApp extends StatelessWidget {
  const ReproductorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Music AI",
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F0F0F),
          primary: const Color(0xFF00E5FF),
        ),
        scaffoldBackgroundColor: const Color(0xFF080808),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ),
      home: const Home(),
    );
  }
}