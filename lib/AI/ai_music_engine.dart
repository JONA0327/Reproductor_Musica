import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:music_reproductor/Explore/playlist_manager.dart';
import 'package:music_reproductor/Player/player_controller.dart';
import 'ai_service.dart';
import 'music_command.dart';

// ─── Chat bubble model ────────────────────────────────────────────────────────

class _Bubble {
  final String text;
  final bool isUser;
  final bool isCommand;
  final bool isError;
  const _Bubble({
    required this.text,
    required this.isUser,
    this.isCommand = false,
    this.isError = false,
  });
}

// ─── Main View ────────────────────────────────────────────────────────────────

class AIMusicEngineView extends StatefulWidget {
  const AIMusicEngineView({super.key});

  @override
  State<AIMusicEngineView> createState() => _AIMusicEngineViewState();
}

class _AIMusicEngineViewState extends State<AIMusicEngineView>
    with WidgetsBindingObserver {
  // Audio query
  final _audioQuery = OnAudioQuery();
  List<SongModel> _allSongs = [];

  // AI state
  AIProvider _provider = AIProvider.openai;
  Set<AIProvider> _availableProviders = {}; // providers with a saved API key
  final List<_Bubble> _bubbles = [];
  final List<ChatMessage> _history = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _loading = false;

  // Speech-to-text
  final SpeechToText _stt = SpeechToText();
  bool _voiceEnabled = false;
  bool _sttAvailable = false;
  bool _isListening = false;
  bool _wasPlayingBeforeStt = false; // to restore after STT steals audio focus

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSongs();
    _initStt();
    _loadAvailableProviders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    if (_isListening) _stt.stop();
    super.dispose();
  }

  // Reload when user returns from Settings (where they may have entered a key)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadAvailableProviders();
  }

  // ── Init helpers ─────────────────────────────────────────────────────────

  Future<void> _loadAvailableProviders() async {
    final available = <AIProvider>{};
    for (final p in AIProvider.values) {
      final key = await AIKeyStore.getKey(p);
      if (key != null && key.trim().isNotEmpty) available.add(p);
    }
    if (!mounted) return;
    setState(() {
      _availableProviders = available;
      // If current provider no longer has a key, switch to first available
      if (!_availableProviders.contains(_provider) &&
          _availableProviders.isNotEmpty) {
        _provider = _availableProviders.first;
      }
    });
  }

  Future<void> _loadSongs() async {
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
        });
      }
    } catch (_) {}
  }

  Future<void> _initStt() async {
    final available = await _stt.initialize(
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
        // Auto-restart if voice mode still active
        if (_voiceEnabled) {
          Future.delayed(const Duration(seconds: 1), _startListening);
        }
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
          // Restore playback if STT stole audio focus and user didn't issue a stop command
          if (_wasPlayingBeforeStt && !PlayerController.instance.isPlaying) {
            PlayerController.instance.togglePlayPause();
          }
          if (_voiceEnabled && !_loading) {
            Future.delayed(const Duration(milliseconds: 600), _startListening);
          }
        }
      },
    );
    if (mounted) setState(() => _sttAvailable = available);
  }

  // ── Voice toggle ─────────────────────────────────────────────────────────

  Future<void> _toggleVoice() async {
    if (_voiceEnabled) {
      // Disable
      await _stt.stop();
      if (mounted) setState(() { _voiceEnabled = false; _isListening = false; });
      return;
    }

    // Enable: request microphone permission first
    final status = await Permission.microphone.request();
    if (!mounted) return;

    if (status.isPermanentlyDenied) {
      _showSnack(
        'Permiso de micrófono bloqueado. Actívalo en Configuración del sistema.',
        isError: true,
      );
      return;
    }
    if (!status.isGranted) {
      _showSnack('Permiso de micrófono denegado.', isError: true);
      return;
    }
    if (!_sttAvailable) {
      _showSnack(
        'Reconocimiento de voz no disponible en este dispositivo.',
        isError: true,
      );
      return;
    }

    setState(() => _voiceEnabled = true);
    await _startListening();
  }

  Future<void> _startListening() async {
    if (!_voiceEnabled || !_sttAvailable || _isListening || _loading) return;
    _wasPlayingBeforeStt = PlayerController.instance.isPlaying;
    try {
      setState(() => _isListening = true);
      await _stt.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            final text = result.recognizedWords;
            if (mounted) setState(() => _isListening = false);
            _sendMessage(text);
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          partialResults: false,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _isListening = false);
    }
  }

  // ── System prompt ─────────────────────────────────────────────────────────

  String _buildSystemPrompt() {
    final buf = StringBuffer()
      ..writeln('Eres un asistente de música integrado en una app de reproducción.')
      ..writeln('Tu ÚNICA tarea es interpretar comandos y responder EXCLUSIVAMENTE con JSON.')
      ..writeln()
      ..writeln('Esquemas de respuesta (elige uno según el comando):')
      ..writeln('  • Reproducir canción:   {"action":"play_song","target":"título exacto o similar"}')
      ..writeln('  • Reproducir playlist:  {"action":"play_playlist","target":"nombre de playlist"}')
      ..writeln('  • Pausar / Reanudar:    {"action":"toggle_play"}')
      ..writeln('  • Siguiente canción:    {"action":"next"}')
      ..writeln('  • Canción anterior:     {"action":"previous"}')
      ..writeln('  • Conversación normal:  {"action":"chat","message":"tu respuesta"}')
      ..writeln();

    // Songs list (top 250 titles to stay within token budget)
    if (_allSongs.isNotEmpty) {
      final titles = _allSongs
          .take(250)
          .map((s) => '"${s.title}"')
          .join(', ');
      buf
        ..writeln('Canciones disponibles:')
        ..writeln('[$titles]')
        ..writeln();
    }

    // Playlists
    final playlists = PlaylistManager.instance.playlists;
    if (playlists.isNotEmpty) {
      final names = playlists.map((p) => '"${p.name}"').join(', ');
      buf
        ..writeln('Playlists disponibles:')
        ..writeln('[$names]')
        ..writeln();
    }

    buf
      ..writeln('IMPORTANTE: Responde SOLO con JSON válido, sin texto fuera del JSON.')
      ..writeln('Usa el mismo idioma del usuario para los mensajes de chat.');

    return buf.toString();
  }

  // ── Send message ──────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;
    _inputCtrl.clear();

    setState(() {
      _bubbles.add(_Bubble(text: trimmed, isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    // 1 — Try offline quick commands (no token cost), pass songs + playlists
    final offline = MusicCommandParser.tryOffline(
      trimmed,
      allSongs: _allSongs,
      playlists: PlaylistManager.instance.playlists,
    );
    if (offline != null) {
      _executeCommand(offline);
      setState(() => _loading = false);
      _maybeRestartListening();
      return;
    }

    // 2 — Check API key
    final key = await AIKeyStore.getKey(_provider);
    if (key == null || key.isEmpty) {
      setState(() {
        _bubbles.add(_Bubble(
          text: 'No hay API key para ${_provider.displayName}. '
              'Ve a Configuración → IA Music Engine para agregarla.',
          isUser: false,
          isError: true,
        ));
        _loading = false;
      });
      _scrollToBottom();
      _maybeRestartListening();
      return;
    }

    // 3 — Call AI
    try {
      // Keep context window small (last 10 turns)
      final contextHistory = _history.length > 10
          ? _history.sublist(_history.length - 10)
          : List<ChatMessage>.from(_history);

      final response = await AIService.send(
        provider: _provider,
        apiKey: key,
        systemPrompt: _buildSystemPrompt(),
        history: contextHistory,
        userMessage: trimmed,
      );

      _history
        ..add(ChatMessage(role: 'user', content: trimmed))
        ..add(ChatMessage(role: 'assistant', content: response));

      final command = MusicCommandParser.parse(response, _allSongs);
      _executeCommand(command);
    } catch (e) {
      final errMsg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _bubbles.add(_Bubble(text: 'Error: $errMsg', isUser: false, isError: true));
      });
    }

    setState(() => _loading = false);
    _scrollToBottom();
    _maybeRestartListening();
  }

  // ── Execute command ───────────────────────────────────────────────────────

  void _executeCommand(MusicCommand cmd) {
    final ctrl = PlayerController.instance;
    switch (cmd) {
      case PlaySongCommand(song: final song, queue: final queue, index: final idx):
        ctrl.playFolder(queue, idx, 'ai_engine');
        setState(() => _bubbles.add(_Bubble(
          text:
              '▶  ${song.title}${song.artist != null ? '  —  ${song.artist}' : ''}',
          isUser: false,
          isCommand: true,
        )));

      case PlayPlaylistCommand(playlist: final pl):
        ctrl.playPlaylistChain([pl]);
        setState(() => _bubbles.add(_Bubble(
          text: '▶  Playlist "${pl.name}"  (${pl.songs.length} canciones)',
          isUser: false,
          isCommand: true,
        )));

      case TogglePlayCommand():
        ctrl.togglePlayPause();
        setState(() => _bubbles.add(_Bubble(
          text: ctrl.isPlaying ? '⏸  Pausado' : '▶  Reproduciendo',
          isUser: false,
          isCommand: true,
        )));

      case NextCommand():
        ctrl.next();
        setState(() => _bubbles.add(
            const _Bubble(text: '⏭  Siguiente canción', isUser: false, isCommand: true)));

      case PreviousCommand():
        ctrl.previous();
        setState(() => _bubbles.add(
            const _Bubble(text: '⏮  Canción anterior', isUser: false, isCommand: true)));

      case ChatResponseCommand(message: final msg):
        setState(() => _bubbles.add(_Bubble(text: msg, isUser: false)));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _maybeRestartListening() {
    if (_voiceEnabled) {
      Future.delayed(const Duration(milliseconds: 800), _startListening);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF00E5FF),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildProviderChips(),
          const Divider(height: 1, color: Color(0xFF1A1A1A)),
          Expanded(child: _buildChatArea()),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFF00E5FF), size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'IA Music Engine',
            style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          // Voice toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _voiceEnabled
                    ? (_isListening
                        ? Icons.mic_rounded
                        : Icons.mic_none_rounded)
                    : Icons.mic_off_rounded,
                color: _voiceEnabled
                    ? (_isListening
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFF00E5FF).withValues(alpha: 0.5))
                    : Colors.white24,
                size: 20,
              ),
              Switch(
                value: _voiceEnabled,
                onChanged: (_) => _toggleVoice(),
                activeThumbColor: const Color(0xFF00E5FF),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                trackOutlineColor:
                    WidgetStateProperty.all(Colors.transparent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Provider chips ────────────────────────────────────────────────────────

  Widget _buildProviderChips() {
    // Only show providers that have a saved API key
    final providers = AIProvider.values
        .where((p) => _availableProviders.contains(p))
        .toList();

    if (providers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: const [
            Icon(Icons.key_off_rounded, size: 14, color: Colors.white30),
            SizedBox(width: 6),
            Text(
              'Sin API keys — ve a Configuración para agregarlas',
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: providers.map((p) {
          final selected = _provider == p;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                p.displayName,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white54,
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              selected: selected,
              onSelected: (_) => setState(() => _provider = p),
              selectedColor: const Color(0xFF00E5FF),
              backgroundColor: const Color(0xFF1A1A1A),
              side: BorderSide(
                color: selected
                    ? const Color(0xFF00E5FF)
                    : Colors.white12,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              visualDensity: VisualDensity.compact,
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Chat area ─────────────────────────────────────────────────────────────

  Widget _buildChatArea() {
    if (_bubbles.isEmpty) return _buildEmptyState();
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      itemCount: _bubbles.length + (_loading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _bubbles.length) return _buildTypingDots();
        return _buildBubble(_bubbles[i]);
      },
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFF00E5FF), size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tu DJ con Inteligencia Artificial',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Escribe o activa el micrófono y di:\n\n'
            '"Cambia a [canción]"\n'
            '"Reproduce la playlist Favoritas"\n'
            '"Siguiente" · "Pausa" · "Anterior"',
            style: TextStyle(
                color: Colors.white38, fontSize: 13, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '⚡  Comandos simples (pausa, siguiente) se ejecutan\n'
              'sin gastar tokens de IA.',
              style: TextStyle(color: Colors.white30, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_Bubble b) {
    Color bg;
    Color textColor;
    Border? border;

    if (b.isUser) {
      bg = const Color(0xFF00E5FF);
      textColor = Colors.black;
    } else if (b.isCommand) {
      bg = const Color(0xFF0D2525);
      textColor = const Color(0xFF00E5FF);
      border = Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.25));
    } else if (b.isError) {
      bg = const Color(0xFF2A0F0F);
      textColor = const Color(0xFFFF6B6B);
      border =
          Border.all(color: Colors.redAccent.withValues(alpha: 0.25));
    } else {
      bg = const Color(0xFF1A1A1A);
      textColor = Colors.white;
    }

    return Align(
      alignment: b.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(b.isUser ? 16 : 4),
            bottomRight: Radius.circular(b.isUser ? 4 : 16),
          ),
          border: border,
        ),
        child: Text(b.text,
            style: TextStyle(color: textColor, fontSize: 14, height: 1.4)),
      ),
    );
  }

  Widget _buildTypingDots() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimDot(delay: 0),
            SizedBox(width: 5),
            _AnimDot(delay: 180),
            SizedBox(width: 5),
            _AnimDot(delay: 360),
          ],
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: const Color(0xFF0A0A0A),
      child: Row(
        children: [
          // Listening indicator
          if (_voiceEnabled && _isListening)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const _PulsingMic(),
              ),
            ),

          // Text field
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
              decoration: InputDecoration(
                hintText: _voiceEnabled && _isListening
                    ? 'Escuchando...'
                    : 'Escribe un comando...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: _loading ? null : () => _sendMessage(_inputCtrl.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _loading
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFF00E5FF),
                shape: BoxShape.circle,
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Color(0xFF00E5FF)))
                  : const Icon(Icons.send_rounded,
                      color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated typing dot ──────────────────────────────────────────────────────

class _AnimDot extends StatefulWidget {
  final int delay;
  const _AnimDot({required this.delay});

  @override
  State<_AnimDot> createState() => _AnimDotState();
}

class _AnimDotState extends State<_AnimDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
            color: Color(0xFF00E5FF), shape: BoxShape.circle),
      ),
    );
  }
}

// ─── Pulsing mic icon ─────────────────────────────────────────────────────────

class _PulsingMic extends StatefulWidget {
  const _PulsingMic();

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity:
          Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl),
      child: const Icon(Icons.mic_rounded,
          color: Color(0xFF00E5FF), size: 18),
    );
  }
}
