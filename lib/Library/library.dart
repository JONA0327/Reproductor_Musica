import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── Folder model ─────────────────────────────────────────────────────────────

class MusicFolder {
  final String path;
  final String name;
  final List<SongModel> songs;
  const MusicFolder({required this.path, required this.name, required this.songs});
}

// ─── Library widget ───────────────────────────────────────────────────────────

class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  bool _hasPermission = false;
  bool _isLoading = true;
  String? _errorMessage;
  List<MusicFolder> _folders = [];

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final hasPermission = await _audioQuery.permissionsStatus();
    if (hasPermission) {
      setState(() => _hasPermission = true);
      await _loadSongs();
      return;
    }
    final granted = await _audioQuery.permissionsRequest();
    if (granted) {
      setState(() => _hasPermission = true);
      await _loadSongs();
    } else {
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted) {
        setState(() => _hasPermission = true);
        await _loadSongs();
      } else {
        setState(() { _hasPermission = false; _isLoading = false; });
      }
    }
  }

  Future<void> _loadSongs() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      ).timeout(const Duration(seconds: 15));

      final valid = songs.where((s) => (s.duration ?? 0) > 30000).toList();

      final Map<String, List<SongModel>> map = {};
      for (final song in valid) {
        final fp = song.data;
        final folder = fp.isNotEmpty ? fp.substring(0, fp.lastIndexOf('/')) : 'Desconocida';
        map.putIfAbsent(folder, () => []).add(song);
      }

      final folders = map.entries.map((e) {
        final name = e.key.split('/').last;
        return MusicFolder(path: e.key, name: name.isEmpty ? e.key : name, songs: e.value);
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      setState(() { _folders = folders; _isLoading = false; });
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  String _fmt(int? ms) {
    if (ms == null) return '--:--';
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int get _totalSongs => _folders.fold(0, (sum, f) => sum + f.songs.length);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 4),
            child: Row(
              children: [
                const Text('Tu Biblioteca',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF)),
                  tooltip: 'Actualizar',
                  onPressed: _hasPermission ? _loadSongs : _requestPermission,
                ),
              ],
            ),
          ),
          if (_hasPermission && !_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('${_folders.length} carpetas · $_totalSongs canciones',
                  style: const TextStyle(color: Colors.white38, fontSize: 13)),
            ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    }
    if (_errorMessage != null) {
      return _msg(
        icon: Icons.error_outline_rounded, iconColor: Colors.redAccent,
        title: 'Error al cargar música', subtitle: _errorMessage,
        action: ElevatedButton.icon(
          onPressed: _loadSongs,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      );
    }
    if (!_hasPermission) {
      return _msg(
        icon: Icons.library_music_rounded,
        title: 'Acceso a música denegado',
        subtitle: 'Permite el acceso a tus archivos de audio para ver tu biblioteca.',
        action: ElevatedButton.icon(
          onPressed: () async { await openAppSettings(); _requestPermission(); },
          icon: const Icon(Icons.settings_rounded),
          label: const Text('Abrir Ajustes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      );
    }
    if (_folders.isEmpty) {
      return _msg(icon: Icons.music_off_rounded, title: 'No se encontraron canciones',
          subtitle: 'Asegúrate de tener archivos de audio en el almacenamiento.');
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1),
      itemCount: _folders.length,
      itemBuilder: (_, i) => _FolderCard(
        folder: _folders[i],
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => _FolderSongsPage(
            folder: _folders[i], formatDuration: _fmt, audioQuery: _audioQuery))),
      ),
    );
  }

  Widget _msg({required IconData icon, Color? iconColor, required String title,
      String? subtitle, Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: iconColor ?? Colors.white24),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                  textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 24), action],
          ],
        ),
      ),
    );
  }
}

// ─── Folder card ──────────────────────────────────────────────────────────────

class _FolderCard extends StatelessWidget {
  final MusicFolder folder;
  final VoidCallback onTap;
  const _FolderCard({required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.folder_rounded, color: Color(0xFF00E5FF), size: 28),
            ),
            const Spacer(),
            Text(folder.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${folder.songs.length} ${folder.songs.length == 1 ? 'canción' : 'canciones'}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─── Folder songs page ────────────────────────────────────────────────────────

class _FolderSongsPage extends StatefulWidget {
  final MusicFolder folder;
  final String Function(int?) formatDuration;
  final OnAudioQuery audioQuery;
  const _FolderSongsPage(
      {required this.folder, required this.formatDuration, required this.audioQuery});

  @override
  State<_FolderSongsPage> createState() => _FolderSongsPageState();
}

class _FolderSongsPageState extends State<_FolderSongsPage> {
  String _q = '';
  int? _sel;

  List<SongModel> get _songs {
    if (_q.isEmpty) return widget.folder.songs;
    final q = _q.toLowerCase();
    return widget.folder.songs
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            (s.artist?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs;
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.folder.name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(widget.folder.path,
                            style: const TextStyle(color: Colors.white30, fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${songs.length} ${songs.length == 1 ? 'canción' : 'canciones'}',
                    style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar en esta carpeta...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            // List
            Expanded(
              child: songs.isEmpty
                  ? const Center(
                      child: Text('Sin resultados',
                          style: TextStyle(color: Colors.white38, fontSize: 14)))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: songs.length,
                      itemBuilder: (_, i) {
                        final song = songs[i];
                        final isSel = _sel == i;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0xFF00E5FF).withOpacity(0.08)
                                : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                  color: isSel
                                      ? const Color(0xFF00E5FF)
                                      : Colors.transparent,
                                  width: 3),
                            ),
                          ),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: QueryArtworkWidget(
                                id: song.id,
                                type: ArtworkType.AUDIO,
                                nullArtworkWidget: Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.music_note_rounded,
                                      color: isSel ? const Color(0xFF00E5FF) : Colors.white38),
                                ),
                              ),
                            ),
                            title: Text(song.title,
                                style: TextStyle(
                                  color: isSel ? const Color(0xFF00E5FF) : Colors.white,
                                  fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                                  fontSize: 14,
                                ),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(song.artist ?? 'Artista desconocido',
                                style: const TextStyle(color: Colors.white38, fontSize: 12),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(widget.formatDuration(song.duration),
                                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                const SizedBox(width: 8),
                                Icon(
                                  isSel
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_outline_rounded,
                                  color: isSel ? const Color(0xFF00E5FF) : Colors.white38,
                                  size: 22,
                                ),
                              ],
                            ),
                            onTap: () => setState(() => _sel = isSel ? null : i),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

