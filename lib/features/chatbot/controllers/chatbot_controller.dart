import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

/// A single message in the chat thread. `role` is either 'user' or
/// 'assistant' — matches the shape Groq's chat-completions API expects,
/// so the whole history can be forwarded as-is.
class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatbotState {
  final List<ChatMessage> messages;
  final bool isSending;
  final String? error;

  const ChatbotState({
    this.messages = const [],
    this.isSending = false,
    this.error,
  });

  ChatbotState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    String? error,
  }) {
    return ChatbotState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

final chatbotControllerProvider =
StateNotifierProvider<ChatbotController, ChatbotState>((ref) {
  return ChatbotController();
});

class ChatbotController extends StateNotifier<ChatbotState> {
  ChatbotController() : super(const ChatbotState()) {
    _seedGreeting();
  }

  final _supabase = Supabase.instance.client;
  final _dio = Dio();

  // Reuses the same Groq proxy the meal planner talks to — it's a
  // generic authenticated passthrough (see
  // supabase/functions/groq-proxy/index.ts), not meal-plan-specific,
  // so there's no need for a second identical function just for the
  // chatbot's calls.
  static const String _groqProxyUrl =
      'https://ghobobiocpjfiwcrrfbr.supabase.co/functions/v1/groq-proxy';

  void _seedGreeting() {
    state = state.copyWith(messages: [
      ChatMessage(
        role: 'assistant',
        content:
        "Hi! I'm your Eatsy assistant. Ask me anything about the app — "
            "how to log food, scan barcodes, set goals — or about your "
            "own progress today, like how many calories you have left.",
      ),
    ]);
  }

  /// Same auth pattern as meal_plan_screen.dart's _groqAuthOptions(): the
  /// proxy requires the user's real session token, not the anon key.
  Options _groqAuthOptions() {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw Exception('Not signed in — please log in again.');
    }
    return Options(
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      validateStatus: (status) => true,
    );
  }

  /// Pulls together a compact snapshot of the user's goals, today's
  /// logged meals, and diet preferences so the assistant can answer
  /// personal questions ("how many calories do I have left today?")
  /// without needing tool-calling. Kept intentionally short — this gets
  /// re-sent as part of the system prompt on every message, so it isn't
  /// worth including full history or anything the model doesn't need.
  Future<String> _buildUserContext() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 'The user is not signed in.';

    final buffer = StringBuffer();

    try {
      final goals = await _supabase
          .from('goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (goals != null) {
        buffer.writeln(
          'Daily goals — calories: ${goals['daily_calories'] ?? 'not set'}, '
              'protein: ${goals['protein_goal'] ?? 'not set'}g, '
              'carbs: ${goals['carbs_goal'] ?? 'not set'}g, '
              'fat: ${goals['fat_goal'] ?? 'not set'}g, '
              'weight goal: ${goals['weight_goal'] ?? 'not set'}kg.',
        );
      } else {
        buffer.writeln('The user has not set any goals yet.');
      }
    } catch (_) {
      buffer.writeln('(Goals could not be loaded.)');
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final logs = await _supabase
          .from('food_logs')
          .select()
          .eq('user_id', userId)
          .gte('logged_at', startOfDay.toIso8601String());

      final List<dynamic> logList = logs as List<dynamic>;
      if (logList.isEmpty) {
        buffer.writeln('Nothing logged yet today.');
      } else {
        double cals = 0, protein = 0, carbs = 0, fat = 0;
        for (final log in logList) {
          cals += ((log['calories'] ?? 0) as num).toDouble();
          protein += ((log['protein'] ?? 0) as num).toDouble();
          carbs += ((log['carbs'] ?? 0) as num).toDouble();
          fat += ((log['fat'] ?? 0) as num).toDouble();
        }
        buffer.writeln(
          'So far today: ${cals.round()} kcal, ${protein.round()}g protein, '
              '${carbs.round()}g carbs, ${fat.round()}g fat, across '
              '${logList.length} logged item(s).',
        );
      }
    } catch (_) {
      buffer.writeln("(Today's logs could not be loaded.)");
    }

    try {
      final prefs = await _supabase
          .from('diet_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (prefs != null) {
        final cuisines =
        List<String>.from(prefs['cuisine_preference'] ?? const []);
        final allergies =
        List<String>.from(prefs['allergies'] ?? const []);
        final dietType = prefs['diet_type']?.toString() ?? 'no_restriction';
        buffer.writeln(
          'Diet preferences — type: $dietType, '
              'cuisines: ${cuisines.isEmpty ? 'none set' : cuisines.join(', ')}, '
              'allergies: ${allergies.isEmpty ? 'none' : allergies.join(', ')}.',
        );
      }
    } catch (_) {
      // Diet preferences are optional context — silently skip if the
      // table isn't reachable rather than surfacing an error for a
      // non-essential detail.
    }

    return buffer.toString();
  }

  static const String _systemPromptBase = '''
You are the in-app assistant for Eatsy, a nutrition and calorie tracking app.
Answer questions about how to use the app (logging food, scanning barcodes,
setting goals, generating AI meal plans, tracking water) and, when relevant,
use the user's data snapshot below to answer personal questions about their
progress. Keep answers short and conversational — a few sentences, not an
essay. If asked something with no connection to nutrition, health, or the
app itself, gently steer back. You are not a doctor; for medical questions,
suggest they consult a professional rather than giving medical advice.
''';

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isSending) return;

    final userMessage = ChatMessage(role: 'user', content: text.trim());
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
      error: null,
    );

    try {
      final context = await _buildUserContext();

      final apiMessages = [
        {
          'role': 'system',
          'content': '$_systemPromptBase\n\nUser data snapshot:\n$context',
        },
        // Forward the visible conversation so the model has context of
        // what's already been said. Skipped the initial static greeting
        // since it's not something the model said itself.
        ...state.messages
            .where((m) => m != state.messages.first)
            .map((m) => {'role': m.role, 'content': m.content}),
        {'role': 'user', 'content': userMessage.content},
      ];

      final response = await _dio.post(
        _groqProxyUrl,
        options: _groqAuthOptions(),
        data: {
          'model': 'llama-3.3-70b-versatile',
          'max_tokens': 500,
          'messages': apiMessages,
        },
      );

      if (response.statusCode == 200) {
        final reply =
        response.data['choices'][0]['message']['content'] as String;
        state = state.copyWith(
          messages: [
            ...state.messages,
            ChatMessage(role: 'assistant', content: reply.trim()),
          ],
          isSending: false,
        );
      } else {
        state = state.copyWith(
          isSending: false,
          error: 'The assistant is unavailable right now. Please try again.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: 'Something went wrong: $e',
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}