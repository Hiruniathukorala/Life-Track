import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _isWeekly = true;
  final _db = FirestoreService();
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Mood scoring ──────────────────────────────────────────────────────────
  static const _positiveLabels = {
    'Happy', 'Calm', 'Excited', 'Focused', 'Motivated', 'Energetic', 'Grateful'
  };
  static const _neutralLabels = {'Okay'};

  double _moodScore(String label) {
    if (_positiveLabels.contains(label)) return 1.0;
    if (_neutralLabels.contains(label)) return 0.5;
    return 0.0;
  }

  Color _moodColor(String label) {
    const map = {
      'Happy':     Color(0xFFFFA726),
      'Calm':      Color(0xFF26A69A),
      'Excited':   Color(0xFFEC407A),
      'Focused':   Color(0xFF6C63FF),
      'Motivated': Color(0xFF66BB6A),
      'Energetic': Color(0xFF29B6F6),
      'Grateful':  Color(0xFFAB47BC),
      'Okay':      Color(0xFF78909C),
      'Tired':     Color(0xFF8D6E63),
      'Sad':       Color(0xFF42A5F5),
      'Stressed':  Color(0xFFEF5350),
      'Anxious':   Color(0xFFFF7043),
    };
    return map[label] ?? const Color(0xFF6C63FF);
  }

  String _emoji(String label) {
    const map = {
      'Happy': '😊', 'Calm': '😌', 'Excited': '🤩', 'Focused': '🧘',
      'Motivated': '💪', 'Energetic': '⚡', 'Grateful': '🙏',
      'Okay': '😐', 'Tired': '😴', 'Sad': '😔', 'Stressed': '😤', 'Anxious': '😰',
    };
    return map[label] ?? '😐';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns last 7 dates as strings (oldest → newest).
  List<String> _last7Dates() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });
  }

  String _dayInitial(String dateStr) {
    final d = DateTime.parse(dateStr);
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[d.weekday - 1];
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Insights', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle
            Center(child: _buildToggle()),
            const SizedBox(height: 28),

            // Weekly / Monthly content
            _isWeekly ? _buildWeeklyContent() : _buildMonthlyContent(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleItem('Weekly', _isWeekly),
          _toggleItem('Monthly', !_isWeekly),
        ],
      ),
    );
  }

  Widget _toggleItem(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _isWeekly = label == 'Weekly'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.white60,
                fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  // ── Weekly ────────────────────────────────────────────────────────────────

  Widget _buildWeeklyContent() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.weeklyMoodsStream(_uid),
      builder: (context, snap) {
        final moods = snap.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Weekly summary card ─────────────────────────────────────
            _buildWeeklySummaryCard(moods),
            const SizedBox(height: 24),

            // ── Daily mood bar chart ────────────────────────────────────
            _buildSectionHeader('Mood Score', 'Past 7 Days'),
            const SizedBox(height: 14),
            _buildMoodBarChart(moods),
            const SizedBox(height: 28),

            // ── Mood distribution ───────────────────────────────────────
            if (moods.isNotEmpty) ...[
              _buildSectionHeader('Mood Distribution', 'This Week'),
              const SizedBox(height: 14),
              _buildMoodDistribution(moods),
              const SizedBox(height: 28),
            ],

            // ── Activity category breakdown ─────────────────────────────
            _buildSectionHeader('Activity Breakdown', 'All Time'),
            const SizedBox(height: 14),
            _buildCategoryBreakdown(),
          ],
        );
      },
    );
  }

  // ── Weekly summary card ───────────────────────────────────────────────────

  Widget _buildWeeklySummaryCard(List<Map<String, dynamic>> moods) {
    if (moods.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(children: [
          const Text('🌟', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text('No mood data yet',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
              'Open the app each day to let AI detect your mood.\nYour weekly analysis will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ]),
      );
    }

    // Find dominant mood
    final counts = <String, int>{};
    double totalScore = 0;
    for (final m in moods) {
      final label = m['label'] as String? ?? 'Okay';
      counts[label] = (counts[label] ?? 0) + 1;
      totalScore += _moodScore(label);
    }
    final dominant = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final positivity = (totalScore / moods.length * 100).round();
    final color = _moodColor(dominant.key);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_emoji(dominant.key), style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your Week in Mood',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Text('Mostly ${dominant.key}',
                  style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          _summaryPill('$positivity%', 'Positivity', Colors.greenAccent),
          const SizedBox(width: 10),
          _summaryPill('${moods.length}', 'Check-ins', Colors.blueAccent),
          const SizedBox(width: 10),
          _summaryPill('${counts.length}', 'Moods', Colors.purpleAccent),
        ]),
      ]),
    );
  }

  Widget _summaryPill(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      ),
    );
  }

  // ── Daily mood bar chart ──────────────────────────────────────────────────

  Widget _buildMoodBarChart(List<Map<String, dynamic>> moods) {
    final dates = _last7Dates();

    // Group by date
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final m in moods) {
      final date = m['date'] as String? ?? '';
      (byDate[date] ??= []).add(m);
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: dates.map((date) {
          final dayMoods = byDate[date] ?? [];
          double score = 0;
          Color barColor = Colors.white12;
          String topEmoji = '';

          if (dayMoods.isNotEmpty) {
            score = dayMoods
                    .map((m) => _moodScore(m['label'] as String? ?? 'Okay'))
                    .reduce((a, b) => a + b) /
                dayMoods.length;
            // Dominant mood of the day
            final dc = <String, int>{};
            for (final m in dayMoods) {
              final l = m['label'] as String? ?? 'Okay';
              dc[l] = (dc[l] ?? 0) + 1;
            }
            final dom = dc.entries.reduce((a, b) => a.value > b.value ? a : b);
            barColor = _moodColor(dom.key);
            topEmoji = _emoji(dom.key);
          }

          return _dayBar(
            day: _dayInitial(date),
            score: score,
            color: barColor,
            emoji: topEmoji,
            count: dayMoods.length,
          );
        }).toList(),
      ),
    );
  }

  Widget _dayBar({
    required String day,
    required double score,
    required Color color,
    required String emoji,
    required int count,
  }) {
    final hasData = count > 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasData)
          Text(emoji, style: const TextStyle(fontSize: 13))
        else
          const SizedBox(height: 18),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            width: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FractionallySizedBox(
              heightFactor: hasData ? score.clamp(0.08, 1.0) : 0.04,
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: hasData ? color : Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: hasData
                      ? [
                          BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                      : [],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(day,
            style: TextStyle(
                color: hasData ? Colors.white60 : Colors.white24,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ── Mood distribution ─────────────────────────────────────────────────────

  Widget _buildMoodDistribution(List<Map<String, dynamic>> moods) {
    final counts = <String, int>{};
    for (final m in moods) {
      final label = m['label'] as String? ?? 'Okay';
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = moods.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: sorted.map((e) {
          final pct = e.value / total;
          final color = _moodColor(e.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Text(_emoji(e.key), style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${e.value}x · ${(pct * 100).round()}%',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ]),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ]),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Activity category breakdown ───────────────────────────────────────────

  Widget _buildCategoryBreakdown() {
    return StreamBuilder<Map<String, int>>(
      stream: _db.categoryStatsStream(_uid),
      builder: (context, snap) {
        final stats = snap.data ?? {};

        if (stats.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text('No activities logged yet.',
                  style: TextStyle(color: Colors.white38)),
            ),
          );
        }

        final total = stats.values.fold(0, (a, b) => a + b);
        final sorted = stats.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        const catColors = {
          'Habits':      Color(0xFF6C63FF),
          'Fitness':     Color(0xFF29B6F6),
          'Moods':       Color(0xFFFFA726),
          'Daily Plans': Color(0xFF66BB6A),
          'Other':       Color(0xFF78909C),
        };

        return Column(
          children: sorted.map((e) {
            final color = catColors[e.key] ?? const Color(0xFF6C63FF);
            final pct = total > 0 ? e.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(e.key,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text('${e.value} · ${(pct * 100).round()}%',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ]),
            );
          }).toList(),
        );
      },
    );
  }

  // ── Monthly ───────────────────────────────────────────────────────────────

  Widget _buildMonthlyContent() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _db.userProfileStream(_uid),
      builder: (context, snap) {
        final profile = snap.data ?? {};
        final totalPoints = profile['totalPoints'] as int? ?? 0;
        final streak = profile['currentStreak'] as int? ?? 0;
        const pointsPerLevel = 500;
        final level = totalPoints ~/ pointsPerLevel + 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Monthly Overview', _monthLabel()),
            const SizedBox(height: 14),

            // Stats row
            Row(children: [
              _monthStatCard('🏆', 'Level', '$level', Colors.amber),
              const SizedBox(width: 10),
              _monthStatCard('⭐', 'Total XP', '$totalPoints', Colors.purple),
              const SizedBox(width: 10),
              _monthStatCard('🔥', 'Streak', '${streak}d', Colors.deepOrange),
            ]),
            const SizedBox(height: 24),

            // XP progress
            _buildSectionHeader('XP Progress', 'Level $level → ${level + 1}'),
            const SizedBox(height: 14),
            _buildXpBar(totalPoints),
            const SizedBox(height: 28),

            // Monthly mood summary
            _buildSectionHeader('Mood History', 'Last 7 Days'),
            const SizedBox(height: 14),
            _buildMonthlyMoodSummary(),
            const SizedBox(height: 28),

            // Category breakdown (same as weekly)
            _buildSectionHeader('Activity Breakdown', 'All Time'),
            const SizedBox(height: 14),
            _buildCategoryBreakdown(),
          ],
        );
      },
    );
  }

  Widget _monthStatCard(
      String emoji, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _buildXpBar(int totalPoints) {
    const ppl = 500;
    final inLevel = totalPoints % ppl;
    final progress = inLevel / ppl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$inLevel / $ppl XP',
              style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          Text('${(progress * 100).round()}% to next level',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
          ),
        ),
      ]),
    );
  }

  Widget _buildMonthlyMoodSummary() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.weeklyMoodsStream(_uid),
      builder: (context, snap) {
        final moods = snap.data ?? [];
        if (moods.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text('No mood data yet — open the app daily!',
                  style: TextStyle(color: Colors.white38)),
            ),
          );
        }
        return _buildMoodDistribution(moods);
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.white38)),
      ],
    );
  }

  String _monthLabel() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }
}
