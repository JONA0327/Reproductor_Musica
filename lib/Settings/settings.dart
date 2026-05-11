import 'package:flutter/material.dart';
import 'package:music_reproductor/AI/ai_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Preferences state
  bool _highQualityStream = true;
  bool _downloadOverWifi = true;
  bool _showLyrics = true;
  bool _crossfade = false;
  bool _gaplessPlayback = true;
  bool _equalizerEnabled = false;
  double _crossfadeDuration = 3.0;
  String _audioQuality = 'Alta';
  String _theme = 'Oscuro';

  // AI key controllers
  final _openaiCtrl = TextEditingController();
  final _anthropicCtrl = TextEditingController();
  final _geminiCtrl = TextEditingController();
  bool _showOpenaiKey = false;
  bool _showAnthropicKey = false;
  bool _showGeminiKey = false;

  final List<String> _audioQualities = ['Normal', 'Alta', 'Sin pérdida'];
  final List<String> _themes = ['Oscuro', 'Claro', 'Sistema'];

  @override
  void initState() {
    super.initState();
    _loadAIKeys();
  }

  @override
  void dispose() {
    _openaiCtrl.dispose();
    _anthropicCtrl.dispose();
    _geminiCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAIKeys() async {
    final openai = await AIKeyStore.getKey(AIProvider.openai);
    final anthropic = await AIKeyStore.getKey(AIProvider.anthropic);
    final gemini = await AIKeyStore.getKey(AIProvider.gemini);
    if (mounted) {
      setState(() {
        _openaiCtrl.text = openai ?? '';
        _anthropicCtrl.text = anthropic ?? '';
        _geminiCtrl.text = gemini ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: const [
                  Text(
                    'Configuración',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Audio section
          SliverToBoxAdapter(child: _sectionHeader(Icons.graphic_eq_rounded, 'Audio')),
          SliverToBoxAdapter(
            child: _settingsCard([
              _dropdownTile(
                icon: Icons.high_quality_rounded,
                title: 'Calidad de audio',
                subtitle: 'Formato de reproducción',
                value: _audioQuality,
                items: _audioQualities,
                onChanged: (v) => setState(() => _audioQuality = v!),
              ),
              _divider(),
              _switchTile(
                icon: Icons.tune_rounded,
                title: 'Ecualizador',
                subtitle: 'Ajustar frecuencias de audio',
                value: _equalizerEnabled,
                onChanged: (v) => setState(() => _equalizerEnabled = v),
                activeColor: const Color(0xFF00E5FF),
              ),
              _divider(),
              _switchTile(
                icon: Icons.skip_next_rounded,
                title: 'Reproducción sin pausas',
                subtitle: 'Sin silencios entre canciones',
                value: _gaplessPlayback,
                onChanged: (v) => setState(() => _gaplessPlayback = v),
                activeColor: const Color(0xFF00E5FF),
              ),
              _divider(),
              _switchTile(
                icon: Icons.swap_horiz_rounded,
                title: 'Crossfade',
                subtitle: 'Mezclar transiciones entre canciones',
                value: _crossfade,
                onChanged: (v) => setState(() => _crossfade = v),
                activeColor: const Color(0xFF00E5FF),
              ),
              if (_crossfade) ...[
                _divider(),
                _sliderTile(
                  icon: Icons.timer_rounded,
                  title: 'Duración del crossfade',
                  subtitle: '${_crossfadeDuration.toStringAsFixed(1)} segundos',
                  value: _crossfadeDuration,
                  min: 1,
                  max: 10,
                  onChanged: (v) => setState(() => _crossfadeDuration = v),
                ),
              ],
            ]),
          ),

          // Biblioteca section
          SliverToBoxAdapter(child: _sectionHeader(Icons.library_music_rounded, 'Biblioteca')),
          SliverToBoxAdapter(
            child: _settingsCard([
              _switchTile(
                icon: Icons.wifi_rounded,
                title: 'Descargar solo con Wi-Fi',
                subtitle: 'Ahorra datos móviles',
                value: _downloadOverWifi,
                onChanged: (v) => setState(() => _downloadOverWifi = v),
                activeColor: const Color(0xFF00E5FF),
              ),
              _divider(),
              _switchTile(
                icon: Icons.lyrics_rounded,
                title: 'Mostrar letra',
                subtitle: 'Letra sincronizada durante la reproducción',
                value: _showLyrics,
                onChanged: (v) => setState(() => _showLyrics = v),
                activeColor: const Color(0xFF00E5FF),
              ),
            ]),
          ),

          // Apariencia section
          SliverToBoxAdapter(child: _sectionHeader(Icons.palette_rounded, 'Apariencia')),
          SliverToBoxAdapter(
            child: _settingsCard([
              _dropdownTile(
                icon: Icons.dark_mode_rounded,
                title: 'Tema',
                subtitle: 'Color del interfaz',
                value: _theme,
                items: _themes,
                onChanged: (v) => setState(() => _theme = v!),
              ),
              _divider(),
              _switchTile(
                icon: Icons.signal_cellular_alt_rounded,
                title: 'Streaming en alta calidad',
                subtitle: 'Mayor uso de datos',
                value: _highQualityStream,
                onChanged: (v) => setState(() => _highQualityStream = v),
                activeColor: const Color(0xFF00E5FF),
              ),
            ]),
          ),

          // IA Music Engine keys section
          SliverToBoxAdapter(
            child: _sectionHeader(Icons.auto_awesome_rounded, 'IA Music Engine'),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        Icon(Icons.key_rounded, size: 15, color: Colors.white38),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ingresa la API key de cada proveedor. '
                            'Solo se almacena localmente en tu dispositivo.',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _apiKeyField(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'ChatGPT (OpenAI)',
                    hint: 'sk-…',
                    controller: _openaiCtrl,
                    visible: _showOpenaiKey,
                    onToggleVisible: () =>
                        setState(() => _showOpenaiKey = !_showOpenaiKey),
                    onSave: () =>
                        AIKeyStore.setKey(AIProvider.openai, _openaiCtrl.text),
                  ),
                  Divider(
                      height: 1,
                      thickness: 1,
                      indent: 56,
                      color: Colors.white.withOpacity(0.06)),
                  _apiKeyField(
                    icon: Icons.auto_fix_high_rounded,
                    label: 'Claude (Anthropic)',
                    hint: 'sk-ant-…',
                    controller: _anthropicCtrl,
                    visible: _showAnthropicKey,
                    onToggleVisible: () =>
                        setState(() => _showAnthropicKey = !_showAnthropicKey),
                    onSave: () => AIKeyStore.setKey(
                        AIProvider.anthropic, _anthropicCtrl.text),
                  ),
                  Divider(
                      height: 1,
                      thickness: 1,
                      indent: 56,
                      color: Colors.white.withOpacity(0.06)),
                  _apiKeyField(
                    icon: Icons.stars_rounded,
                    label: 'Gemini (Google)',
                    hint: 'AIza…',
                    controller: _geminiCtrl,
                    visible: _showGeminiKey,
                    onToggleVisible: () =>
                        setState(() => _showGeminiKey = !_showGeminiKey),
                    onSave: () =>
                        AIKeyStore.setKey(AIProvider.gemini, _geminiCtrl.text),
                  ),
                ],
              ),
            ),
          ),

          // Acerca de section
          SliverToBoxAdapter(child: _sectionHeader(Icons.info_outline_rounded, 'Acerca de')),
          SliverToBoxAdapter(
            child: _settingsCard([
              _actionTile(
                icon: Icons.verified_rounded,
                title: 'Versión',
                subtitle: '1.0.0',
                onTap: null,
                trailing: const Text('1.0.0', style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),
              _divider(),
              _actionTile(
                icon: Icons.policy_rounded,
                title: 'Política de privacidad',
                onTap: () {},
              ),
              _divider(),
              _actionTile(
                icon: Icons.description_rounded,
                title: 'Términos de uso',
                onTap: () {},
              ),
              _divider(),
              _actionTile(
                icon: Icons.delete_sweep_rounded,
                title: 'Limpiar caché',
                subtitle: 'Eliminar datos temporales',
                onTap: () => _showClearCacheDialog(),
                iconColor: Colors.redAccent,
              ),
            ]),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF00E5FF)),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF00E5FF),
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 1,
        indent: 56,
        color: Colors.white.withOpacity(0.06),
      );

  Widget _switchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? activeColor,
    Color? iconColor,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Icon(icon, color: iconColor ?? Colors.white54, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12))
          : null,
      value: value,
      onChanged: onChanged,
      activeColor: activeColor ?? const Color(0xFF00E5FF),
    );
  }

  Widget _dropdownTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    Color? iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: iconColor ?? Colors.white54, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12))
          : null,
      trailing: DropdownButton<String>(
        value: value,
        dropdownColor: const Color(0xFF1A1A1A),
        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13),
        underline: const SizedBox(),
        icon: const Icon(Icons.expand_more_rounded, color: Colors.white38, size: 18),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _sliderTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          leading: Icon(icon, color: Colors.white54, size: 22),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: subtitle != null
              ? Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12))
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(52, 0, 16, 4),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00E5FF),
              thumbColor: const Color(0xFF00E5FF),
              inactiveTrackColor: Colors.white12,
              overlayColor: const Color(0xFF00E5FF).withOpacity(0.15),
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: iconColor ?? Colors.white54, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12))
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20)
              : null),
      onTap: onTap,
    );
  }

  Widget _apiKeyField({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool visible,
    required VoidCallback onToggleVisible,
    required VoidCallback onSave,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white54),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: !visible,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13,
                      fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0F0F0F),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        visible
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white24,
                        size: 18,
                      ),
                      onPressed: onToggleVisible,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  onSave();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Key de $label guardada'),
                    backgroundColor: const Color(0xFF00E5FF),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ));
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00E5FF),
                  backgroundColor:
                      const Color(0xFF00E5FF).withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Guardar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Limpiar caché', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Deseas eliminar todos los datos temporales? Esto no afecta a tus canciones descargadas.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }
}
