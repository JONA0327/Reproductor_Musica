import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:music_reproductor/Explore/playlist_manager.dart';

// ─── Universal song display info ──────────────────────────────────────────────

class CurrentSongInfo {
  final int id;
  final String title;
  final String? artist;
  final int? duration;
  const CurrentSongInfo({
    required this.id,
    required this.title,
    this.artist,
    this.duration,
  });
}

/// Singleton that owns the AudioPlayer and exposes playback state.
class PlayerController extends ChangeNotifier {
  static final PlayerController instance = PlayerController._();

  PlayerController._() {
    _player.playingStream.listen((_) => notifyListeners());
    _player.positionStream.listen((_) => notifyListeners());
    _player.durationStream.listen((_) => notifyListeners());
    _player.currentIndexStream.listen((idx) {
      if (idx != null && idx != _lastTrackedIndex) {
        if (_infoQueue.isNotEmpty && idx < _infoQueue.length) {
          _lastTrackedIndex = idx;
          PlaylistManager.instance.incrementPlayCount(_infoQueue[idx].id);
        }
      }
      notifyListeners();
    });
  }

  final AudioPlayer _player = AudioPlayer();

  List<SongModel> _queue = [];
  List<CurrentSongInfo> _infoQueue = [];
  int _lastTrackedIndex = -1;
  String? currentFolderPath;
  bool _isShuffle = false;

  // ── Read-only state ────────────────────────────────────────────────────────

  bool get isPlaying => _player.playing;
  bool get isShuffle => _isShuffle;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  List<SongModel> get queue => _queue;
  int get currentIndex => _player.currentIndex ?? 0;

  /// Universal current song info — works for both folder and playlist modes.
  CurrentSongInfo? get currentInfo {
    final i = currentIndex;
    if (_infoQueue.isEmpty || i < 0 || i >= _infoQueue.length) return null;
    return _infoQueue[i];
  }

  /// Returns the SongModel only when playing from a folder (for backward compat).
  SongModel? get currentSong {
    if (_queue.isEmpty) return null;
    final i = currentIndex;
    if (i < 0 || i >= _queue.length) return null;
    return _queue[i];
  }

  bool isCurrentSong(SongModel s) => currentInfo?.id == s.id;

  // ── Playback commands ──────────────────────────────────────────────────────

  Future<void> playFolder(
      List<SongModel> songs, int startIndex, String folderPath) async {
    _queue = List.from(songs);
    _infoQueue = songs
        .map((s) => CurrentSongInfo(
            id: s.id, title: s.title, artist: s.artist, duration: s.duration))
        .toList();
    _lastTrackedIndex = -1;
    currentFolderPath = folderPath;
    try {
      final sources = songs
          .map((s) => AudioSource.uri(
                Uri.file(s.data),
                tag: MediaItem(
                  id: s.data,
                  title: s.title,
                  artist: s.artist ?? 'Desconocido',
                ),
              ))
          .toList();
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: startIndex,
        initialPosition: Duration.zero,
      );
      await _player.setShuffleModeEnabled(_isShuffle);
      await _player.play();
    } catch (e) {
      debugPrint('PlayerController.playFolder error: $e');
    }
    notifyListeners();
  }

  /// Plays a chain of custom playlists sequentially.
  /// When one playlist ends, the next one starts automatically.
  Future<void> playPlaylistChain(
    List<CustomPlaylist> playlists, {
    int startPlaylist = 0,
    int startSong = 0,
  }) async {
    final allSongs = playlists.expand((p) => p.songs).toList();
    if (allSongs.isEmpty) return;

    _queue = [];
    _infoQueue = allSongs
        .map((s) => CurrentSongInfo(
            id: s.id, title: s.title, artist: s.artist, duration: s.duration))
        .toList();
    _lastTrackedIndex = -1;
    currentFolderPath = null;

    // Calculate the global start index across all playlists
    int globalIdx = 0;
    for (int i = 0; i < startPlaylist && i < playlists.length; i++) {
      globalIdx += playlists[i].songs.length;
    }
    globalIdx += startSong;
    if (globalIdx >= allSongs.length) globalIdx = 0;

    try {
      final sources = allSongs
          .map((s) => AudioSource.uri(
                Uri.file(s.data),
                tag: MediaItem(
                  id: s.data,
                  title: s.title,
                  artist: s.artist ?? 'Desconocido',
                ),
              ))
          .toList();
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: globalIdx,
        initialPosition: Duration.zero,
      );
      await _player.setShuffleModeEnabled(_isShuffle);
      await _player.play();
    } catch (e) {
      debugPrint('PlayerController.playPlaylistChain error: $e');
    }
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    _player.playing ? await _player.pause() : await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
    _queue = [];
    _infoQueue = [];
    _lastTrackedIndex = -1;
    currentFolderPath = null;
    notifyListeners();
  }

  Future<void> seek(Duration pos) => _player.seek(pos);

  Future<void> next() => _player.seekToNext();

  Future<void> previous() async {
    if (position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _player.setShuffleModeEnabled(_isShuffle);
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
