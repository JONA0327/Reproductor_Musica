import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Song info stored in playlists ───────────────────────────────────────────

class PlaylistSongInfo {
  final int id;
  final String data;
  final String title;
  final String? artist;
  final int? duration;

  const PlaylistSongInfo({
    required this.id,
    required this.data,
    required this.title,
    this.artist,
    this.duration,
  });

  factory PlaylistSongInfo.fromSong(SongModel s) => PlaylistSongInfo(
        id: s.id,
        data: s.data,
        title: s.title,
        artist: s.artist,
        duration: s.duration,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'data': data,
        'title': title,
        if (artist != null) 'artist': artist,
        if (duration != null) 'duration': duration,
      };

  factory PlaylistSongInfo.fromJson(Map<String, dynamic> j) => PlaylistSongInfo(
        id: j['id'] as int,
        data: j['data'] as String,
        title: j['title'] as String,
        artist: j['artist'] as String?,
        duration: j['duration'] as int?,
      );
}

// ─── Custom playlist ──────────────────────────────────────────────────────────

class CustomPlaylist {
  final String id;
  String name;
  List<PlaylistSongInfo> songs;

  CustomPlaylist({
    required this.id,
    required this.name,
    List<PlaylistSongInfo>? songs,
  }) : songs = songs ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songs': songs.map((s) => s.toJson()).toList(),
      };

  factory CustomPlaylist.fromJson(Map<String, dynamic> j) => CustomPlaylist(
        id: j['id'] as String,
        name: j['name'] as String,
        songs: (j['songs'] as List<dynamic>?)
                ?.map((s) => PlaylistSongInfo.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ─── Playlist manager singleton ───────────────────────────────────────────────

class PlaylistManager extends ChangeNotifier {
  static final PlaylistManager instance = PlaylistManager._();
  PlaylistManager._();

  static const _playlistsKey = 'custom_playlists_v1';
  static const _playCountsKey = 'play_counts_v1';

  List<CustomPlaylist> _playlists = [];
  Map<int, int> _playCounts = {};

  List<CustomPlaylist> get playlists => List.unmodifiable(_playlists);
  Map<int, int> get playCounts => Map.unmodifiable(_playCounts);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final rawPlaylists = prefs.getString(_playlistsKey);
    if (rawPlaylists != null) {
      try {
        final list = jsonDecode(rawPlaylists) as List<dynamic>;
        _playlists = list
            .map((e) => CustomPlaylist.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _playlists = [];
      }
    }

    final rawCounts = prefs.getString(_playCountsKey);
    if (rawCounts != null) {
      try {
        final map = jsonDecode(rawCounts) as Map<String, dynamic>;
        _playCounts = map.map((k, v) => MapEntry(int.parse(k), v as int));
      } catch (_) {
        _playCounts = {};
      }
    }

    notifyListeners();
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _playlistsKey, jsonEncode(_playlists.map((p) => p.toJson()).toList()));
    notifyListeners();
  }

  Future<void> _savePlayCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _playCountsKey,
        jsonEncode(_playCounts.map((k, v) => MapEntry(k.toString(), v))));
  }

  // ── Playlist CRUD ─────────────────────────────────────────────────────────

  Future<CustomPlaylist> createPlaylist(String name) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final playlist = CustomPlaylist(id: id, name: name);
    _playlists.add(playlist);
    await _savePlaylists();
    return playlist;
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
  }

  Future<void> renamePlaylist(String id, String newName) async {
    final idx = _playlists.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _playlists[idx].name = newName;
      await _savePlaylists();
    }
  }

  Future<void> addSong(String playlistId, SongModel song) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    final playlist = _playlists[idx];
    if (playlist.songs.any((s) => s.id == song.id)) return;
    playlist.songs.add(PlaylistSongInfo.fromSong(song));
    await _savePlaylists();
  }

  Future<void> removeSong(String playlistId, int songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    _playlists[idx].songs.removeWhere((s) => s.id == songId);
    await _savePlaylists();
  }

  bool hasSong(String playlistId, int songId) {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return false;
    return _playlists[idx].songs.any((s) => s.id == songId);
  }

  // ── Play counts ───────────────────────────────────────────────────────────

  void incrementPlayCount(int songId) {
    _playCounts[songId] = (_playCounts[songId] ?? 0) + 1;
    _savePlayCounts();
    notifyListeners();
  }

  List<MapEntry<int, int>> getTopSongIds({int limit = 20}) {
    final sorted = _playCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }
}
