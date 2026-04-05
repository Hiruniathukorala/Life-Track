import 'package:flutter/material.dart';

/// The 12 recognised mood states in LifeTrack.
enum MoodLabel {
  happy, calm, excited, focused, motivated,
  energetic, grateful, okay, tired, sad, stressed, anxious,
}

/// Holds the full result of one AI mood-detection pass.
class MoodResult {
  final String label;         // e.g. "Happy"
  final String emoji;         // e.g. "😊"
  final String description;   // personalised insight (1–2 sentences)
  final Color color;
  final double confidence;    // 0.0 – 1.0
  final String detectedFrom;  // 'ai_gemini' | 'ai_context' | 'user_selected'
  final List<String> suggestions; // 3 personalised action tips

  const MoodResult({
    required this.label,
    required this.emoji,
    required this.description,
    required this.color,
    required this.confidence,
    required this.detectedFrom,
    this.suggestions = const [],
  });

  // ── Static mood palette ─────────────────────────────────────────────────────

  static const Map<String, Map<String, dynamic>> _palette = {
    'Happy':     {'emoji': '😊', 'color': 0xFFFFA726},
    'Calm':      {'emoji': '😌', 'color': 0xFF26A69A},
    'Excited':   {'emoji': '🤩', 'color': 0xFFEC407A},
    'Focused':   {'emoji': '🧘', 'color': 0xFF6C63FF},
    'Motivated': {'emoji': '💪', 'color': 0xFF66BB6A},
    'Energetic': {'emoji': '⚡', 'color': 0xFF29B6F6},
    'Grateful':  {'emoji': '🙏', 'color': 0xFFAB47BC},
    'Okay':      {'emoji': '😐', 'color': 0xFF78909C},
    'Tired':     {'emoji': '😴', 'color': 0xFF8D6E63},
    'Sad':       {'emoji': '😔', 'color': 0xFF42A5F5},
    'Stressed':  {'emoji': '😤', 'color': 0xFFEF5350},
    'Anxious':   {'emoji': '😰', 'color': 0xFFFF7043},
  };

  static List<String> get allLabels => _palette.keys.toList();

  // ── Factories ───────────────────────────────────────────────────────────────

  factory MoodResult.fromLabel(
    String label, {
    String description = '',
    double confidence = 0.7,
    String detectedFrom = 'ai_context',
    List<String> suggestions = const [],
  }) {
    final norm = _normalise(label);
    final data = _palette[norm] ?? _palette['Okay']!;
    return MoodResult(
      label: norm,
      emoji: data['emoji'] as String,
      description: description.isEmpty ? 'Feeling $norm today.' : description,
      color: Color(data['color'] as int),
      confidence: confidence,
      detectedFrom: detectedFrom,
      suggestions: suggestions,
    );
  }

  /// Build from a Firestore map — handles old documents without suggestions.
  factory MoodResult.fromMap(Map<String, dynamic> map) {
    final raw = map['suggestions'];
    final suggestions = raw is List
        ? raw.map((e) => e.toString()).toList()
        : <String>[];
    return MoodResult(
      label: map['label'] as String? ?? 'Okay',
      emoji: map['emoji'] as String? ?? '😐',
      description: map['description'] as String? ?? '',
      color: Color(map['color'] as int? ?? 0xFF78909C),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
      detectedFrom: map['detectedFrom'] as String? ?? 'ai_context',
      suggestions: suggestions,
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'emoji': emoji,
        'description': description,
        'color': color.value,
        'confidence': confidence,
        'detectedFrom': detectedFrom,
        'suggestions': suggestions,
      };

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _normalise(String raw) {
    final lower = raw.trim().toLowerCase();
    for (final key in _palette.keys) {
      if (key.toLowerCase() == lower) return key;
    }
    return 'Okay';
  }

  bool get isPositive => const {
        'Happy', 'Calm', 'Excited', 'Focused',
        'Motivated', 'Energetic', 'Grateful',
      }.contains(label);
}
