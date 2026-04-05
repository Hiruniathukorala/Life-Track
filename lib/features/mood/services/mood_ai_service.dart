import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/mood_result.dart';
import '../../../core/config/ai_config.dart';

// ── User context passed to the detection engine ─────────────────────────────

class UserContext {
  final String? name;
  final int? age;
  final String? gender;
  final String? profession;
  final String? healthConditions;
  final int currentStreak;
  final int dailyPoints;
  final int habitsCompleted;
  final int totalHabits;
  final String? previousMoodLabel;
  final String? userText; // optional freeform text from the user

  const UserContext({
    this.name,
    this.age,
    this.gender,
    this.profession,
    this.healthConditions,
    required this.currentStreak,
    required this.dailyPoints,
    required this.habitsCompleted,
    required this.totalHabits,
    this.previousMoodLabel,
    this.userText,
  });

  UserContext copyWith({String? userText}) => UserContext(
        name: name,
        age: age,
        gender: gender,
        profession: profession,
        healthConditions: healthConditions,
        currentStreak: currentStreak,
        dailyPoints: dailyPoints,
        habitsCompleted: habitsCompleted,
        totalHabits: totalHabits,
        previousMoodLabel: previousMoodLabel,
        userText: userText ?? this.userText,
      );
}

// ── AI mood detection engine ────────────────────────────────────────────────

class MoodAiService {
  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  /// Detect mood from [ctx].
  /// Tries Gemini first; falls back to built-in heuristics if unavailable.
  Future<MoodResult> detectMood(UserContext ctx) async {
    if (AiConfig.isConfigured) {
      try {
        final result = await _callGemini(ctx);
        if (result != null) return result;
      } catch (e) {
        debugPrint('[MoodAI] Gemini failed: $e — using local analysis');
      }
    }
    return _analyzeLocally(ctx);
  }

  // ── Gemini API ──────────────────────────────────────────────────────────────

