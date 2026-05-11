import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:music_reproductor/Home/home.dart';
import 'package:music_reproductor/Explore/playlist_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.music_reproductor.channel',
    androidNotificationChannelName: 'Reproducción de música',
    androidNotificationIcon: 'mipmap/ic_launcher',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: false,
  );
  await PlaylistManager.instance.load();
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