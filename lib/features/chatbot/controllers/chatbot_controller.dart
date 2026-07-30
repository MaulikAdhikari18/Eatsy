import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/day_boundary.dart';

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  const ChatMessage({required this.role, required this.content});
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isSending;
  final String? errorMessage;

  const ChatState({
    this.messages = const [],
    this.isSending = false,
    this.errorMessage,
  });
}

/// The in-app chatbot — answers questions about how to use Eatsy, and
/// (per explicit product decision) questions about the person's own
/// data: goals, diet preferences, what they've logged today.
///
/// Chat history is session-only, not persisted to Supabase — same
/// deliberate scoping as tipDismissedProvider's dismissed state:
/// there's no backing table, and a fresh conversation each time you
/// open the chatbot is a reasonable, much simpler v1 than building
/// message persistence for what's fundamentally a help/support
/// surface, not a saved conversation history feature.
///
/// Reuses groq-proxy rather than a separate chatbot-specific Edge
/// Function — it's already a generic {model, max_tokens, messages}
/// pass-through with no meal-plan-specific logic in it (confirmed by
/// reading its actual implementation), so a second near-identical
/// proxy would just be duplication for no benefit.
class ChatbotController extends StateNotifier<ChatState> {
  ChatbotController() : super(const ChatState());

  final _supabase = Supabase.instance.client;

  static const _proxyUrl =
      'https://ghobobiocpjfiwcrrfbr.supabase.co/functions/v1/groq-proxy';

  // Same model already confirmed working for meal plan generation and
  // meal swaps in meal_plan_screen.dart — reusing it rather than
  // picking a different one keeps behavior/cost predictable across
  // every AI feature in the app.
  static const _model = 'llama-3.3-70b-versatile';

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final userMessage = ChatMessage(role: 'user', content: trimmed);
    state = ChatState(
      messages: [...state.messages, userMessage],
      isSending: true,
    );

    try {
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('Not signed in');

      final systemPrompt = await _buildSystemPrompt();

      final dio = Dio();
      final response = await dio.post(
        _proxyUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          validateStatus: (status) => true,
        ),
        data: {
          'model': _model,
          'max_tokens': 500,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            // Full conversation so far, not just the new message —
            // Groq's chat completions endpoint is stateless per call,
            // so the whole history has to be resent every time for the
            // assistant to have any memory of earlier turns.
            ...state.messages.map((m) => {'role': m.role, 'content': m.content}),
          ],
        },
      );

      if (response.statusCode == 200) {
        final content =
        response.data['choices'][0]['message']['content'] as String;
        state = ChatState(
          messages: [
            ...state.messages,
            ChatMessage(role: 'assistant', content: content.trim()),
          ],
          isSending: false,
        );
      } else {
        throw Exception('Non-200 from proxy: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Chatbot error: $e');
      // The failed user message stays in state.messages (so it's not
      // silently lost from the transcript), but isSending clears and
      // errorMessage lets the UI show a retry-friendly message rather
      // than leaving the person staring at a stuck loading indicator.
      state = ChatState(
        messages: state.messages,
        isSending: false,
        errorMessage: "Couldn't get a response — please try again.",
      );
    }
  }

  /// Pulls the person's goals, diet preferences, and today's food log
  /// into the system prompt so the assistant can actually answer
  /// questions like "how many calories do I have left today" instead
  /// of only explaining app features in the abstract. Falls back to
  /// general-app-help-only (empty context block) if this fetch fails
  /// for any reason — the chatbot should degrade gracefully, not go
  /// completely unusable because one Supabase call had a hiccup.
  Future<String> _buildSystemPrompt() async {
    final userId = _supabase.auth.currentUser?.id;
    String contextBlock = '';

    if (userId != null) {
      try {
        final goals = await _supabase
            .from('goals')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        final prefs = await _supabase
            .from('user_preferences')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        final startOfDay = DayBoundary.startOfLocalDay();
        final endOfDay = DayBoundary.endOfLocalDay();
        final todayLogs = await _supabase
            .from('food_logs')
            .select('food_name, calories, meal_type')
            .eq('user_id', userId)
            .gte('logged_at', startOfDay.toIso8601String())
            .lt('logged_at', endOfDay.toIso8601String());

        final logRows = List<Map<String, dynamic>>.from(todayLogs);
        final loggedFoods = logRows
            .map((l) => '${l['food_name']} (${l['meal_type']}, '
            '${l['calories']} kcal)')
            .join(', ');
        final caloriesSoFar = logRows.fold<double>(
            0, (sum, l) => sum + ((l['calories'] ?? 0) as num).toDouble());

        final allergies = (prefs?['allergies'] as List?)?.join(', ');

        contextBlock = '''

The person's current Eatsy data — use this to personalize answers, but
never invent numbers that aren't given here:
- Daily calorie goal: ${goals?['daily_calories'] ?? 'not set yet'} kcal
- Macro goals: ${goals?['protein_goal'] ?? '?'}g protein, ${goals?['carbs_goal'] ?? '?'}g carbs, ${goals?['fat_goal'] ?? '?'}g fat
- Weight goal: ${goals?['weight_goal'] ?? 'not set'}
- Diet type: ${prefs?['diet_type'] ?? 'no restriction set'}
- Allergies: ${(allergies == null || allergies.isEmpty) ? 'none listed' : allergies}
- Logged today so far (${caloriesSoFar.toInt()} kcal total): ${loggedFoods.isEmpty ? 'nothing logged yet today' : loggedFoods}
''';
      } catch (e) {
        debugPrint('Chatbot context fetch error: $e');
      }
    }

    return '''
You are Eatsy's in-app assistant. Eatsy is a nutrition and food-tracking
app with these features: food logging (search, barcode scan), AI-generated
meal plans with per-meal swapping, calorie/macro goal tracking, water
tracking, weight tracking, diet preferences (cuisine, allergies, diet
type), and optional Health Connect/HealthKit sync (steps, active
calories, heart rate, sleep, weight).

Answer questions about how to use the app, and about the person's own
data below when it's relevant to what they're asking. Keep answers
short and conversational — 2 to 4 sentences unless the question
genuinely needs more. You are not a doctor or dietitian: if asked for
medical advice, gently suggest they talk to a real professional instead
of guessing.
$contextBlock''';
  }
}

final chatbotControllerProvider =
StateNotifierProvider<ChatbotController, ChatState>(
        (ref) => ChatbotController());