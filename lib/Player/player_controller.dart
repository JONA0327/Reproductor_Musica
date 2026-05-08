import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Singleton that owns the AudioPlayer and exposes playback state.
class PlayerController extends ChangeNotifier {
  static final PlayerController instance = PlayerController._();

  PlayerController._() {
    _player.playingStream.listen((_) => notifyListeners());
    _player.positionStream.listen((_) => notifyListeners());
    _player.durationStream.listen((_) => notifyListeners());
    _player.currentIndexStream.listen((_) => notifyListeners());
  }

  final AudioPlayer _player = AudioPlayer();

  List<SongModel> _queue = [];
  String? currentFolderPath;
  bool _isShuffle = false;

  // ── Read-only state ────────────────────────────────────────────────────────

  bool get isPlaying => _player.playing;
  bool get isShuffle => _isShuffle;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  List<SongModel> get queue => _queue;
  int get currentIndex => _player.currentIndex ?? 0;

  SongModel? get currentSong {
    if (_queue.isEmpty) return null;
    final i = currentIndex;
    if (i < 0 || i >= _queue.length) return null;
    return _queue[i];
  }

  bool isCurrentSong(SongModel s) => currentSong?.id == s.id;

  // ── Playback commands ──────────────────────────────────────────────────────

  Future<void> playFolder(
      List<SongModel> songs, int startIndex, String folderPath) async {
    _queue = List.from(songs);
    currentFolderPath = folderPath;
    try {
      final sources =
          songs.map((s) => AudioSource.uri(Uri.file(s.data))).toList();
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

  Future<void> togglePlayPause() async {
    _player.playing ? await _player.pause() : await _player.play();
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
