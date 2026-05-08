import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:music_reproductor/Library/library.dart';
import 'package:music_reproductor/Settings/settings.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _pageIndex = 0;

  // Vistas de la aplicación
  final List<Widget> _views = [
    const Center(child: Text("Explorar Música", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300))),
    const LibraryView(),
    const Center(child: Text("Compartir Mix", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300))),
    const Center(child: Text("IA Music Engine", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)))),
    const SettingsView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody evita que la UI dé saltos cuando la navbar se anima
      extendBody: true,

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF121212), Color(0xFF000000)],
          ),
        ),
        // IndexedStack evita el lag al cambiar entre pestañas
        child: IndexedStack(
          index: _pageIndex,
          children: _views,
        ),
      ),

      bottomNavigationBar: CurvedNavigationBar(
        index: _pageIndex,
        height: 60.0,
        items: <Widget>[
          Icon(Icons.grid_view_rounded,
              size: 28,
              color: _pageIndex == 0 ? Colors.black : Colors.white60),
          Icon(Icons.library_music_rounded,
              size: 28,
              color: _pageIndex == 1 ? Colors.black : Colors.white60),
          Icon(Icons.ios_share_rounded,
              size: 28,
              color: _pageIndex == 2 ? Colors.black : Colors.white60),
          Icon(Icons.auto_awesome_rounded,
              size: 28,
              color: _pageIndex == 3 ? Colors.black : Colors.white60),
          Icon(Icons.settings_rounded,
              size: 28,
              color: _pageIndex == 4 ? Colors.black : Colors.white60),
        ],
        color: const Color(0xFF1A1A1A), // Color de la barra
        buttonBackgroundColor: const Color(0xFF00E5FF), // Color del círculo flotante
        backgroundColor: Colors.transparent, // Fondo detrás de la curva

        // --- CONFIGURACIÓN DE ANIMACIÓN FLUIDA ---
        animationCurve: Curves.easeInOutQuart, // Movimiento suave de entrada y salida, SIN rebote
        animationDuration: const Duration(milliseconds: 450), // Velocidad equilibrada

        onTap: (index) {
          setState(() {
            _pageIndex = index;
          });
        },
      ),
    );
  }
}