  Future<MoodResult?> _callGemini(UserContext ctx) async {
    final now = DateTime.now();
    final period   = _timePeriod(now.hour);
    final dayName  = _dayName(now.weekday);
    final habitPct = ctx.totalHabits > 0
        ? '${((ctx.habitsCompleted / ctx.totalHabits) * 100).round()}%'
        : 'N/A';
    final firstName = (ctx.name ?? '').split(' ').first;

    // Build optional profile lines
    final profileLines = [
      if ((ctx.name ?? '').isNotEmpty)          '- Name: ${ctx.name}',
      if ((ctx.age ?? 0) > 0)                   '- Age: ${ctx.age}',
      if ((ctx.gender ?? '').isNotEmpty)         '- Gender: ${ctx.gender}',
      if ((ctx.profession ?? '').isNotEmpty)     '- Profession: ${ctx.profession}',
      if ((ctx.healthConditions ?? '').isNotEmpty &&
          ctx.healthConditions != 'None')        '- Health notes: ${ctx.healthConditions}',
    ].join('\n');

    final prevLine = (ctx.previousMoodLabel != null)
        ? '\n- Previous mood: ${ctx.previousMoodLabel}'
        : '';
    final textLine = (ctx.userText ?? '').trim().isNotEmpty
        ? '\n- User says: "${ctx.userText!.trim()}"'
        : '';

    final prompt = '''
You are a compassionate AI mood coach inside LifeTrack, a personal wellness app.

Analyse the user's real-time context and determine their current emotional state with empathy and precision.

USER PROFILE:
${profileLines.isNotEmpty ? profileLines : '(profile not set)'}

TODAY'S CONTEXT:
- Time: ${now.hour}:${now.minute.toString().padLeft(2, '0')} ($period)
- Day: $dayName
- Active-day streak: ${ctx.currentStreak} day${ctx.currentStreak == 1 ? '' : 's'}
- XP earned today: ${ctx.dailyPoints} pts
- Habits completed: ${ctx.habitsCompleted} / ${ctx.totalHabits} ($habitPct)$prevLine$textLine

RULES:
1. Choose EXACTLY ONE mood label from: Happy, Calm, Excited, Focused, Motivated, Energetic, Grateful, Okay, Tired, Sad, Stressed, Anxious
2. confidence: float 0.0–1.0 reflecting certainty
3. description: 1–2 warm sentences. Reference actual numbers (streak, habits, time). Address user as "${firstName.isNotEmpty ? firstName : 'friend'}".
4. suggestions: EXACTLY 3 short, actionable self-care or productivity tips personalised to their mood and context. Each tip under 10 words.
5. Reply ONLY with valid JSON — no markdown, no prose outside the JSON block.

EXAMPLE OUTPUT:
{
  "mood": "Motivated",
  "confidence": 0.87,
  "description": "Your 7-day streak is inspiring, ${firstName.isNotEmpty ? firstName : 'friend'}! $dayName morning energy is at its peak.",
  "suggestions": [
    "Write your top 3 goals for today",
    "Do a 10-min workout to lock in momentum",
    "Share your streak win with someone you trust"
  ]
}
''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [{'text': prompt}]
        }
      ],
      'generationConfig': {
        'temperature': 0.45,
        'maxOutputTokens': 350,
      },
    });

    final uri = Uri.parse('$_geminiUrl?key=${AiConfig.geminiApiKey}');
    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      debugPrint('[MoodAI] HTTP ${response.statusCode}: ${response.body}');
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
    if (rawText == null) return null;

    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawText);
    if (jsonMatch == null) return null;

    final parsed    = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    final label     = parsed['mood'] as String? ?? 'Okay';
    final conf      = (parsed['confidence'] as num?)?.toDouble() ?? 0.75;
    final desc      = parsed['description'] as String? ?? '';
    final rawSugg   = parsed['suggestions'] as List?;
    final sugg      = rawSugg?.map((e) => e.toString()).toList() ?? [];

    return MoodResult.fromLabel(
      label,
      description: desc,
      confidence: conf,
      detectedFrom: 'ai_gemini',
      suggestions: sugg,
    );
  }

  // ── Built-in heuristic analysis ─────────────────────────────────────────────

  MoodResult _analyzeLocally(UserContext ctx) {
    final scores = <String, double>{
      'Happy': 0, 'Calm': 0, 'Excited': 0, 'Focused': 0,
      'Motivated': 0, 'Energetic': 0, 'Grateful': 0,
      'Okay': 1, // baseline
      'Tired': 0, 'Sad': 0, 'Stressed': 0, 'Anxious': 0,
    };

    final hour       = DateTime.now().hour;
    final habitRate  = ctx.totalHabits > 0
        ? ctx.habitsCompleted / ctx.totalHabits
        : 0.0;

    // ── Time of day (reduced weight when user supplies text) ─────────────────
    final double timeWeight = (ctx.userText ?? '').trim().isNotEmpty ? 0.5 : 1.0;
    if (hour >= 5 && hour < 9) {
      scores['Calm']      = scores['Calm']!      + 1.5 * timeWeight;
      scores['Focused']   = scores['Focused']!   + 1.0 * timeWeight;
    } else if (hour >= 9 && hour < 12) {
      scores['Energetic'] = scores['Energetic']! + 1.5 * timeWeight;
      scores['Motivated'] = scores['Motivated']! + 1.2 * timeWeight;
    } else if (hour >= 12 && hour < 15) {
      scores['Focused']   = scores['Focused']!   + 1.5 * timeWeight;
      scores['Okay']      = scores['Okay']!      + 0.5 * timeWeight;
    } else if (hour >= 15 && hour < 18) {
      scores['Okay']      = scores['Okay']!      + 1.0 * timeWeight;
      scores['Tired']     = scores['Tired']!     + 0.8 * timeWeight;
    } else if (hour >= 18 && hour < 21) {
      scores['Calm']      = scores['Calm']!      + 1.5 * timeWeight;
      scores['Grateful']  = scores['Grateful']!  + 0.8 * timeWeight;
    } else {
      scores['Tired']     = scores['Tired']!     + 2.0 * timeWeight;
      scores['Calm']      = scores['Calm']!      + 0.5 * timeWeight;
    }

    // ── Streak ───────────────────────────────────────────────────────────────
    if (ctx.currentStreak >= 21) {
      scores['Excited']   = scores['Excited']!   + 3.0;
      scores['Motivated'] = scores['Motivated']! + 2.0;
    } else if (ctx.currentStreak >= 14) {
      scores['Motivated'] = scores['Motivated']! + 3.0;
      scores['Excited']   = scores['Excited']!   + 1.5;
    } else if (ctx.currentStreak >= 7) {
      scores['Motivated'] = scores['Motivated']! + 2.0;
      scores['Happy']     = scores['Happy']!     + 1.0;
    } else if (ctx.currentStreak >= 3) {
      scores['Motivated'] = scores['Motivated']! + 1.0;
    } else if (ctx.currentStreak == 0) {
      scores['Sad']       = scores['Sad']!       + 0.8;
      scores['Stressed']  = scores['Stressed']!  + 0.5;
    }

    // ── Habits ───────────────────────────────────────────────────────────────
    if (habitRate >= 1.0) {
      scores['Happy']     = scores['Happy']!     + 2.5;
      scores['Excited']   = scores['Excited']!   + 1.0;
    } else if (habitRate >= 0.75) {
      scores['Happy']     = scores['Happy']!     + 1.5;
      scores['Motivated'] = scores['Motivated']! + 1.0;
    } else if (habitRate >= 0.5) {
      scores['Focused']   = scores['Focused']!   + 1.0;
    } else if (habitRate > 0) {
      scores['Okay']      = scores['Okay']!      + 0.8;
    } else if (hour >= 18 && habitRate == 0.0) {
      scores['Stressed']  = scores['Stressed']!  + 0.8;
      scores['Tired']     = scores['Tired']!     + 0.5;
    }

    // ── XP / points ──────────────────────────────────────────────────────────
    if (ctx.dailyPoints >= 200) {
      scores['Energetic'] = scores['Energetic']! + 1.5;
      scores['Happy']     = scores['Happy']!     + 1.0;
    } else if (ctx.dailyPoints >= 100) {
      scores['Motivated'] = scores['Motivated']! + 1.0;
    } else if (ctx.dailyPoints == 0 && hour >= 14) {
      scores['Tired']     = scores['Tired']!     + 0.5;
    }

    // ── Previous mood continuity ─────────────────────────────────────────────
    if (ctx.previousMoodLabel != null) {
      final prev = ctx.previousMoodLabel!;
      // Slight inertia — previous negative moods dampen positive peaks
      if ({'Sad', 'Stressed', 'Anxious', 'Tired'}.contains(prev)) {
        scores['Stressed'] = scores['Stressed']! + 0.4;
        scores['Tired']    = scores['Tired']!    + 0.3;
      }
    }

    // ── Text sentiment ───────────────────────────────────────────────────────
    if ((ctx.userText ?? '').trim().isNotEmpty) {
      final textScores = _analyzeText(ctx.userText!.toLowerCase());
      for (final e in textScores.entries) {
        scores[e.key] = (scores[e.key] ?? 0) + e.value * 3.0;
      }
    }

    // ── Profession-specific signal ───────────────────────────────────────────
    final prof = (ctx.profession ?? '').toLowerCase();
    if (prof.contains('student') || prof.contains('study')) {
      scores['Stressed'] = scores['Stressed']! + 0.3;
      scores['Focused']  = scores['Focused']!  + 0.3;
    } else if (prof.contains('doctor') || prof.contains('nurse') ||
               prof.contains('health')) {
      scores['Tired']    = scores['Tired']!    + 0.4;
    }

    // ── Winner ───────────────────────────────────────────────────────────────
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final winner = sorted.first;
    final total  = scores.values.fold(0.0, (a, b) => a + b);
    final conf   = total > 0
        ? (winner.value / total).clamp(0.42, 0.94)
        : 0.5;

    final label  = winner.key;
    final desc   = _buildDescription(label, ctx, hour);
    final sugg   = _buildSuggestions(label, ctx, hour);

    return MoodResult.fromLabel(
      label,
      description: desc,
      confidence: conf,
      detectedFrom: 'ai_context',
      suggestions: sugg,
    );
  }

  // ── Description builder ─────────────────────────────────────────────────────

  String _buildDescription(String mood, UserContext ctx, int hour) {
    final period = _timePeriod(hour);
    final name   = (ctx.name ?? '').split(' ').first;
    final hi     = name.isNotEmpty ? '$name' : 'you';

    final streakPart = ctx.currentStreak > 1
        ? 'Your ${ctx.currentStreak}-day streak shows real consistency!'
        : ctx.currentStreak == 1
            ? 'Day one of your new streak — great start!'
            : 'Today is a fresh start — let\'s build that streak.';

    final habitPart = ctx.habitsCompleted == ctx.totalHabits && ctx.totalHabits > 0
        ? 'All ${ctx.totalHabits} habits done today — impressive!'
        : ctx.habitsCompleted > 0
            ? '${ctx.habitsCompleted} of ${ctx.totalHabits} habits completed.'
            : ctx.totalHabits > 0
                ? 'Habits are still waiting — you\'ve got this!'
                : '';

    switch (mood) {
      case 'Happy':
        return '$hi is radiating positivity this $period! 🌟 $streakPart';
      case 'Calm':
        return 'A calm, grounded energy surrounds $hi this $period. $streakPart';
      case 'Excited':
        return 'High-energy vibes detected! $hi seems thrilled about the day. $streakPart';
      case 'Focused':
        return '$hi is locked in and laser-focused right now. $habitPart';
      case 'Motivated':
        return 'Strong motivation signals detected! $streakPart ${habitPart.isEmpty ? '' : habitPart}';
      case 'Energetic':
        return 'Energy levels are sky-high this $period! $habitPart';
      case 'Grateful':
        return 'Gratitude is a superpower — $hi has got it today. $streakPart';
      case 'Okay':
        return 'Steady and stable — not every day needs to be fireworks. $habitPart';
      case 'Tired':
        return 'Low energy detected this $period. Even rest days count. $streakPart';
      case 'Sad':
        return 'It\'s okay not to feel okay. $streakPart Every small step matters.';
      case 'Stressed':
        return 'Noticing some pressure signals. $habitPart Take one thing at a time.';
      case 'Anxious':
        return 'Some tension detected — totally normal. $streakPart You\'re doing better than you think.';
      default:
        return 'Mood detected from your activity patterns.';
    }
  }

  // ── Suggestion builder ──────────────────────────────────────────────────────

  List<String> _buildSuggestions(String mood, UserContext ctx, int hour) {
    final period = _timePeriod(hour);

    // Mood-specific base tips
    final base = <String, List<String>>{
      'Happy': [
        'Share your good mood with someone you love',
        'Write down what made you happy today',
        'Set a bold goal while energy is high',
      ],
      'Calm': [
        'Use this calm to plan your next week',
        'Try a 5-minute journaling session',
        'Enjoy a slow, mindful cup of tea or water',
      ],
      'Excited': [
        'Channel excitement into your top priority task',
        'Start that project you\'ve been postponing',
        'Celebrate a recent win with someone close',
      ],
      'Focused': [
        'Block distractions for the next 30 minutes',
        'Tackle your hardest task first',
        'Review your daily goals and adjust if needed',
      ],
      'Motivated': [
        'Write your top 3 goals for today',
        'Do a 10-minute workout to lock in energy',
        'Keep your streak alive — log one habit now',
      ],
      'Energetic': [
        'Go for a brisk walk or quick workout',
        'Tackle a task you\'ve been avoiding',
        'Use this energy to help someone else today',
      ],
      'Grateful': [
        'Write 3 things you\'re thankful for today',
        'Send a kind message to someone who helped you',
        'Reflect on how far you\'ve come this month',
      ],
      'Okay': [
        'Do one small thing that usually lifts your mood',
        'Take a 5-minute break and step outside',
        'Check off one habit to build momentum',
      ],
      'Tired': [
        'Take a short 10-minute power nap if you can',
        'Drink a glass of water — dehydration drains energy',
        'Do light stretching to wake your body up',
      ],
      'Sad': [
        'Reach out to someone you trust right now',
        'Go outside for even 5 minutes of fresh air',
        'Be kind to yourself — rest is productive too',
      ],
      'Stressed': [
        'Write down every worry — then pick just one to solve',
        'Take 5 slow deep breaths right now',
        'Break your to-do list into smaller steps',
      ],
      'Anxious': [
        'Breathe in for 4 counts, hold 4, out for 6',
        'Ground yourself: name 5 things you can see',
        'Focus only on what you can control today',
      ],
    };

    final tips = List<String>.from(base[mood] ?? base['Okay']!);

    // Contextual override: if habits not done by evening, add reminder
    if (hour >= 17 && ctx.habitsCompleted < ctx.totalHabits) {
      tips[2] = 'Log your remaining ${ctx.totalHabits - ctx.habitsCompleted} habit(s) before bed';
    }

    // Streak-specific tip override
    if (ctx.currentStreak == 0) {
      tips[1] = 'Start fresh — log one small activity to restart your streak';
    } else if (ctx.currentStreak >= 7 && period == 'evening') {
      tips[0] = 'Amazing ${ctx.currentStreak}-day streak! Don\'t break it tonight';
    }

    return tips.take(3).toList();
  }

  // ── Keyword sentiment map ───────────────────────────────────────────────────

  static const _keywords = <String, Map<String, double>>{
    'Happy':     {'happy': 3, 'great': 2, 'good': 1.5, 'wonderful': 3, 'amazing': 3, 'fantastic': 3, 'joy': 2.5, 'love': 2, 'smile': 2, 'fun': 2, 'laugh': 2, 'cheerful': 3, 'awesome': 2.5},
    'Calm':      {'calm': 3, 'peaceful': 3, 'relax': 2.5, 'chill': 2, 'zen': 3, 'serene': 3, 'quiet': 2, 'still': 1.5, 'easy': 1.5, 'gentle': 2, 'steady': 1.5, 'tranquil': 3},
    'Excited':   {'excited': 3, 'thrilled': 3, 'pumped': 2.5, 'ecstatic': 3, 'amazing': 2, 'wow': 2, 'incredible': 2.5, 'fire': 2, 'hype': 2},
    'Focused':   {'focused': 3, 'concentrate': 2.5, 'productive': 2.5, 'working': 1.5, 'zone': 2, 'flow': 2.5, 'clear': 2, 'sharp': 2, 'determined': 2, 'deep work': 3},
    'Motivated': {'motivated': 3, 'driven': 2.5, 'inspired': 2.5, 'ready': 2, 'push': 2, 'goal': 2, 'achieve': 2.5, 'hustle': 2, 'let\'s go': 2.5, 'strong': 2},
    'Energetic': {'energy': 3, 'energetic': 3, 'active': 2.5, 'alive': 2.5, 'awake': 2, 'fresh': 2, 'vibrant': 2.5, 'bouncing': 2},
    'Grateful':  {'grateful': 3, 'thankful': 3, 'appreciate': 2.5, 'blessed': 2.5, 'fortunate': 2, 'lucky': 1.5, 'thank': 2, 'gratitude': 3},
    'Tired':     {'tired': 3, 'exhausted': 3, 'sleepy': 2.5, 'fatigue': 2.5, 'drained': 3, 'worn': 2, 'weak': 1.5, 'nap': 2, 'sleep': 2, 'heavy': 1.5, 'sluggish': 2.5, 'groggy': 2},
    'Sad':       {'sad': 3, 'down': 2, 'blue': 2, 'unhappy': 3, 'depressed': 3, 'cry': 2.5, 'upset': 2, 'miss': 1.5, 'lonely': 2.5, 'empty': 2, 'hopeless': 3, 'disappointed': 2},
    'Stressed':  {'stress': 3, 'stressed': 3, 'overwhelm': 3, 'pressure': 2.5, 'too much': 2.5, 'deadline': 2, 'behind': 2, 'panic': 2.5, 'chaos': 2},
    'Anxious':   {'anxious': 3, 'anxiety': 3, 'worry': 2.5, 'worried': 2.5, 'nervous': 2.5, 'fear': 2, 'scared': 2, 'dread': 2.5, 'uncertain': 2, 'tense': 2},
  };

  Map<String, double> _analyzeText(String text) {
    final result = <String, double>{};
    for (final mood in _keywords.entries) {
      double score = 0;
      for (final kw in mood.value.entries) {
        if (text.contains(kw.key)) score += kw.value;
      }
      if (score > 0) result[mood.key] = score;
    }
    return result;
  }

  // ── Utility ──────────────────────────────────────────────────────────────────

  String _timePeriod(int hour) {
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  String _dayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[(weekday - 1).clamp(0, 6)];
  }
}
