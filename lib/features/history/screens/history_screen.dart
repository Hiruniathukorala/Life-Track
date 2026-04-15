import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = FirestoreService();
  String? _filterCategory; // null = show all
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static const _categories = ['All', 'Habits', 'Fitness', 'Moods', 'Daily Plans'];

  static const _categoryColors = {
    'Habits':      Color(0xFF6C63FF),
    'Fitness':     Color(0xFF29B6F6),
    'Moods':       Color(0xFFFFA726),
    'Daily Plans': Color(0xFF66BB6A),
  };

  Color _colorFor(Map<String, dynamic> log) {
    final stored = log['color'] as int?;
    if (stored != null) return Color(stored);
    final cat = log['category'] as String?;
    return _categoryColors[cat] ?? const Color(0xFF6C63FF);
  }

  IconData _iconFor(Map<String, dynamic> log) {
    switch (log['category'] as String?) {
      case 'Fitness':     return Icons.fitness_center_rounded;
      case 'Moods':       return Icons.mood_rounded;
      case 'Daily Plans': return Icons.check_circle_outline_rounded;
      case 'Habits':
      default:            return Icons.repeat_rounded;
    }
  }

  /// Group logs by their date label (Today / Yesterday / date string)
  Map<String, List<Map<String, dynamic>>> _groupByDate(List<Map<String, dynamic>> logs) {
    final now = DateTime.now();
    final todayStr    = _dateStr(now);
    final yestStr     = _dateStr(now.subtract(const Duration(days: 1)));
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final log in logs) {
      // timestamp is a Firestore Timestamp → arrives as Map or DateTime in Flutter SDK
      String label;
      final ts = log['timestamp'];
      if (ts != null) {
        DateTime? dt;
        if (ts is DateTime) {
          dt = ts;
        } else if (ts is Map && ts['_seconds'] != null) {
          dt = DateTime.fromMillisecondsSinceEpoch((ts['_seconds'] as int) * 1000);
        }
        if (dt != null) {
          final s = _dateStr(dt);
          if (s == todayStr)  label = 'Today';
          else if (s == yestStr) label = 'Yesterday';
          else label = _friendlyDate(dt);
        } else {
          label = 'Recent';
        }
      } else {
        label = 'Recent';
      }
      (grouped[label] ??= []).add(log);
    }
    return grouped;
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  String _friendlyDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Activity History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category filter chips
          _buildFilterRow(),
          const SizedBox(height: 8),
          // Log list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _db.allLogsStream(_uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data ?? [];
                final logs = _filterCategory == null
                    ? all
                    : all.where((l) => l['category'] == _filterCategory).toList();

                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded,
                            size: 64, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text(
                          _filterCategory == null
                              ? 'No activities logged yet'
                              : 'No $_filterCategory activities',
                          style: const TextStyle(color: Colors.white38, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                final grouped = _groupByDate(logs);
                final sections = grouped.keys.toList();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: sections.length,
                  itemBuilder: (ctx, i) {
                    final section = sections[i];
                    final items = grouped[section]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(children: [
                            Text(section,
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                            const SizedBox(width: 10),
                            Expanded(child: Divider(color: Colors.white12, height: 1)),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${items.length}',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11)),
                            ),
                          ]),
                        ),
                        ...items.map((log) => _buildLogCard(context, log)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final cat = _categories[i];
          final isAll = cat == 'All';
          final isSelected = isAll
              ? _filterCategory == null
              : _filterCategory == cat;
          final color = isAll
              ? const Color(0xFF6C63FF)
              : (_categoryColors[cat] ?? const Color(0xFF6C63FF));
          return GestureDetector(
            onTap: () => setState(() =>
                _filterCategory = isAll ? null : cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? color.withOpacity(0.5) : Colors.white12),
              ),
              child: Text(cat,
                  style: TextStyle(
                      color: isSelected ? color : Colors.white38,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, Map<String, dynamic> log) {
    final color = _colorFor(log);
    final icon  = _iconFor(log);

    return Dismissible(
      key: Key(log['id'] ?? log.hashCode.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.redAccent, size: 26),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete log?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text('Remove "${log['activity']}" from history?',
              style: const TextStyle(color: Colors.white54)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54))),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete',
                    style: TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.bold))),
          ],
        ),
      ) ?? false,
      onDismissed: (_) {
        final id = log['id'] as String?;
        if (id != null) _db.deleteLog(_uid, id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log['activity'] ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  if ((log['mood'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(log['mood'] as String,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13)),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(log['time'] ?? '',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                if (log['category'] != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(log['category'] as String,
                        style: TextStyle(
                            color: color, fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
