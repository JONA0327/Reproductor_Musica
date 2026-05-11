import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─── Provider enum ────────────────────────────────────────────────────────────

enum AIProvider { openai, anthropic, gemini }

// ─── Chat history entry ───────────────────────────────────────────────────────

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  const ChatMessage({required this.role, required this.content});
}

// ─── API key storage (SharedPreferences) ──────────────────────────────────────

class AIKeyStore {
  static const _keyMap = {
    AIProvider.openai: 'ai_key_openai',
    AIProvider.anthropic: 'ai_key_anthropic',
    AIProvider.gemini: 'ai_key_gemini',
  };

  static Future<String?> getKey(AIProvider p) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMap[p]!);
  }

  static Future<void> setKey(AIProvider p, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMap[p]!, key.trim());
  }

  static Future<void> clearKey(AIProvider p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMap[p]!);
  }
}

// ─── AI service ───────────────────────────────────────────────────────────────

class AIService {
  /// Sends a message to the selected AI provider and returns the raw text response.
  static Future<String> send({
    required AIProvider provider,
    required String apiKey,
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) {
    return switch (provider) {
      AIProvider.openai =>
        _openai(apiKey, systemPrompt, history, userMessage),
      AIProvider.anthropic =>
        _anthropic(apiKey, systemPrompt, history, userMessage),
      AIProvider.gemini =>
        _gemini(apiKey, systemPrompt, history, userMessage),
    };
  }

  // ── OpenAI (gpt-4o-mini) ──────────────────────────────────────────────────

  static Future<String> _openai(
    String key,
    String system,
    List<ChatMessage> history,
    String msg,
  ) async {
    final messages = [
      {'role': 'system', 'content': system},
      ...history.map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': msg},
    ];
    final resp = await http
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'gpt-4o-mini',
            'messages': messages,
            'max_tokens': 200,
            'temperature': 0.2,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('OpenAI ${resp.statusCode}: ${_extractError(resp.body)}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['choices'][0]['message']['content'] as String;
  }

  // ── Anthropic (claude-haiku-4-5) ─────────────────────────────────────────

  static Future<String> _anthropic(
    String key,
    String system,
    List<ChatMessage> history,
    String msg,
  ) async {
    final messages = [
      ...history.map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': msg},
    ];
    final resp = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'claude-haiku-4-5',
            'system': system,
            'messages': messages,
            'max_tokens': 200,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception(
          'Anthropic ${resp.statusCode}: ${_extractError(resp.body)}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['content'][0]['text'] as String;
  }

  // ── Gemini (gemini-2.0-flash) ─────────────────────────────────────────────

  static Future<String> _gemini(
    String key,
    String system,
    List<ChatMessage> history,
    String msg,
  ) async {
    final contents = [
      ...history.map((m) => {
            'role': m.role == 'assistant' ? 'model' : 'user',
            'parts': [
              {'text': m.content}
            ],
          }),
      {
        'role': 'user',
        'parts': [
          {'text': msg}
        ]
      },
    ];
    final resp = await http
        .post(
          Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$key'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'system_instruction': {
              'parts': [
                {'text': system}
              ]
            },
            'contents': contents,
            'generationConfig': {
              'maxOutputTokens': 200,
              'temperature': 0.2,
            },
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception(
          'Gemini ${resp.statusCode}: ${_extractError(resp.body)}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  // ── Error helper ──────────────────────────────────────────────────────────

  static String _extractError(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      final msg = m['error']?['message'] ?? m['error']?['type'];
      if (msg != null) return msg.toString();
    } catch (_) {}
    final len = body.length.clamp(0, 120);
    return body.substring(0, len);
  }
}

/// Expose provider display names.
extension AIProviderExt on AIProvider {
  String get displayName => switch (this) {
        AIProvider.openai => 'ChatGPT',
        AIProvider.anthropic => 'Claude',
        AIProvider.gemini => 'Gemini',
      };

  String get keyHint => switch (this) {
        AIProvider.openai => 'sk-...',
        AIProvider.anthropic => 'sk-ant-...',
        AIProvider.gemini => 'AIza...',
      };
}
