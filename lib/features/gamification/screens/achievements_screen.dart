import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirestoreService();
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Badge definitions (icon, label, description, color, unlock check) ──────

  List<_BadgeDef> get _habitDefs => [
        _BadgeDef(Icons.water_drop_rounded, 'Hydration Hero',
            'Log water-related habits 7+ times', const Color(0xFF29B6F6),
            (d) => d.activityCount('Morning Hydration') +
                    d.activityCount('Drinking Water') >=
                7),
        _BadgeDef(Icons.menu_book_rounded, 'Book Worm',
            'Log reading activities 7+ times', const Color(0xFF7E57C2),
            (d) => d.activityCount('30m Reading') >= 7),
        _BadgeDef(Icons.self_improvement_rounded, 'Zen Master',
            'Maintain a 10-day streak', const Color(0xFF26A69A),
            (d) => d.streak >= 10),
        _BadgeDef(Icons.task_alt_rounded, 'Planner Pro',
            'Log 5+ Daily Plan activities', const Color(0xFF42A5F5),
            (d) => (d.categoryStats['Daily Plans'] ?? 0) >= 5),
        _BadgeDef(Icons.nightlight_round_rounded, 'Sleep Star',
            'Maintain a 7-day streak', const Color(0xFF5C6BC0),
            (d) => d.streak >= 7),
        _BadgeDef(Icons.wb_sunny_rounded, 'Early Bird',
            'Log Morning Hydration 10+ times', const Color(0xFFFFA726),
            (d) => d.activityCount('Morning Hydration') >= 10),
      ];

  List<_BadgeDef> get _fitnessDefs => [
        _BadgeDef(Icons.fitness_center_rounded, 'Gym Rat',
            'Log 12+ Fitness activities', const Color(0xFF66BB6A),
            (d) => (d.categoryStats['Fitness'] ?? 0) >= 12),
        _BadgeDef(Icons.directions_run_rounded, 'Road Runner',
            'Log running 5+ times', const Color(0xFF26C6DA),
            (d) => d.activityCount('Running') + d.activityCount('Jogging') >= 5),
        _BadgeDef(Icons.sports_gymnastics_rounded, 'Flexible',
            'Log Yoga 7+ times', const Color(0xFFEC407A),
            (d) => d.activityCount('Yoga') >= 7),
        _BadgeDef(Icons.pool_rounded, 'Swimmer',
            'Log Swimming 3+ times', const Color(0xFF29B6F6),
            (d) => d.activityCount('Swimming') >= 3),
        _BadgeDef(Icons.sports_soccer_rounded, 'Team Player',
            'Log any Fitness activity', const Color(0xFF8D6E63),
            (d) => (d.categoryStats['Fitness'] ?? 0) >= 1),
        _BadgeDef(Icons.speed_rounded, 'Speed Demon',
            'Log HIIT 5+ times', const Color(0xFFFF5722),
            (d) => d.activityCount('HIIT') >= 5),
      ];

  List<_BadgeDef> get _wellnessDefs => [
        _BadgeDef(Icons.favorite_rounded, 'Self Care',
            'Record your mood 7+ times', const Color(0xFFEC407A),
            (d) => d.moodCount >= 7),
        _BadgeDef(Icons.emoji_emotions_rounded, 'Mood Tracker',
            'Record your mood 30+ times', const Color(0xFFFFA726),
            (d) => d.moodCount >= 30),
        _BadgeDef(Icons.spa_rounded, 'Rest Well',
            'Log Rest & Recovery 5+ times', const Color(0xFF9CCC65),
            (d) => d.activityCount('Rest & Recovery') >= 5),
        _BadgeDef(Icons.psychology_rounded, 'Mind Strong',
            'Log Skill Practice 5+ times', const Color(0xFF7E57C2),
            (d) => d.activityCount('Skill Practice') >= 5),
        _BadgeDef(Icons.local_hospital_rounded, 'Health First',
            'Complete your health profile', const Color(0xFFEF5350),
            (d) => d.profileComplete),
        _BadgeDef(Icons.star_rounded, 'All-Rounder',
            'Log in all 4 categories', Colors.amber,
            (d) =>
                (d.categoryStats['Habits'] ?? 0) > 0 &&
                (d.categoryStats['Fitness'] ?? 0) > 0 &&
                (d.categoryStats['Moods'] ?? 0) > 0 &&
                (d.categoryStats['Daily Plans'] ?? 0) > 0),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Awards & Achievements',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.primaryColor,
          indicatorWeight: 3,
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Habits'),
            Tab(text: 'Fitness'),
            Tab(text: 'Wellness'),
          ],
        ),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _db.userProfileStream(_uid),
        builder: (context, profileSnap) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _db.allLogsStream(_uid),
            builder: (context, logsSnap) {
              return StreamBuilder<Map<String, int>>(
                stream: _db.categoryStatsStream(_uid),
                builder: (context, statsSnap) {
                  return StreamBuilder<int>(
                    stream: _db.moodCountStream(_uid),
                    builder: (context, moodSnap) {
                      final profile = profileSnap.data ?? {};
                      final allLogs = logsSnap.data ?? [];
                      final catStats = statsSnap.data ?? {};
                      final moodCount = moodSnap.data ?? 0;
                      final streak =
                          (profile['currentStreak'] as int?) ?? 0;
                      final totalPoints =
                          (profile['totalPoints'] as int?) ?? 0;
                      final dailyPoints =
                          (profile['dailyPoints'] as int?) ?? 0;

                      // Build per-activity count map
                      final actMap = <String, int>{};
                      for (final log in allLogs) {
                        final a = log['activity'] as String? ?? '';
                        actMap[a] = (actMap[a] ?? 0) + 1;
                      }

                      final profileComplete =
                          (profile['name'] as String? ?? '').isNotEmpty &&
                              (profile['profession'] as String? ?? '')
                                  .isNotEmpty &&
                              ((profile['age'] as int?) ?? 0) > 0;

                      final data = _BadgeData(
                        streak: streak,
                        categoryStats: catStats,
                        activityMap: actMap,
                        moodCount: moodCount,
                        profileComplete: profileComplete,
                      );

                      final habitBadges = _habitDefs
                          .map((d) => _Badge.from(d, data))
                          .toList();
                      final fitnessBadges = _fitnessDefs
                          .map((d) => _Badge.from(d, data))
                          .toList();
                      final wellnessBadges = _wellnessDefs
                          .map((d) => _Badge.from(d, data))
                          .toList();

                      final allBadges = [
                        ...habitBadges,
                        ...fitnessBadges,
                        ...wellnessBadges,
                      ];
                      final earned =
                          allBadges.where((b) => b.earned).length;

                      return Column(
                        children: [
                          _buildXpHeader(theme, totalPoints, streak,
                              dailyPoints, earned, allBadges.length),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildBadgeGrid(habitBadges),
                                _buildBadgeGrid(fitnessBadges),
                                _buildBadgeGrid(wellnessBadges),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildXpHeader(ThemeData theme, int xp, int streak, int dailyPoints,
      int earned, int total) {
    // Unified formula: 500 pts per level
    const ptsPerLevel = 500;
    final level = (xp / ptsPerLevel).floor() + 1;
    final nextLevelXp = level * ptsPerLevel;
    final progress = (xp % ptsPerLevel) / ptsPerLevel;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor.withOpacity(0.25), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      color: Colors.amber,
                      backgroundColor: Colors.white10,
                    ),
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 32),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Level $level Tracker',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('$xp / $nextLevelXp XP',
                        style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white10,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        '${nextLevelXp - xp} XP to Level ${level + 1}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('🏅 Earned', '$earned'),
              _buildMiniStat('🎯 Total', '$total'),
              _buildMiniStat('🔥 Streak', '${streak}d'),
              _buildMiniStat('⭐ Points', '$dailyPoints'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white38)),
      ],
    );
  }

  Widget _buildBadgeGrid(List<_Badge> badges) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: badges.length,
      itemBuilder: (context, i) => _buildBadgeTile(context, badges[i]),
    );
  }

  Widget _buildBadgeTile(BuildContext context, _Badge badge) {
    return GestureDetector(
      onTap: () => _showBadgeDetail(context, badge),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: badge.earned
              ? badge.color.withOpacity(0.1)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badge.earned
                ? badge.color.withOpacity(0.4)
                : Colors.white10,
            width: badge.earned ? 1.5 : 1,
          ),
          boxShadow: badge.earned
              ? [
                  BoxShadow(
                      color: badge.color.withOpacity(0.15), blurRadius: 12)
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: badge.earned
                        ? badge.color.withOpacity(0.2)
                        : Colors.white.withOpacity(0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(badge.icon,
                      size: 28,
                      color: badge.earned ? badge.color : Colors.white24),
                ),
                if (!badge.earned)
                  const Icon(Icons.lock_rounded,
                      size: 14, color: Colors.white24),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: badge.earned ? Colors.white : Colors.white30,
                fontWeight:
                    badge.earned ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(BuildContext context, _Badge badge) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: badge.earned
                    ? badge.color.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(badge.icon,
                  size: 48,
                  color: badge.earned ? badge.color : Colors.white24),
            ),
            const SizedBox(height: 16),
            Text(badge.label,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text(badge.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 14, height: 1.5)),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: badge.earned
                    ? badge.color.withOpacity(0.2)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge.earned ? '✅ Earned!' : '🔒 Keep going to unlock',
                style: TextStyle(
                  color: badge.earned ? badge.color : Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Data model for badge evaluation ────────────────────────────────────────

class _BadgeData {
  final int streak;
  final Map<String, int> categoryStats;
  final Map<String, int> activityMap;
  final int moodCount;
  final bool profileComplete;

  const _BadgeData({
    required this.streak,
    required this.categoryStats,
    required this.activityMap,
    required this.moodCount,
    required this.profileComplete,
  });

  int activityCount(String name) => activityMap[name] ?? 0;
}

// ── Badge definition (static) ───────────────────────────────────────────────

class _BadgeDef {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final bool Function(_BadgeData) isEarned;

  const _BadgeDef(
      this.icon, this.label, this.description, this.color, this.isEarned);
}

// ── Evaluated badge ─────────────────────────────────────────────────────────

class _Badge {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final bool earned;

  const _Badge(
      {required this.icon,
      required this.label,
      required this.description,
      required this.color,
      required this.earned});

  factory _Badge.from(_BadgeDef def, _BadgeData data) => _Badge(
        icon: def.icon,
        label: def.label,
        description: def.description,
        color: def.color,
        earned: def.isEarned(data),
      );
}
