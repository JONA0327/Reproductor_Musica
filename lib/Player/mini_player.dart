import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'player_controller.dart';

/// Compact player bar shown above the bottom nav bar while music plays.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PlayerController.instance,
      builder: (_, __) {
        final ctrl = PlayerController.instance;
        final song = ctrl.currentSong;
        if (song == null) return const SizedBox.shrink();

        final totalMs = ctrl.duration.inMilliseconds;
        final progress = totalMs > 0
            ? (ctrl.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0;

        return Material(
          color: const Color(0xFF141414),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 1, color: const Color(0xFF2A2A2A)),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                minHeight: 2,
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Artwork
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: QueryArtworkWidget(
                        id: song.id,
                        type: ArtworkType.AUDIO,
                        size: 40,
                        nullArtworkWidget: Container(
                          width: 40,
                          height: 40,
                          color: const Color(0xFF1E1E1E),
                          child: const Icon(Icons.music_note_rounded,
                              color: Color(0xFF00E5FF), size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Song info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(song.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(song.artist ?? 'Desconocido',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    // Controls
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded,
                          color: Colors.white60, size: 24),
                      onPressed: () => ctrl.previous(),
                      visualDensity: VisualDensity.compact,
                    ),
                    GestureDetector(
                      onTap: () => ctrl.togglePlayPause(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                            color: Color(0xFF00E5FF),
                            shape: BoxShape.circle),
                        child: Icon(
                          ctrl.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded,
                          color: Colors.white60, size: 24),
                      onPressed: () => ctrl.next(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
