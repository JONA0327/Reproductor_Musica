import 'dart:convert';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:music_reproductor/Explore/playlist_manager.dart';

// ─── Command types ────────────────────────────────────────────────────────────

sealed class MusicCommand {}

class PlaySongCommand extends MusicCommand {
  final SongModel song;
  final List<SongModel> queue;
  final int index;
  PlaySongCommand(this.song, this.queue, this.index);
}

class PlayPlaylistCommand extends MusicCommand {
  final CustomPlaylist playlist;
  PlayPlaylistCommand(this.playlist);
}

class TogglePlayCommand extends MusicCommand {}

class NextCommand extends MusicCommand {}

class PreviousCommand extends MusicCommand {}

class ChatResponseCommand extends MusicCommand {
  final String message;
  ChatResponseCommand(this.message);
}

// ─── Parser ───────────────────────────────────────────────────────────────────

class MusicCommandParser {
  static final _pauseRe =
      RegExp(r'\b(pausa|parar|para|pause|stop|silencio)\b');
  static final _nextRe =
      RegExp(r'\b(siguiente|next|adelante|avanza|salta)\b');
  static final _prevRe =
      RegExp(r'\b(anterior|prev|atras|back|regresa|vuelve)\b');

  // Words to strip before doing fuzzy target extraction
  static final _commandWords = RegExp(
    r'\b(reproduce|pon|activa|abre|inicia|cambia a|cambia|toca|'
    r'escucha|dale|play|la|el|los|las|un|una|de|del|'
    r'playlist|lista|cancion|musica|song|quiero|por favor)\b',
  );

  /// Resolves commands fully offline — no AI call, no tokens.
  /// Pass [allSongs] and [playlists] for song/playlist matching.
  static MusicCommand? tryOffline(
    String text, {
    List<SongModel>? allSongs,
    List<CustomPlaylist>? playlists,
  }) {
    final t = _norm(text);

    // ── Simple transport commands ────────────────────────────────────────────
    if (_pauseRe.hasMatch(t)) return TogglePlayCommand();
    if (_nextRe.hasMatch(t)) return NextCommand();
    if (_prevRe.hasMatch(t)) return PreviousCommand();

    // ── Extract meaningful target after stripping command/filler words ───────
    final target = t
        .replaceAll(_commandWords, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (target.isEmpty) return null;

    // ── Playlist match (higher priority when text mentions playlist/lista) ───
    final wantsPlaylist =
        t.contains('playlist') || t.contains('lista');
    final availablePlaylists =
        playlists ?? PlaylistManager.instance.playlists;

    if (wantsPlaylist || availablePlaylists.isNotEmpty) {
      final pl = _fuzzyFindPlaylist(target, availablePlaylists);
      if (pl != null) return PlayPlaylistCommand(pl);
    }

    // ── Song match ────────────────────────────────────────────────────────────
    if (allSongs != null && allSongs.isNotEmpty) {
      // Only attempt song match when there's an explicit play verb in the text
      final hasPlayVerb = RegExp(
        r'\b(reproduce|pon|cambia|toca|escucha|dale|play)\b',
      ).hasMatch(t);
      if (hasPlayVerb) {
        final song = _fuzzyFindSong(target, allSongs);
        if (song != null) {
          return PlaySongCommand(song, allSongs, allSongs.indexOf(song));
        }
      }
    }

    return null;
  }

  /// Parses the JSON envelope returned by the AI.
  static MusicCommand parse(String aiResponse, List<SongModel> allSongs) {
    // AI sometimes wraps JSON in a markdown fence — strip it first.
    final cleaned = aiResponse
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final jsonMatch = RegExp(r'\{[\s\S]*?\}').firstMatch(cleaned);
    if (jsonMatch == null) return ChatResponseCommand(aiResponse.trim());

    try {
      final map = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      final action = (map['action'] as String? ?? '').trim();
      final target = (map['target'] as String? ?? '').trim();

      switch (action) {
        case 'play_song':
          final song = _fuzzyFindSong(target, allSongs);
          if (song == null) {
            return ChatResponseCommand('No encontré la canción "$target".');
          }
          return PlaySongCommand(song, allSongs, allSongs.indexOf(song));

        case 'play_playlist':
          final playlist = _fuzzyFindPlaylist(target);
          if (playlist == null) {
            return ChatResponseCommand('No encontré la playlist "$target".');
          }
          return PlayPlaylistCommand(playlist);

        case 'toggle_play':
          return TogglePlayCommand();

        case 'next':
          return NextCommand();

        case 'previous':
          return PreviousCommand();

        case 'chat':
          return ChatResponseCommand(
              map['message'] as String? ?? aiResponse.trim());

        default:
          return ChatResponseCommand(aiResponse.trim());
      }
    } catch (_) {
      return ChatResponseCommand(aiResponse.trim());
    }
  }

  // ── Fuzzy finders ─────────────────────────────────────────────────────────

  static SongModel? _fuzzyFindSong(String query, List<SongModel> songs) {
    if (query.isEmpty) return null;
    final q = _norm(query);

    // 1. Exact normalized title match
    for (final s in songs) {
      if (_norm(s.title) == q) return s;
    }

    // 2. All meaningful words present in title
    final words = q.split(' ').where((w) => w.length > 2).toList();
    if (words.isNotEmpty) {
      for (final s in songs) {
        final title = _norm(s.title);
        if (words.every((w) => title.contains(w))) return s;
      }
    }

    // 3. Best partial score (most words matched)
    SongModel? best;
    int bestScore = 0;
    for (final s in songs) {
      final title = _norm(s.title);
      final score = words.where((w) => title.contains(w)).length;
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return bestScore > 0 ? best : null;
  }

  static CustomPlaylist? _fuzzyFindPlaylist(String query,
      [List<CustomPlaylist>? playlists]) {
    if (query.isEmpty) return null;
    final q = _norm(query);
    final list = playlists ?? PlaylistManager.instance.playlists;

    // 1. Exact normalized match
    for (final p in list) {
      if (_norm(p.name) == q) return p;
    }
    // 2. Substring match (both directions)
    for (final p in list) {
      final pn = _norm(p.name);
      if (pn.contains(q) || q.contains(pn)) return p;
    }
    // 3. Best word overlap
    final words = q.split(' ').where((w) => w.length > 2).toList();
    CustomPlaylist? best;
    int bestScore = 0;
    for (final p in list) {
      final pn = _norm(p.name);
      final score = words.where((w) => pn.contains(w)).length;
      if (score > bestScore) { bestScore = score; best = p; }
    }
    return bestScore > 0 ? best : null;
  }

  // ── Normalization ─────────────────────────────────────────────────────────

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll(RegExp(r'ñ'), 'n')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
