import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import '../../history/screens/history_screen.dart';
import '../../mood/models/mood_result.dart';
import '../../mood/widgets/mood_check_in_sheet.dart';


class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _db = FirestoreService();
  final String _today = DateTime.now().toIso8601String().substring(0, 10);

  static const List<String> _defaultHabits = [
    'Morning Hydration', 'Review Goals', '30m Reading', 'Evening Reflection'
  ];

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _db.userProfileStream(_uid),
      builder: (context, profileSnap) {
        final profile = profileSnap.data ?? {};
        final name = profile['name'] ?? 'there';
        final streak = profile['currentStreak'] ?? 0;
        final dailyPoints = profile['dailyPoints'] ?? 0;
        final totalPoints = profile['totalPoints'] ?? 0;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome Back,'),
                Text(name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14)),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.orangeAccent, size: 24),
                    const SizedBox(width: 4),
                    Text('$streak Day Streak',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressCard(context, dailyPoints, totalPoints),
                const SizedBox(height: 16),

                // ── Today's Mood ─────────────────────────────────────────────
                _buildMoodCard(context),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Activity',
                        style: Theme.of(context).textTheme.titleLarge),
                    TextButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const HistoryScreen())),
                      style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).primaryColor),
                      child: const Text('View All →',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildRecentLogs(context),

                const SizedBox(height: 24),
                Text('Daily Habits',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _buildHabitsList(context),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Today's Mood card ─────────────────────────────────────────────────────

  Widget _buildMoodCard(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _db.currentMoodStream(_uid),
      builder: (context, snap) {
        final moodMap = snap.data;

        // No mood yet today — show a prompt
        if (moodMap == null) {
          return GestureDetector(
            onTap: () => MoodCheckInSheet.showIfNeeded(context, force: true),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.2)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology_rounded,
                      color: Color(0xFF6C63FF), size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How are you feeling?',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      SizedBox(height: 2),
                      Text('Tap to run AI mood check-in',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white24, size: 20),
              ]),
            ),
          );
        }

        // Mood detected — show it
        final mood = MoodResult.fromMap(moodMap);
        return GestureDetector(
          onTap: () async {
            await MoodCheckInSheet.showIfNeeded(context, force: true);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mood.color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: mood.color.withOpacity(0.25)),
            ),
            child: Row(children: [
              // Emoji
              Text(mood.emoji,
                  style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text("Today's Mood",
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: mood.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            mood.detectedFrom == 'ai_gemini'
                                ? Icons.auto_awesome_rounded
                                : Icons.analytics_rounded,
                            size: 9,
                            color: mood.color,
                          ),
                          const SizedBox(width: 3),
                          Text('AI',
                              style: TextStyle(
                                  color: mood.color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(mood.label,
                        style: TextStyle(
                            color: mood.color,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      mood.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Confidence ring
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: mood.confidence,
                    strokeWidth: 3,
                    backgroundColor: mood.color.withOpacity(0.15),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(mood.color),
                  ),
                  Text(
                    '${(mood.confidence * 100).round()}%',
                    style: TextStyle(
                        color: mood.color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildProgressCard(BuildContext context, int dailyPoints, int totalPoints) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Goal', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    '$dailyPoints / 300 pts',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Total: $totalPoints pts',
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
              CircularProgressIndicator(
                value: (dailyPoints / 300).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[800],
                color: Theme.of(context).primaryColor,
                strokeWidth: 8,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLogs(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.logsStream(_uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snap.data ?? [];
        if (logs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('No activity logged yet. Tap + to log something!',
                  style: TextStyle(color: Colors.white38)),
            ),
          );
        }
        return Column(
          children: logs.take(3).map((log) {
            return Dismissible(
              key: Key(log['id'] ?? log.hashCode.toString()),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Delete log?',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    content: Text('Remove "${log['activity']}" from your activity log?',
                        style: const TextStyle(color: Colors.white54)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                      TextButton(onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ) ?? false;
              },
              onDismissed: (_) => _db.deleteLog(_uid, log['id']),
              child: _buildLogItem(context, log),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLogItem(BuildContext context, Map<String, dynamic> log) {
    final color = Color(log['color'] as int? ?? 0xFF6C63FF);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log['activity'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 16, color: Colors.white)),
                const SizedBox(height: 4),
                Text(log['mood'] ?? '',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
              ],
            ),
          ),
          Text(log['time'] ?? '',
              style: TextStyle(color: Colors.white.withOpacity(0.4),
                  fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildHabitsList(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.habitsForDateStream(_uid, _today),
      builder: (context, snap) {
        final completed = {
          for (final h in snap.data ?? [])
            if (h['completed'] == true) h['habit'] as String
        };
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _db.habitAlarmsStream(_uid),
          builder: (context, alarmSnap) {
            final alarms = {
              for (final a in alarmSnap.data ?? [])
                a['habit'] as String: a
            };
            return Column(
              children: _defaultHabits.map((habit) {
                final isDone    = completed.contains(habit);
                final hasAlarm  = alarms.containsKey(habit);
                final alarmData = alarms[habit];
                final alarmTime = hasAlarm
                    ? TimeOfDay(
                        hour:   alarmData!['hour']   as int? ?? 8,
                        minute: alarmData['minute'] as int? ?? 0)
                    : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      // Repeat icon
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .primaryColor
                                .withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.repeat_rounded,
                              color:
                                  Theme.of(context).primaryColor,
                              size: 22),
                        ),
                      ),
                      // Checkbox + title
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            checkboxTheme: CheckboxThemeData(
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(6)),
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isDone,
                            onChanged: (val) async {
                              try {
                                await _db.setHabitCompletion(
                                    _uid, habit, _today,
                                    val ?? false);
                                if (val == true) {
                                  await _db.addPoints(_uid, 20);
                                  await _db.updateStreak(_uid);
                                }
                              } catch (e) {
                                debugPrint('Habit save: $e');
                              }
                            },
                            title: Text(habit,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: isDone
                                      ? Colors.white54
                                      : Colors.white,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                )),
                            subtitle: hasAlarm
                                ? Text(
                                    '⏰ ${alarmTime!.format(context)}',
                                    style: const TextStyle(
                                        color: Color(0xFF6C63FF),
                                        fontSize: 11),
                                  )
                                : null,
                            controlAffinity:
                                ListTileControlAffinity.trailing,
                            activeColor:
                                Theme.of(context).primaryColor,
                            checkColor: Colors.white,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                          ),
                        ),
                      ),
                      // Bell alarm button — tap to set; if alarm exists,
                      // shows a menu to change or delete.
                      IconButton(
                        icon: Icon(
                          hasAlarm
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          color: hasAlarm
                              ? const Color(0xFF6C63FF)
                              : Colors.white24,
                          size: 22,
                        ),
                        tooltip: hasAlarm ? 'Alarm options' : 'Set daily alarm',
                        onPressed: () => hasAlarm
                            ? _showAlarmOptions(context, habit, alarmTime!)
                            : _showAlarmPicker(context, habit),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  /// Shows a bottom sheet with Change / Delete options for an existing alarm.
  Future<void> _showAlarmOptions(
      BuildContext context, String habit, TimeOfDay current) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              const Icon(Icons.notifications_active_rounded,
                  color: Color(0xFF6C63FF), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Alarm for "$habit"',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  current.format(context),
                  style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            // Change time
            ListTile(
              onTap: () async {
                Navigator.pop(context);
                await _showAlarmPicker(context, habit, current: current);
              },
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: Color(0xFF6C63FF), size: 20),
              ),
              title: const Text('Change alarm time',
                  style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Colors.white24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            const SizedBox(height: 4),
            // Delete alarm
            ListTile(
              onTap: () async {
                Navigator.pop(context);
                await _db.deleteHabitAlarm(_uid, habit);
                await NotificationService().cancelHabitAlarm(habit);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🔕 Alarm for "$habit" removed'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_off_rounded,
                    color: Colors.redAccent, size: 20),
              ),
              title: const Text('Remove alarm',
                  style: TextStyle(color: Colors.redAccent)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAlarmPicker(
      BuildContext context, String habit,
      {TimeOfDay? current}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Set alarm for "$habit"',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary:   Color(0xFF6C63FF),
              onPrimary: Colors.white,
              surface:   Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;

    // Save to Firestore
    await _db.saveHabitAlarm(_uid, habit, picked.hour, picked.minute);

    // Schedule notification (permission is also requested inside scheduleHabitAlarm)
    final ns = NotificationService();
    await ns.scheduleHabitAlarm(habitName: habit, time: picked);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⏰ Alarm set for "$habit" at ${picked.format(context)}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF6C63FF),
      ),
    );

    // Samsung / Xiaomi / Huawei OEM devices aggressively kill background
    // alarm receivers.  Prompt the user to exempt LifeTrack from battery
    // optimisation the first time they set an alarm.
    _showBatteryOptimisationTip(context);
  }

  void _showBatteryOptimisationTip(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('🔋', style: TextStyle(fontSize: 22)),
          SizedBox(width: 10),
          Text('Keep Alarms Reliable',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'Samsung and some Android devices can block alarms when the app '
          'is in the background.\n\n'
          'To make sure your habit alarms always fire:\n\n'
          '1. Go to Settings → Battery\n'
          '2. Tap "App power management"\n'
          '3. Find LifeTrack and set it to "Unrestricted" or\n'
          '   remove it from sleeping apps.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it',
                style: TextStyle(color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
