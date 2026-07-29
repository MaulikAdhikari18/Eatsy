import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/receipt_decorations.dart';

class _FaqEntry {
  final String question;
  final String answer;
  const _FaqEntry(this.question, this.answer);
}

/// Static FAQ — deliberately NOT the chatbot. This is free and instant
/// (no Groq call, no latency), and covers exactly the kind of "how do
/// I do X" questions that don't need an AI to answer well. The chatbot
/// (see lib/features/chatbot/) is for open-ended questions and
/// anything involving the person's own data, which this can't do.
const _faqs = [
  _FaqEntry(
    'How do I log a meal?',
    'Three ways: search by name on the Log tab, scan a barcode (Log → '
        'barcode icon), or take a photo with Scan. Search and barcode '
        'both work today; photo recognition is coming in a future update.',
  ),
  _FaqEntry(
    'Why can\'t I find a specific food when I search?',
    'Search checks a few sources in order — a packaged-product '
        'database, then a general food database, then a small built-in '
        'list — so most common foods and branded products should turn '
        'up. Very obscure or hyper-local dishes occasionally won\'t.',
  ),
  _FaqEntry(
    'How are my calorie and macro targets calculated?',
    'From your age, height, weight, gender, and activity level (set '
        'during onboarding, editable anytime in Settings) using a '
        'standard BMR/TDEE formula. You can also just type in your own '
        'numbers directly on the Settings screen if you\'d rather set '
        'them yourself.',
  ),
  _FaqEntry(
    'What are Diet Preferences for?',
    'Cuisine, allergies, and diet type (vegetarian, keto, etc.) — set '
        'these so your AI-generated meal plans actually fit what you '
        'can and want to eat. Skippable during onboarding, editable '
        'anytime from Settings.',
  ),
  _FaqEntry(
    'How does the AI Meal Plan work?',
    'It generates a personalized plan from your goals, macros, and '
        'diet preferences. You can swap out any single meal for a new '
        'AI suggestion without regenerating the whole plan, and export '
        'the full week as a PDF.',
  ),
  _FaqEntry(
    'What does Connect Health Data actually share?',
    'Steps, active calories, heart rate, sleep, and weight — read-only, '
        'entirely optional, and nothing is read until you explicitly '
        'connect it. You can disconnect at any time; see Privacy Policy '
        'for exactly what\'s collected and why.',
  ),
  _FaqEntry(
    'Can I delete my account and data?',
    'Yes — Settings → scroll to Delete Account, or via the drawer\'s '
        'profile menu. This permanently removes every category of data '
        'listed in the Privacy Policy, including your login itself, '
        'immediately and without needing to contact anyone.',
  ),
  _FaqEntry(
    'Can I switch between kg/lb or ml/L?',
    'Yes — unit dropdowns sit right next to the relevant fields '
        '(weight entries on Settings, water total on the Dashboard) '
        'rather than being buried in a separate settings menu.',
  ),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back_ios_new,
                      size: 16, color: colors.textPrimary),
                ),
              ),
              const SizedBox(height: 24),

              BarcodeStrip(color: colors.accent, height: 10),
              const SizedBox(height: 16),

              Text(
                'Help',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Quick answers to common questions. For anything else, '
                    'try the Chatbot.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 24),

              ..._faqs.map((faq) => _FaqTile(entry: faq)),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final _FaqEntry entry;
  const _FaqTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider),
      ),
      child: Theme(
        // Removes the default divider ExpansionTile draws when
        // expanded — this app's own dividers are a deliberate,
        // consistent color (colors.divider), and the default one
        // doesn't respect it.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding:
          const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: colors.accent,
          collapsedIconColor: colors.textMuted,
          title: Text(
            entry.question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.answer,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}