import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:music_reproductor/Explore/playlist_manager.dart';
import 'package:music_reproductor/Player/player_controller.dart';

// ─── Explore view ─────────────────────────────────────────────────────────────

class ExploreView extends StatefulWidget {
  const ExploreView({super.key});

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> _allSongs = [];
  bool _loadingSongs = true;

  // Multi-select ordered list for queuing playlists
  final List<String> _selectedOrder = [];

  @override
  void initState() {
    super.initState();
    _loadAllSongs();
    PlaylistManager.instance.addListener(_onManagerChanged);
  }

  @override
  void dispose() {
    PlaylistManager.instance.removeListener(_onManagerChanged);
    super.dispose();
  }

  void _onManagerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAllSongs() async {
    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      if (mounted) {
        setState(() {
          _allSongs = songs.where((s) => (s.duration ?? 0) > 30000).toList();
          _loadingSongs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSongs = false);
    }
  }

  List<SongModel> get _topSongs {
    final topIds = PlaylistManager.instance.getTopSongIds(limit: 20);
    final songMap = {for (final s in _allSongs) s.id: s};
    return topIds.map((e) => songMap[e.key]).whereType<SongModel>().toList();
  }

  String _fmt(int? ms) {
    if (ms == null) return '--:--';
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _isMultiSelect => _selectedOrder.isNotEmpty;

  void _toggleSelection(String playlistId) {
    setState(() {
      if (_selectedOrder.contains(playlistId)) {
        _selectedOrder.remove(playlistId);
      } else {
        _selectedOrder.add(playlistId);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedOrder.clear());

  void _playSelected() {
    final mgr = PlaylistManager.instance;
    final selected = _selectedOrder
        .map((id) {
          try {
            return mgr.playlists.firstWhere((p) => p.id == id);
          } catch (_) {
            return null;
          }
        })
        .whereType<CustomPlaylist>()
        .toList();
    if (selected.isEmpty) return;
    PlayerController.instance.playPlaylistChain(selected);
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final playlists = PlaylistManager.instance.playlists;
    final topSongs = _topSongs;

    return SafeArea(
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Explorar Música',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                if (_isMultiSelect) ...[
                  TextButton(
                    onPressed: _clearSelection,
                    child: const Text('Cancelar',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ),
                ] else
                  IconButton(
                    icon: const Icon(Icons.add_rounded,
                        color: Color(0xFF00E5FF)),
                    tooltip: 'Nueva playlist',
                    onPressed: () => _showCreatePlaylistDialog(context),
                  ),
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // ── Top played songs ──────────────────────────────────────
                if (_loadingSongs)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child:
                        Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
                  )
                else if (topSongs.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up_rounded,
                            color: Color(0xFF00E5FF), size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Más Escuchadas',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            final ctrl = PlayerController.instance;
                            ctrl.playFolder(topSongs, 0, 'top_played');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded,
                                    color: Color(0xFF00E5FF), size: 16),
                                SizedBox(width: 4),
                                Text('Reproducir',
                                    style: TextStyle(
                                        color: Color(0xFF00E5FF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 168,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: topSongs.length,
                      itemBuilder: (_, i) {
                        final song = topSongs[i];
                        final count =
                            PlaylistManager.instance.playCounts[song.id] ?? 0;
                        return _TopSongCard(
                          song: song,
                          playCount: count,
                          rank: i + 1,
                          isPlaying: PlayerController.instance.currentInfo?.id ==
                                  song.id &&
                              PlayerController.instance.isPlaying,
                          onTap: () {
                            final ctrl = PlayerController.instance;
                            if (ctrl.currentInfo?.id == song.id) {
                              ctrl.togglePlayPause();
                            } else {
                              ctrl.playFolder(topSongs, i, 'top_played');
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // ── Playlists section ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.queue_music_rounded,
                          color: Color(0xFF00E5FF), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Mis Playlists',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (playlists.isNotEmpty && !_isMultiSelect)
                        GestureDetector(
                          onTap: () => setState(() {
                            if (!_selectedOrder.contains(playlists.first.id)) {
                              _selectedOrder.add(playlists.first.id);
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.checklist_rounded,
                                    color: Colors.white60, size: 15),
                                SizedBox(width: 4),
                                Text('Encolar',
                                    style: TextStyle(
                                        color: Colors.white60, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.queue_music_rounded,
                            size: 72, color: Colors.white12),
                        const SizedBox(height: 16),
                        const Text('Sin playlists aún',
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 17,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text(
                          'Crea una playlist para organizar tu música favorita o categorizar canciones',
                          style:
                              TextStyle(color: Colors.white24, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showCreatePlaylistDialog(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Nueva Playlist'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: playlists.length,
                    itemBuilder: (_, i) {
                      final pl = playlists[i];
                      final selectionIndex = _selectedOrder.indexOf(pl.id);
                      return _PlaylistCard(
                        playlist: pl,
                        selectionIndex:
                            _isMultiSelect ? selectionIndex : null,
                        onTap: () {
                          if (_isMultiSelect) {
                            _toggleSelection(pl.id);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _PlaylistDetailPage(
                                  playlist: pl,
                                  allSongs: _allSongs,
                                  audioQuery: _audioQuery,
                                  formatDuration: _fmt,
                                ),
                              ),
                            );
                          }
                        },
                        onLongPress: _isMultiSelect
                            ? null
                            : () => _showPlaylistOptions(context, pl),
                      );
                    },
                  ),

                // Multi-select hint
                if (_isMultiSelect)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Text(
                      'Toca las playlists en el orden que quieras reproducirlas',
                      style: const TextStyle(
                          color: Colors.white30, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),

          // ── Multi-select bottom action bar ──────────────────────────────
          if (_isMultiSelect)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF141414),
                border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedOrder.length} playlist${_selectedOrder.length == 1 ? '' : 's'} en cola',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _playSelected,
                    icon: const Icon(Icons.playlist_play_rounded, size: 20),
                    label: const Text('Reproducir en orden'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Nueva Playlist',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nombre de la playlist',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              PlaylistManager.instance.createPlaylist(v.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                PlaylistManager.instance.createPlaylist(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Crear',
                style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showPlaylistOptions(BuildContext context, CustomPlaylist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PlaylistOptionsSheet(
        playlist: playlist,
        onPlay: () {
          Navigator.pop(context);
          PlayerController.instance.playPlaylistChain([playlist]);
        },
        onQueueAdd: () {
          Navigator.pop(context);
          setState(() {
            if (!_selectedOrder.contains(playlist.id)) {
              _selectedOrder.add(playlist.id);
            }
          });
        },
        onRename: () {
          Navigator.pop(context);
          _showRenameDialog(context, playlist);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(context, playlist);
        },
      ),
    );
  }

  void _showRenameDialog(BuildContext context, CustomPlaylist playlist) {
    final ctrl = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Renombrar Playlist',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                PlaylistManager.instance
                    .renamePlaylist(playlist.id, ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar',
                style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, CustomPlaylist playlist) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Eliminar Playlist',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar "${playlist.name}"? Esta acción no se puede deshacer.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              PlaylistManager.instance.deletePlaylist(playlist.id);
              Navigator.pop(context);
            },
            child: const Text('Eliminar',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Top song card ─────────────────────────────────────────────────────────────

class _TopSongCard extends StatelessWidget {
  final SongModel song;
  final int playCount;
  final int rank;
  final bool isPlaying;
  final VoidCallback onTap;

  const _TopSongCard({
    required this.song,
    required this.playCount,
    required this.rank,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 128,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isPlaying
                  ? const Color(0xFF00E5FF).withOpacity(0.5)
                  : Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  child: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    size: 128,
                    nullArtworkWidget: Container(
                      width: 128,
                      height: 88,
                      color: const Color(0xFF1E1E1E),
                      child: const Icon(Icons.music_note_rounded,
                          color: Color(0xFF00E5FF), size: 32),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: rank <= 3
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF1A1A1A).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                          color:
                              rank <= 3 ? Colors.black : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (isPlaying)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                          color: Color(0xFF00E5FF), shape: BoxShape.circle),
                      child: const Icon(Icons.pause_rounded,
                          color: Colors.black, size: 14),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                        color: isPlaying
                            ? const Color(0xFF00E5FF)
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.headphones_rounded,
                          color: Colors.white38, size: 11),
                      const SizedBox(width: 3),
                      Text('$playCount',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Playlist card ─────────────────────────────────────────────────────────────

class _PlaylistCard extends StatelessWidget {
  final CustomPlaylist playlist;
  // null = not in multi-select; -1 = multi-select but not selected; >= 0 = selected order
  final int? selectionIndex;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PlaylistCard({
    required this.playlist,
    required this.selectionIndex,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectionIndex != null && selectionIndex! >= 0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withOpacity(0.12)
              : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF00E5FF)
                  : Colors.white.withOpacity(0.07)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00E5FF).withOpacity(0.25)
                        : const Color(0xFF00E5FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isSelected
                      ? Center(
                          child: Text(
                            '${selectionIndex! + 1}',
                            style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                          ),
                        )
                      : const Icon(Icons.queue_music_rounded,
                          color: Color(0xFF00E5FF), size: 24),
                ),
                const Spacer(),
                if (selectionIndex == null)
                  const Icon(Icons.more_vert_rounded,
                      color: Colors.white24, size: 18),
              ],
            ),
            const Spacer(),
            Text(
              playlist.name,
              style: TextStyle(
                  color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${playlist.songs.length} ${playlist.songs.length == 1 ? 'canción' : 'canciones'}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Playlist options bottom sheet ────────────────────────────────────────────

class _PlaylistOptionsSheet extends StatelessWidget {
  final CustomPlaylist playlist;
  final VoidCallback onPlay;
  final VoidCallback onQueueAdd;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _PlaylistOptionsSheet({
    required this.playlist,
    required this.onPlay,
    required this.onQueueAdd,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(
            playlist.name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${playlist.songs.length} ${playlist.songs.length == 1 ? 'canción' : 'canciones'}',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF2A2A2A)),
          ListTile(
            leading: const Icon(Icons.play_circle_outline_rounded,
                color: Color(0xFF00E5FF)),
            title: const Text('Reproducir',
                style: TextStyle(color: Colors.white)),
            onTap: onPlay,
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded,
                color: Colors.white60),
            title: const Text('Agregar a cola de playlists',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('Encolar junto a otras playlists',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            onTap: onQueueAdd,
          ),
          ListTile(
            leading:
                const Icon(Icons.edit_rounded, color: Colors.white60),
            title: const Text('Renombrar',
                style: TextStyle(color: Colors.white)),
            onTap: onRename,
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent),
            title: const Text('Eliminar',
                style: TextStyle(color: Colors.redAccent)),
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

// ─── Playlist detail page ─────────────────────────────────────────────────────

class _PlaylistDetailPage extends StatefulWidget {
  final CustomPlaylist playlist;
  final List<SongModel> allSongs;
  final OnAudioQuery audioQuery;
  final String Function(int?) formatDuration;

  const _PlaylistDetailPage({
    required this.playlist,
    required this.allSongs,
    required this.audioQuery,
    required this.formatDuration,
  });

  @override
  State<_PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<_PlaylistDetailPage> {
  String _q = '';

  @override
  void initState() {
    super.initState();
    PlaylistManager.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    PlaylistManager.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  CustomPlaylist? get _playlist {
    try {
      return PlaylistManager.instance.playlists
          .firstWhere((p) => p.id == widget.playlist.id);
    } catch (_) {
      return null;
    }
  }

  List<PlaylistSongInfo> get _filteredSongs {
    final pl = _playlist;
    if (pl == null) return [];
    if (_q.isEmpty) return pl.songs;
    final q = _q.toLowerCase();
    return pl.songs
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            (s.artist?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  void _tapSong(PlaylistSongInfo song) {
    final ctrl = PlayerController.instance;
    final pl = _playlist;
    if (pl == null) return;
    if (ctrl.currentInfo?.id == song.id) {
      ctrl.togglePlayPause();
    } else {
      final idx = pl.songs.indexOf(song);
      if (idx >= 0) ctrl.playPlaylistChain([pl], startSong: idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pl = _playlist;
    if (pl == null) {
      return const Scaffold(backgroundColor: Color(0xFF080808));
    }

    final songs = _filteredSongs;

    return ListenableBuilder(
      listenable: PlayerController.instance,
      builder: (_, __) {
        final ctrl = PlayerController.instance;
        return Scaffold(
          backgroundColor: const Color(0xFF080808),
          body: SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 8, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pl.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(
                              '${pl.songs.length} ${pl.songs.length == 1 ? 'canción' : 'canciones'}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Play all
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                              color: Color(0xFF00E5FF),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.black, size: 20),
                        ),
                        onPressed: pl.songs.isEmpty
                            ? null
                            : () => ctrl.playPlaylistChain([pl]),
                        tooltip: 'Reproducir todo',
                      ),
                      // Add songs
                      IconButton(
                        icon: const Icon(Icons.add_rounded,
                            color: Color(0xFF00E5FF)),
                        onPressed: () => _showAddSongsSheet(context, pl),
                        tooltip: 'Agregar canciones',
                      ),
                      // Delete playlist
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent),
                        tooltip: 'Eliminar playlist',
                        onPressed: () => _confirmDelete(context, pl),
                      ),
                    ],
                  ),
                ),

                // ── Search ───────────────────────────────────────────────
                if (pl.songs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      onChanged: (v) => setState(() => _q = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar en esta playlist...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Colors.white30),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),

                // ── Song list ────────────────────────────────────────────
                Expanded(
                  child: pl.songs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_off_rounded,
                                  size: 72, color: Colors.white12),
                              const SizedBox(height: 16),
                              const Text('Playlist vacía',
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              const Text(
                                'Agrega canciones desde tu biblioteca',
                                style: TextStyle(
                                    color: Colors.white24, fontSize: 13),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showAddSongsSheet(context, pl),
                                icon: const Icon(Icons.add_rounded,
                                    size: 18),
                                label:
                                    const Text('Agregar canciones'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF00E5FF),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        )
                      : songs.isEmpty
                          ? const Center(
                              child: Text('Sin resultados',
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 14)))
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.only(bottom: 16),
                              itemCount: songs.length,
                              itemBuilder: (_, i) {
                                final song = songs[i];
                                final isCurrent =
                                    ctrl.currentInfo?.id == song.id;
                                final isActivePlaying =
                                    isCurrent && ctrl.isPlaying;
                                return AnimatedContainer(
                                  duration: const Duration(
                                      milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? const Color(0xFF00E5FF)
                                            .withOpacity(0.08)
                                        : Colors.transparent,
                                    border: Border(
                                      left: BorderSide(
                                          color: isCurrent
                                              ? const Color(0xFF00E5FF)
                                              : Colors.transparent,
                                          width: 3),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 4),
                                    leading: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      child: QueryArtworkWidget(
                                        id: song.id,
                                        type: ArtworkType.AUDIO,
                                        nullArtworkWidget: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color:
                                                const Color(0xFF1E1E1E),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    8),
                                          ),
                                          child: Icon(
                                            Icons.music_note_rounded,
                                            color: isCurrent
                                                ? const Color(
                                                    0xFF00E5FF)
                                                : Colors.white38,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      song.title,
                                      style: TextStyle(
                                        color: isCurrent
                                            ? const Color(0xFF00E5FF)
                                            : Colors.white,
                                        fontWeight: isCurrent
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      song.artist ??
                                          'Artista desconocido',
                                      style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          widget.formatDuration(
                                              song.duration),
                                          style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 12),
                                        ),
                                        const SizedBox(width: 2),
                                        PopupMenuButton<String>(
                                          color:
                                              const Color(0xFF1A1A1A),
                                          icon: const Icon(
                                              Icons.more_vert_rounded,
                                              color: Colors.white38,
                                              size: 18),
                                          onSelected: (v) {
                                            if (v == 'remove') {
                                              PlaylistManager.instance
                                                  .removeSong(
                                                      pl.id, song.id);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'remove',
                                              child: Row(children: [
                                                Icon(
                                                  Icons
                                                      .remove_circle_outline_rounded,
                                                  color:
                                                      Colors.redAccent,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Quitar de playlist',
                                                  style: TextStyle(
                                                      color: Colors
                                                          .redAccent),
                                                ),
                                              ]),
                                            ),
                                          ],
                                        ),
                                        Icon(
                                          isActivePlaying
                                              ? Icons
                                                  .pause_circle_filled_rounded
                                              : Icons
                                                  .play_circle_outline_rounded,
                                          color: isCurrent
                                              ? const Color(0xFF00E5FF)
                                              : Colors.white24,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                    onTap: () => _tapSong(song),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddSongsSheet(BuildContext context, CustomPlaylist pl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F0F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddSongsSheet(
        playlist: pl,
        allSongs: widget.allSongs,
        audioQuery: widget.audioQuery,
      ),
    );
  }

  void _confirmDelete(BuildContext context, CustomPlaylist pl) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Eliminar Playlist',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar "${pl.name}"?\n\nSolo se eliminará la playlist. Tu música no se borrará.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              // Navigate first so the page is gone before the rebuild
              Navigator.pop(dialogCtx); // close dialog
              Navigator.pop(context);   // close detail page
              // Stop player if music was playing, then delete
              PlayerController.instance.stop();
              PlaylistManager.instance.deletePlaylist(pl.id);
            },
            child: const Text('Eliminar',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Add songs sheet ──────────────────────────────────────────────────────────

// ─── Folder group for add-songs sheet ────────────────────────────────────────

class _FolderGroup {
  final String path;
  final String name;
  final List<SongModel> songs;
  const _FolderGroup({required this.path, required this.name, required this.songs});
}

// ─── Add songs sheet ──────────────────────────────────────────────────────────

class _AddSongsSheet extends StatefulWidget {
  final CustomPlaylist playlist;
  final List<SongModel> allSongs; // hint list; reloaded internally if empty
  final OnAudioQuery audioQuery;

  const _AddSongsSheet({
    required this.playlist,
    required this.allSongs,
    required this.audioQuery,
  });

  @override
  State<_AddSongsSheet> createState() => _AddSongsSheetState();
}

// Browse mode: flat search vs folder list vs songs inside a folder
enum _BrowseMode { search, folders, folderSongs }

class _AddSongsSheetState extends State<_AddSongsSheet> {
  String _q = '';
  _BrowseMode _mode = _BrowseMode.folders;
  _FolderGroup? _openFolder;
  final TextEditingController _searchCtrl = TextEditingController();

  List<SongModel> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    // Reuse pre-loaded list when available
    if (widget.allSongs.isNotEmpty) {
      if (mounted) setState(() { _songs = widget.allSongs; _loading = false; });
      return;
    }
    // Otherwise query fresh (handles the case where ExploreView hadn't loaded yet)
    try {
      final songs = await widget.audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      if (mounted) {
        setState(() {
          _songs = songs.where((s) => (s.duration ?? 0) > 30000).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Build folder groups from _songs
  List<_FolderGroup> get _folders {
    final Map<String, List<SongModel>> map = {};
    for (final s in _songs) {
      final fp = s.data;
      final folder = fp.isNotEmpty ? fp.substring(0, fp.lastIndexOf('/')) : '';
      map.putIfAbsent(folder, () => []).add(s);
    }
    return map.entries.map((e) {
      final name = e.key.split('/').last;
      return _FolderGroup(
          path: e.key,
          name: name.isEmpty ? e.key : name,
          songs: e.value);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<SongModel> get _searchResults {
    final q = _q.toLowerCase();
    if (q.isEmpty) return [];
    return _songs
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            (s.artist?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  List<SongModel> get _folderSongsFiltered {
    if (_openFolder == null) return [];
    if (_q.isEmpty) return _openFolder!.songs;
    final q = _q.toLowerCase();
    return _openFolder!.songs
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            (s.artist?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  void _openFolderView(_FolderGroup folder) {
    setState(() {
      _openFolder = folder;
      _mode = _BrowseMode.folderSongs;
      _q = '';
      _searchCtrl.clear();
    });
  }

  void _goBack() {
    setState(() {
      _openFolder = null;
      _mode = _BrowseMode.folders;
      _q = '';
      _searchCtrl.clear();
    });
  }

  void _switchToSearch() {
    setState(() {
      _mode = _BrowseMode.search;
      _openFolder = null;
      _q = '';
      _searchCtrl.clear();
    });
  }

  int _folderAddedCount(_FolderGroup folder) {
    return folder.songs
        .where((s) => PlaylistManager.instance.hasSong(widget.playlist.id, s.id))
        .length;
  }

  void _toggleSong(SongModel song) {
    final inPlaylist = PlaylistManager.instance.hasSong(widget.playlist.id, song.id);
    if (inPlaylist) {
      PlaylistManager.instance.removeSong(widget.playlist.id, song.id);
    } else {
      PlaylistManager.instance.addSong(widget.playlist.id, song);
    }
  }

  void _previewSong(List<SongModel> list, int index) {
    final ctrl = PlayerController.instance;
    final song = list[index];
    if (ctrl.currentInfo?.id == song.id) {
      ctrl.togglePlayPause();
    } else {
      ctrl.playFolder(list, index, 'preview');
    }
  }

  void _addAllFolder(_FolderGroup folder) {
    for (final s in folder.songs) {
      if (!PlaylistManager.instance.hasSong(widget.playlist.id, s.id)) {
        PlaylistManager.instance.addSong(widget.playlist.id, s);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PlaylistManager.instance,
      builder: (_, __) {
        final bool inFolder = _mode == _BrowseMode.folderSongs;
        final bool inSearch = _mode == _BrowseMode.search;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, scrollCtrl) => Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (inFolder || inSearch)
                          GestureDetector(
                            onTap: _goBack,
                            child: const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white60, size: 18),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            inFolder ? _openFolder!.name : 'Agregar Canciones',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (inFolder)
                          TextButton.icon(
                            onPressed: () => _addAllFolder(_openFolder!),
                            icon: const Icon(Icons.playlist_add_rounded,
                                size: 16, color: Color(0xFF00E5FF)),
                            label: const Text('Agregar todo',
                                style: TextStyle(
                                    color: Color(0xFF00E5FF), fontSize: 12)),
                            style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                          ),
                        if (!inSearch && !inFolder)
                          IconButton(
                            icon: const Icon(Icons.search_rounded,
                                color: Colors.white54),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Buscar en todas',
                            onPressed: _switchToSearch,
                          ),
                      ],
                    ),
                    if (inFolder)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_openFolder!.songs.length} canciones · '
                          '${_folderAddedCount(_openFolder!)} agregadas',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (inSearch || inFolder)
                      TextField(
                        controller: _searchCtrl,
                        autofocus: inSearch,
                        onChanged: (v) => setState(() => _q = v),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: inFolder
                              ? 'Buscar en ${_openFolder!.name}...'
                              : 'Buscar canción...',
                          hintStyle: const TextStyle(color: Colors.white30),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: Colors.white30),
                          suffixIcon: _q.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      color: Colors.white38, size: 18),
                                  onPressed: () => setState(() {
                                    _q = '';
                                    _searchCtrl.clear();
                                  }),
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF1A1A1A),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    if (inSearch || inFolder) const SizedBox(height: 4),
                  ],
                ),
              ),

              // ── Content ──────────────────────────────────────────────────
              Expanded(child: _buildContent(scrollCtrl)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollCtrl) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    }
    switch (_mode) {
      case _BrowseMode.folders:
        return _buildFolderList(scrollCtrl);
      case _BrowseMode.search:
        return _buildSongList(_searchResults, scrollCtrl,
            emptyText: _q.isEmpty ? 'Escribe para buscar...' : 'Sin resultados');
      case _BrowseMode.folderSongs:
        return _buildSongList(_folderSongsFiltered, scrollCtrl);
    }
  }

  Widget _buildFolderList(ScrollController scrollCtrl) {
    final folders = _folders;
    if (folders.isEmpty) {
      return const Center(
        child: Text('No hay canciones disponibles',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
      );
    }
    return ListView.builder(
      controller: scrollCtrl,
      itemCount: folders.length,
      itemBuilder: (_, i) {
        final folder = folders[i];
        final added = _folderAddedCount(folder);
        final total = folder.songs.length;
        final allAdded = added == total;
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: allAdded
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                  : const Color(0xFF00E5FF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              allAdded ? Icons.folder_rounded : Icons.folder_open_rounded,
              color: allAdded
                  ? const Color(0xFF00E5FF)
                  : const Color(0xFF00E5FF).withValues(alpha: 0.6),
              size: 24,
            ),
          ),
          title: Text(
            folder.name,
            style: TextStyle(
                color: allAdded ? const Color(0xFF00E5FF) : Colors.white,
                fontSize: 14,
                fontWeight: allAdded ? FontWeight.w600 : FontWeight.normal),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            added > 0
                ? '$total canciones · $added agregada${added == 1 ? '' : 's'}'
                : '$total canciones',
            style: TextStyle(
                color: added > 0
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.7)
                    : Colors.white38,
                fontSize: 11),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (added > 0 && !allAdded)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$added',
                      style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              if (allAdded)
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF00E5FF), size: 20),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 22),
            ],
          ),
          onTap: () => _openFolderView(folder),
        );
      },
    );
  }

  Widget _buildSongList(List<SongModel> songs, ScrollController scrollCtrl,
      {String emptyText = 'Sin resultados'}) {
    if (songs.isEmpty) {
      return Center(
          child: Text(emptyText,
              style: const TextStyle(color: Colors.white38, fontSize: 14)));
    }
    return ListenableBuilder(
      listenable: PlayerController.instance,
      builder: (_, __) {
        final ctrl = PlayerController.instance;
        return ListView.builder(
          controller: scrollCtrl,
          itemCount: songs.length,
          itemBuilder: (_, i) {
            final song = songs[i];
            final inPlaylist =
                PlaylistManager.instance.hasSong(widget.playlist.id, song.id);
            final isCurrent = ctrl.currentInfo?.id == song.id;
            final isActivePlaying = isCurrent && ctrl.isPlaying;

            return ListTile(
              contentPadding:
                  const EdgeInsets.fromLTRB(16, 4, 8, 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: QueryArtworkWidget(
                  id: song.id,
                  type: ArtworkType.AUDIO,
                  size: 44,
                  nullArtworkWidget: Container(
                    width: 44,
                    height: 44,
                    color: const Color(0xFF1E1E1E),
                    child: Icon(Icons.music_note_rounded,
                        color: isCurrent
                            ? const Color(0xFF00E5FF)
                            : Colors.white38,
                        size: 20),
                  ),
                ),
              ),
              title: Text(
                song.title,
                style: TextStyle(
                  color: isCurrent
                      ? const Color(0xFF00E5FF)
                      : (inPlaylist ? const Color(0xFF00E5FF) : Colors.white),
                  fontSize: 13,
                  fontWeight: (isCurrent || inPlaylist)
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                song.artist ?? 'Desconocido',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // ── Explicit action buttons ──────────────────────────────────
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Play / pause preview
                  IconButton(
                    icon: Icon(
                      isActivePlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_outline_rounded,
                      color: isCurrent
                          ? const Color(0xFF00E5FF)
                          : Colors.white38,
                      size: 28,
                    ),
                    tooltip: isActivePlaying ? 'Pausar' : 'Reproducir',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _previewSong(songs, i),
                  ),
                  // Add / remove from playlist
                  IconButton(
                    icon: Icon(
                      inPlaylist
                          ? Icons.check_circle_rounded
                          : Icons.add_circle_outline_rounded,
                      color: inPlaylist
                          ? const Color(0xFF00E5FF)
                          : Colors.white38,
                      size: 28,
                    ),
                    tooltip: inPlaylist ? 'Quitar de playlist' : 'Agregar',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _toggleSong(song),
                  ),
                ],
              ),
              onTap: () => _previewSong(songs, i),
            );
          },
        );
      },
    );
  }
}
