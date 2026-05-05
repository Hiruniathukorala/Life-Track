import 'package:flutter/material.dart';
import '../../../core/services/firestore_service.dart';

class FamilyMemberDetailScreen extends StatelessWidget {
  final String linkedUid;
  final String role;

  const FamilyMemberDetailScreen({
    super.key,
    required this.linkedUid,
    required this.role,
  });

  static const List<String> _defaultHabits = [
    'Morning Hydration', 'Review Goals', '30m Reading', 'Evening Reflection'
  ];

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final db = FirestoreService();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: db.linkedUserProfileStream(linkedUid),
      builder: (context, profileSnap) {
        final profile = profileSnap.data ?? {};
        final name         = profile['name']          as String? ?? '...';
        final totalPoints  = profile['totalPoints']   as int?    ?? 0;
        final dailyPoints  = profile['dailyPoints']   as int?    ?? 0;
        final streak       = profile['currentStreak'] as int?    ?? 0;
        final initial      = name.isNotEmpty ? name[0].toUpperCase() : '?';
        final color        = _colorFor(linkedUid);

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: CustomScrollView(
            slivers: [
              // ── Hero App Bar ──────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: color.withOpacity(0.9),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.withOpacity(0.8), const Color(0xFF0F0F0F)],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: color.withOpacity(0.25),
                          child: Text(initial,
                              style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: color)),
                        ),
                        const SizedBox(height: 12),
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withOpacity(0.4)),
                          ),
                          child: Text(role,
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Stats Grid ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stats',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(children: [
                        _statCard(context, '⭐', 'Total XP',
                            '$totalPoints pts', Colors.amber),
                        const SizedBox(width: 10),
                        _statCard(context, '🔥', 'Streak',
                            '${streak}d', Colors.deepOrange),
                        const SizedBox(width: 10),
                        _statCard(context, '⚡', 'Today',
                            '$dailyPoints pts', Colors.greenAccent),
                      ]),
                      const SizedBox(height: 10),
                      // XP progress toward next level (every 500 pts = 1 level)
                      _buildXpProgress(context, totalPoints, color),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Recent Activity ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recent Activity',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: db.logsStream(linkedUid),
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: CircularProgressIndicator()));
                          }
                          if (snap.hasError || (snap.data == null)) {
                            return _permissionBanner(
                                'Activity logs are private.\nAsk your admin to grant family read access.');
                          }
                          final logs = snap.data!;
                          if (logs.isEmpty) {
                            return _emptyBanner('No activities logged yet.');
                          }
                          return Column(
                            children: logs.take(5).map((log) =>
                                _activityRow(log, color)).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Today's Habits ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Today's Habits",
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: db.habitsForDateStream(linkedUid, _today),
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator()));
                          }
                          if (snap.hasError || snap.data == null) {
                            return _permissionBanner(
                                'Habits are private.\nAsk your admin to grant family read access.');
                          }
                          final completed = {
                            for (final h in snap.data!)
                              if (h['completed'] == true) h['habit'] as String
                          };
                          return Column(
                            children: _defaultHabits.map((habit) {
                              final done = completed.contains(habit);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: done
                                      ? color.withOpacity(0.08)
                                      : Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: done
                                          ? color.withOpacity(0.3)
                                          : Colors.white12),
                                ),
                                child: Row(children: [
                                  Icon(
                                    done
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: done ? color : Colors.white24,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(habit,
                                      style: TextStyle(
                                          color: done
                                              ? Colors.white70
                                              : Colors.white38,
                                          fontSize: 14,
                                          decoration: done
                                              ? TextDecoration.lineThrough
                                              : null)),
                                  const Spacer(),
                                  if (done)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('+20 XP',
                                          style: TextStyle(
                                              color: color,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                ]),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _colorFor(String uid) {
    const colors = [
      Color(0xFF6C63FF), Color(0xFFEC407A), Color(0xFF29B6F6),
      Color(0xFF26A69A), Color(0xFFFFA726), Color(0xFF66BB6A),
    ];
    final idx = uid.codeUnits.fold(0, (a, b) => a + b) % colors.length;
    return colors[idx];
  }

  Widget _statCard(BuildContext context, String emoji, String label,
      String value, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: accent,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildXpProgress(
      BuildContext context, int totalPoints, Color color) {
    const pointsPerLevel = 500;
    final level  = totalPoints ~/ pointsPerLevel + 1;
    final inLevel = totalPoints % pointsPerLevel;
    final progress = (inLevel / pointsPerLevel).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Level $level',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          Text('$inLevel / $pointsPerLevel XP to Level ${level + 1}',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ]),
    );
  }

  Widget _activityRow(Map<String, dynamic> log, Color accent) {
    final logColor = Color(log['color'] as int? ?? 0xFF6C63FF);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: logColor.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, color: logColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(log['activity'] as String? ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            if ((log['mood'] ?? '').toString().isNotEmpty)
              Text(log['mood'] as String,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45), fontSize: 12)),
          ]),
        ),
        Text(log['time'] as String? ?? '',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _permissionBanner(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(children: [
          const Icon(Icons.lock_outline_rounded,
              color: Colors.white24, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(color: Colors.white24, fontSize: 13))),
        ]),
      );

  Widget _emptyBanner(String msg) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
            child:
                Text(msg, style: const TextStyle(color: Colors.white24))),
      );
}
