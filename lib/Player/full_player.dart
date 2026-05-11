import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'player_controller.dart';

/// Full-screen player page. Opened by tapping the mini player.
class FullPlayerPage extends StatefulWidget {
  const FullPlayerPage({super.key});

  @override
  State<FullPlayerPage> createState() => _FullPlayerPageState();
}

class _FullPlayerPageState extends State<FullPlayerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _specCtrl;

  @override
  void initState() {
    super.initState();
    // Short duration → fast but smooth sine oscillation
    _specCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncAnim();
    PlayerController.instance.addListener(_syncAnim);
  }

  /// Keep animation ticker alive only while actually playing — saves CPU/GPU.
  void _syncAnim() {
    if (!mounted) return;
    if (PlayerController.instance.isPlaying) {
      if (!_specCtrl.isAnimating) _specCtrl.repeat();
    } else {
      if (_specCtrl.isAnimating) _specCtrl.stop();
    }
  }

  @override
  void dispose() {
    PlayerController.instance.removeListener(_syncAnim);
    _specCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: ListenableBuilder(
        listenable: PlayerController.instance,
        builder: (_, _) {
          final ctrl = PlayerController.instance;
          final info = ctrl.currentInfo;

          if (info == null) {
            // Nothing playing → close page
            WidgetsBinding.instance
                .addPostFrameCallback((_) => Navigator.of(context).maybePop());
            return const SizedBox.shrink();
          }

          final totalMs = ctrl.duration.inMilliseconds;
          final progress = totalMs > 0
              ? (ctrl.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
              : 0.0;

          return SafeArea(
            child: Column(
              children: [
                // ── Top bar ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white60, size: 32),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'REPRODUCIENDO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Album Art ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Hero(
                      tag: 'mini_player_artwork',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: QueryArtworkWidget(
                          id: info.id,
                          type: ArtworkType.AUDIO,
                          size: 320,
                          quality: 90,
                          nullArtworkWidget: Container(
                            color: const Color(0xFF181818),
                            child: const Icon(Icons.music_note_rounded,
                                color: Color(0xFF00E5FF), size: 80),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Spectrogram ────────────────────────────────────────────
                // RepaintBoundary isolates repaints to this widget only.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _specCtrl,
                      builder: (_, _) => CustomPaint(
                        size: const Size(double.infinity, 46),
                        painter: _SpectrumPainter(
                          progress: _specCtrl.value,
                          isPlaying: ctrl.isPlaying,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ── Title + Artist ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        info.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.artist ?? 'Desconocido',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ── Seek bar ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16),
                          activeTrackColor: const Color(0xFF00E5FF),
                          inactiveTrackColor: const Color(0xFF2A2A2A),
                          thumbColor: Colors.white,
                          overlayColor:
                              const Color(0xFF00E5FF).withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: progress,
                          onChanged: (v) {
                            if (totalMs > 0) {
                              ctrl.seek(Duration(
                                  milliseconds: (v * totalMs).round()));
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(PlayerController.fmt(ctrl.position),
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                            Text(PlayerController.fmt(ctrl.duration),
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // ── Playback Controls ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Shuffle
                      IconButton(
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: ctrl.isShuffle
                              ? const Color(0xFF00E5FF)
                              : Colors.white38,
                          size: 24,
                        ),
                        onPressed: ctrl.toggleShuffle,
                      ),
                      // Previous
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded,
                            color: Colors.white, size: 38),
                        onPressed: ctrl.previous,
                      ),
                      // Play / Pause
                      GestureDetector(
                        onTap: ctrl.togglePlayPause,
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: const BoxDecoration(
                              color: Color(0xFF00E5FF),
                              shape: BoxShape.circle),
                          child: Icon(
                            ctrl.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 38,
                          ),
                        ),
                      ),
                      // Next
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded,
                            color: Colors.white, size: 38),
                        onPressed: ctrl.next,
                      ),
                      // Spacer (balance shuffle button)
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Lightweight spectrum visualizer ─────────────────────────────────────────
//
// Approach: pure math (layered sine waves) — zero audio analysis, zero FFT.
// 22 bars × 2 sin() calls = 44 trig ops per frame. Very fast on any device.
// Static lists computed once (no allocation in paint()).
// RepaintBoundary ensures only this 46px tall widget repaints at 60 fps.

class _SpectrumPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;

  // Pre-computed per-bar constants — allocated once, reused every frame.
  static const int _barCount = 22;
  static final List<double> _freqs = List.unmodifiable(
    List.generate(_barCount, (i) => 1.4 + (i / _barCount) * 3.6),
  );
  static final List<double> _phases = List.unmodifiable(
    List.generate(_barCount, (i) => (i * 0.43) % (2 * math.pi)),
  );

  const _SpectrumPainter({required this.progress, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    const double gap = 3.5;
    final double barW =
        (size.width - gap * (_barCount - 1)) / _barCount;
    final double maxH = size.height;
    final double t = progress * 2 * math.pi;

    // Single Paint object — no allocation inside the loop.
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFF00E5FF), Color(0xFF006E84)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, maxH));

    for (int i = 0; i < _barCount; i++) {
      final double h;
      if (isPlaying) {
        // Two layered sine waves: creates organic, non-repetitive motion.
        final double raw =
            math.sin(t * _freqs[i] + _phases[i]) * 0.35 +
            math.sin(t * _freqs[i] * 0.52 + _phases[i] + 1.1) * 0.22 +
            0.47;
        h = (raw * maxH).clamp(4.0, maxH);
      } else {
        // Paused: tiny static bars derived from phase (no animation tick needed).
        h = 3.0 + (math.sin(_phases[i]) * 0.5 + 0.5) * 6.0;
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (barW + gap), maxH - h, barW, h),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.progress != progress || old.isPlaying != isPlaying;
}
