import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';

class PeriodTrackerScreen extends StatefulWidget {
  const PeriodTrackerScreen({super.key});

  @override
  State<PeriodTrackerScreen> createState() => _PeriodTrackerScreenState();
}

class _PeriodTrackerScreenState extends State<PeriodTrackerScreen>
    with TickerProviderStateMixin {
  final _db = FirestoreService();
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  int _cycleLength  = 28;
  int _periodLength = 5;
  DateTime _lastPeriodStart =
      DateTime.now().subtract(const Duration(days: 14));
  bool _isPeriodActive = false;
  bool _saving         = false;

  final Map<String, bool> _symptoms = {
    'Cramps': false, 'Headache': false, 'Bloating': false,
    'Fatigue': false, 'Mood Swings': false, 'Back Pain': false,
    'Nausea': false, 'Spotting': false,
  };

  final Map<String, IconData> _symptomIcons = {
    'Cramps':      Icons.bolt_rounded,
    'Headache':    Icons.psychology_rounded,
    'Bloating':    Icons.bubble_chart_rounded,
    'Fatigue':     Icons.battery_2_bar_rounded,
    'Mood Swings': Icons.mood_rounded,
    'Back Pain':   Icons.accessibility_new_rounded,
    'Nausea':      Icons.sick_rounded,
    'Spotting':    Icons.water_drop_rounded,
  };

  int _flowIntensity = 0; // 0=none 1=light 2=medium 3=heavy

  // ── Computed ──────────────────────────────────────────────────────────────

  int get _dayInCycle {
    final diff = DateTime.now().difference(_lastPeriodStart).inDays;
    return (diff % _cycleLength) + 1;
  }

  int get _daysUntilNextPeriod {
    final next = _dayInCycle <= _cycleLength
        ? _cycleLength - _dayInCycle
        : _cycleLength - (_dayInCycle % _cycleLength);
    return next;
  }

  String get _currentPhase {
    if (_dayInCycle <= _periodLength) return 'Menstrual';
    if (_dayInCycle <= 13) return 'Follicular';
    if (_dayInCycle <= 15) return 'Ovulation';
    return 'Luteal';
  }

  Color get _phaseColor {
    switch (_currentPhase) {
      case 'Menstrual':  return const Color(0xFFE53935);
      case 'Follicular': return const Color(0xFFEC407A);
      case 'Ovulation':  return const Color(0xFFAB47BC);
      case 'Luteal':     return const Color(0xFF7E57C2);
      default:           return const Color(0xFFEC407A);
    }
  }

  String get _phaseDescription {
    switch (_currentPhase) {
      case 'Menstrual':  return 'Your period has started. Rest, hydrate, and be gentle with yourself. 🌸';
      case 'Follicular': return 'Energy is rising! Great time for new projects and social activities. ✨';
      case 'Ovulation':  return 'Peak energy and confidence. You\'re at your most vibrant. 🌺';
      case 'Luteal':     return 'Wind-down phase. Focus on self-care and relaxing activities. 🌙';
      default:           return '';
    }
  }

  double get _cycleProgress => (_dayInCycle - 1) / _cycleLength;

  String get _periodStartDate =>
      _lastPeriodStart.toIso8601String().substring(0, 10);

  // ── Rotating period tip ───────────────────────────────────────────────────

  static const List<String> _periodTips = [
    '💧 Hydration reduces bloating — aim for 2.5 L of water today',
    '🍫 Dark chocolate has magnesium which naturally reduces cramps',
    '🔥 A heat pad on your lower abdomen for 20 min beats most painkillers',
    '🚶 Light walking actually reduces period pain over time',
    '🧘 5 minutes of child\'s pose relieves lower back and cramp pain',
    '🥬 Iron-rich foods today: spinach, lentils, pumpkin seeds',
    '☕ Avoid caffeine — it constricts blood vessels and worsens cramps',
    '💊 Ibuprofen works best taken before cramps peak, not after they start',
    '❄️ Avoid cold drinks — they can intensify cramping significantly',
    '💤 Extra sleep during Day 1–2 isn\'t laziness — it\'s real recovery',
    '🫐 Anti-inflammatory foods help: berries, ginger tea, turmeric',
    '📵 Reducing social media also reduces stress-driven PMS symptoms',
  ];

  String get _todayTip {
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year))
        .inDays;
    return _periodTips[dayOfYear % _periodTips.length];
  }

  // ── Guidance (phase + scanned mood combined) ──────────────────────────────

  String _buildGuidance(String phase, String moodLabel) {
    final hasCramps  = _symptoms['Cramps']  ?? false;
    final hasFatigue = _symptoms['Fatigue'] ?? false;

    switch (phase) {
      case 'Menstrual':
        switch (moodLabel) {
          case 'Tired':
            return hasCramps
                ? 'Cramps are draining your energy today — a heat pad + magnesium helps most. Skip intense workouts.'
                : hasFatigue
                    ? 'Fatigue on Day $_dayInCycle is completely normal. Rest is productive right now. Warm drinks help.'
                    : 'Your energy is lowest right now — rest, hydrate, and let your body do its work.';
          case 'Sad':
            return 'Feeling low is completely normal during your period 💜. Watch something cosy and eat dark chocolate — it genuinely helps.';
          case 'Stressed':
            return 'Period + stress is tough. Try box breathing: 4s in → 4s hold → 4s out. Avoid caffeine today.';
          case 'Anxious':
            return 'Hormonal anxiety peaks on Day 1–2. Slow deep breathing for 5 minutes resets your nervous system fast.';
          case 'Happy':
            return 'Feeling great despite Day $_dayInCycle! Gentle movement can extend this good energy. Keep it light.';
          case 'Calm':
            return 'A peaceful period day 🌸 — stay hydrated and enjoy some quiet time. You\'re handling this really well.';
          default:
            return 'Rest, hydrate, and be gentle with yourself. Your body is working hard right now.';
        }

      case 'Follicular':
        switch (moodLabel) {
          case 'Happy':
            return 'Energy is rising and you feel it! Great time to start a new habit or tackle that goal you\'ve been avoiding.';
          case 'Excited':
            return 'Follicular energy peak — plan your boldest tasks this week! Your body fully supports it right now.';
          case 'Tired':
            return 'Still recovering post-period — iron-rich foods today (spinach, lentils, dark chocolate). Energy builds tomorrow.';
          case 'Calm':
            return 'Calm and steady — use this clarity for planning and creative thinking. Your focus is sharpening.';
          default:
            return 'Energy is rising after your period. Great time for new projects, social plans, and light workouts.';
        }

      case 'Ovulation':
        switch (moodLabel) {
          case 'Excited':
            return 'Peak confidence day! Schedule important meetings, workouts, or anything needing your absolute best self.';
          case 'Happy':
            return 'You\'re at your most vibrant today 🌺 — great for social plans, creative work, and big conversations.';
          case 'Stressed':
            return 'Ovulation + stress is unusual. Your body is sensitive right now — a 20-min walk outside resets cortisol fast.';
          case 'Tired':
            return 'Feeling tired at ovulation? Hydrate well and eat protein — your body may need more fuel right now.';
          default:
            return 'Peak energy and confidence today. You\'re at your most vibrant — make the most of it!';
        }

      case 'Luteal':
      default:
        switch (moodLabel) {
          case 'Stressed':
            return 'PMS zone — magnesium helps most (nuts, seeds, dark chocolate). Cut caffeine and salty food today 🌙';
          case 'Tired':
            return 'Pre-period fatigue is real. Prioritise sleep tonight, reduce screen time after 9pm, and be kind to yourself.';
          case 'Sad':
            return 'Luteal phase can feel heavy. This is hormonal and will pass 💜 Gentle movement and omega-3 foods help.';
          case 'Anxious':
            return 'Pre-period anxiety peaks in the Luteal phase. 5 min of slow breathing + reducing sugar helps significantly.';
          case 'Happy':
            return 'Feeling great in your luteal phase — a positive sign! Keep your sleep routine consistent to maintain it.';
          case 'Calm':
            return 'Calm in the Luteal phase is golden — protect this energy. Avoid overcommitting for the next few days.';
          default:
            return 'Wind-down phase. Focus on self-care, reduce commitments where possible, and prioritise good sleep.';
        }
    }
  }

  String _guidanceEmoji(String phase, String moodLabel) {
    if (moodLabel == 'Tired' || moodLabel == 'Sad') return '💜';
    if (moodLabel == 'Stressed' || moodLabel == 'Anxious') return '🌿';
    if (moodLabel == 'Happy' || moodLabel == 'Excited') return '✨';
    if (phase == 'Menstrual') return '🌸';
    if (phase == 'Ovulation') return '🌺';
    return '🌙';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _db.periodDataStream(_uid).first;
    if (!mounted) return;
    if (data != null) {
      setState(() {
        _cycleLength     = (data['cycleLength']  as num?)?.toInt() ?? 28;
        _periodLength    = (data['periodLength'] as num?)?.toInt() ?? 5;
        _isPeriodActive  = data['isPeriodActive'] as bool? ?? false;
        _flowIntensity   = (data['flowIntensity'] as num?)?.toInt() ?? 0;
        final savedStart = data['lastPeriodStart'] as String?;
        if (savedStart != null) {
          _lastPeriodStart = DateTime.tryParse(savedStart) ?? _lastPeriodStart;
        }
        final savedSymptoms = data['symptoms'] as Map<String, dynamic>?;
        if (savedSymptoms != null) {
          savedSymptoms.forEach((k, v) {
            if (_symptoms.containsKey(k)) _symptoms[k] = v as bool;
          });
        }
      });
    } else {
      await _db.savePeriodData(_uid, {
        'cycleLength':     _cycleLength,
        'periodLength':    _periodLength,
        'isPeriodActive':  _isPeriodActive,
        'flowIntensity':   _flowIntensity,
        'lastPeriodStart': _lastPeriodStart.toIso8601String(),
        'symptoms':        _symptoms,
        'updatedAt':       DateTime.now().toIso8601String(),
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Period Tracker',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.favorite_rounded, color: _phaseColor, size: 24),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _buildPhaseBanner(),
            const SizedBox(height: 20),

            // ── Mood-based guidance (only when period is active) ──────────────
            if (_isPeriodActive) ...[
              _buildMoodGuidanceCard(),
              const SizedBox(height: 16),
              _buildDailyTipCard(),
              const SizedBox(height: 24),
            ],

            _buildSectionHeader('Cycle Calendar', 'Day $_dayInCycle of $_cycleLength'),
            const SizedBox(height: 16),
            _buildCycleCalendar(),
            const SizedBox(height: 28),

            _buildQuickStats(),
            const SizedBox(height: 28),

            _buildSectionHeader('Period Status', 'Track your flow'),
            const SizedBox(height: 16),
            _buildPeriodControl(),
            const SizedBox(height: 28),

            _buildSectionHeader('Symptoms', 'How are you feeling?'),
            const SizedBox(height: 16),
            _buildSymptomsGrid(),
            const SizedBox(height: 28),

            _buildSectionHeader('Cycle Settings', 'Customise your cycle'),
            const SizedBox(height: 16),
            _buildCycleSettings(),
            const SizedBox(height: 28),

            // ── Period Mood History ──────────────────────────────────────────
            if (_isPeriodActive) ...[
              _buildSectionHeader('Period Mood Log', 'Your feelings this period'),
              const SizedBox(height: 16),
              _buildPeriodMoodHistory(),
              const SizedBox(height: 28),
            ],

            // ── Cross-period pattern ─────────────────────────────────────────
            _buildPatternCard(),
            const SizedBox(height: 28),

            _buildSaveButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Mood Guidance Card ────────────────────────────────────────────────────

  Widget _buildMoodGuidanceCard() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _db.currentMoodStream(_uid),
      builder: (context, snap) {
        final moodMap   = snap.data;
        final moodLabel = moodMap?['label'] as String? ?? 'Okay';
        final moodEmoji = moodMap?['emoji']  as String? ?? '😐';
        final guidance  = _buildGuidance(_currentPhase, moodLabel);
        final emoji     = _guidanceEmoji(_currentPhase, moodLabel);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _phaseColor.withOpacity(0.18),
                _phaseColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _phaseColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _phaseColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      color: _phaseColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Personalised Guidance',
                      style: TextStyle(
                          color: _phaseColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                // Current mood pill
                if (moodMap != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _phaseColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$moodEmoji $moodLabel',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
              ]),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      guidance,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
              if (moodMap == null) ...[
                const SizedBox(height: 10),
                Text(
                  'Scan your face to get mood-personalised advice ↗',
                  style: TextStyle(
                      color: _phaseColor.withOpacity(0.7),
                      fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Daily Tip Card ────────────────────────────────────────────────────────

  Widget _buildDailyTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tips_and_updates_rounded,
                color: Colors.amber, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today\'s Tip',
                    style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
                const SizedBox(height: 3),
                Text(_todayTip,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Period Mood History ───────────────────────────────────────────────────

  bool _showAllMoods = false;

  Widget _buildPeriodMoodHistory() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.periodMoodsThisPeriodStream(_uid, _periodStartDate),
      builder: (context, snap) {
        final all   = snap.data ?? [];
        final moods = _showAllMoods ? all : all.take(7).toList();

        if (moods.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: const Center(
              child: Text(
                'No mood scans yet this period.\nYour mood history will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            children: [
              ...moods.map((m) {
              final label   = m['label']  as String? ?? 'Okay';
              final emoji   = m['emoji']  as String? ?? '😐';
              final day     = m['cycleDay'] as int? ?? 0;
              final conf    = ((m['confidence'] as num?)?.toDouble() ?? 0.5) * 100;
              final phase   = m['phase'] as String? ?? '';
              final syms    = (m['symptoms'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [];
              final color   = _labelColor(label);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(label,
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          const SizedBox(width: 6),
                          Text('${conf.round()}% confidence',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ]),
                        if (syms.isNotEmpty)
                          Text(syms.join(', '),
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _phaseColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Day $day',
                            style: TextStyle(
                                color: _phaseColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (phase.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(phase,
                              style: const TextStyle(
                                  color: Colors.white24, fontSize: 10)),
                        ),
                    ],
                  ),
                ]),
              );
            }).toList(),
              // "Show more / Show less" toggle when there are > 7 entries
              if (all.length > 7) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _showAllMoods = !_showAllMoods),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _phaseColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _phaseColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      _showAllMoods
                          ? 'Show less'
                          : 'Show all ${all.length} entries',
                      style: TextStyle(
                          color: _phaseColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Cross-period Pattern Card ─────────────────────────────────────────────

  Widget _buildPatternCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.allPeriodMoodsStream(_uid),
      builder: (context, snap) {
        final all = snap.data ?? [];
        if (all.length < 3) return const SizedBox.shrink();

        // Count mood occurrences per cycle day
        final dayMoods = <int, Map<String, int>>{};
        for (final m in all) {
          final day   = m['cycleDay'] as int? ?? 0;
          final label = m['label']    as String? ?? 'Okay';
          if (day == 0) continue;
          dayMoods.putIfAbsent(day, () => {});
          dayMoods[day]![label] = (dayMoods[day]![label] ?? 0) + 1;
        }

        // Find top mood per day (days 1-5 only, most insightful)
        final insights = <String>[];
        for (int d = 1; d <= 5; d++) {
          final m = dayMoods[d];
          if (m == null || m.isEmpty) continue;
          final top = m.entries.reduce((a, b) => a.value > b.value ? a : b);
          if (top.value >= 2) {
            insights.add('Day $d: usually ${top.key} ${_labelEmoji(top.key)}');
          }
        }

        if (insights.isEmpty) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.insights_rounded,
                    color: Color(0xFF6C63FF), size: 20),
                const SizedBox(width: 8),
                const Text('Your Period Pattern',
                    style: TextStyle(
                        color: Color(0xFF6C63FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ]),
              const SizedBox(height: 6),
              const Text(
                'Based on your mood history across periods:',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ...insights.map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const Icon(Icons.circle, size: 6, color: Color(0xFF6C63FF)),
                      const SizedBox(width: 8),
                      Text(i,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ]),
                  )),
              const SizedBox(height: 8),
              Text(
                'Consider scheduling lighter tasks on these days next cycle.',
                style: TextStyle(
                    color: const Color(0xFF6C63FF).withOpacity(0.7),
                    fontSize: 12,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Phase Banner ──────────────────────────────────────────────────────────

  Widget _buildPhaseBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _phaseColor.withOpacity(0.3),
            _phaseColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _phaseColor.withOpacity(0.25)),
      ),
      child: Row(children: [
        SizedBox(
          width: 90, height: 90,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: _cycleProgress,
              strokeWidth: 8,
              color: _phaseColor,
              backgroundColor: _phaseColor.withOpacity(0.1),
            ),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$_dayInCycle',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Text('day',
                  style: TextStyle(fontSize: 11, color: Colors.white54)),
            ]),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _phaseColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_currentPhase Phase',
                    style: TextStyle(
                        color: _phaseColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              const SizedBox(height: 8),
              Text(_phaseDescription,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.4)),
              const SizedBox(height: 8),
              Text(
                _daysUntilNextPeriod == 0
                    ? '🌸 Period expected today'
                    : '🗓 Next period in $_daysUntilNextPeriod days',
                style: TextStyle(
                    color: _phaseColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Cycle Calendar ────────────────────────────────────────────────────────

  Widget _buildCycleCalendar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildLegendDot('Period',    const Color(0xFFE53935)),
            _buildLegendDot('Follicular', const Color(0xFFEC407A)),
            _buildLegendDot('Ovulation', const Color(0xFFAB47BC)),
            _buildLegendDot('Luteal',    const Color(0xFF7E57C2)),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: List.generate(_cycleLength, (index) {
            final day       = index + 1;
            final color     = _dayColor(day);
            final isCurrent = day == _dayInCycle;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isCurrent ? 36 : 30,
              height: isCurrent ? 36 : 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrent ? color : color.withOpacity(0.2),
                border: Border.all(
                  color: isCurrent ? Colors.white : color.withOpacity(0.4),
                  width: isCurrent ? 2.5 : 1,
                ),
                boxShadow: isCurrent
                    ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)]
                    : [],
              ),
              child: Center(
                child: Text('$day',
                    style: TextStyle(
                        color: isCurrent ? Colors.white : color,
                        fontSize: isCurrent ? 13 : 11,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ),
            );
          }),
        ),
      ]),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(children: [
      Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ]);
  }

  // ── Quick Stats ───────────────────────────────────────────────────────────

  Widget _buildQuickStats() {
    return Row(children: [
      Expanded(child: _buildStatCard('Cycle Length', '$_cycleLength days',
          Icons.loop_rounded, const Color(0xFFEC407A))),
      const SizedBox(width: 12),
      Expanded(child: _buildStatCard('Period Length', '$_periodLength days',
          Icons.water_drop_rounded, const Color(0xFFE53935))),
      const SizedBox(width: 12),
      Expanded(child: _buildStatCard('Days Left', '$_daysUntilNextPeriod days',
          Icons.upcoming_rounded, const Color(0xFF7E57C2))),
    ]);
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 10),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text(title,
            style: const TextStyle(fontSize: 11, color: Colors.white38)),
      ]),
    );
  }

  // ── Period Control ────────────────────────────────────────────────────────

  Widget _buildPeriodControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Period Active',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
                Text(
                  _isPeriodActive
                      ? 'Tracking your period now — mood scans save separately'
                      : 'Tap to mark your period started',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPeriodActive,
            onChanged: (val) => setState(() {
              _isPeriodActive = val;
              if (val) _lastPeriodStart = DateTime.now();
            }),
            activeColor: const Color(0xFFE53935),
          ),
        ]),
        if (_isPeriodActive) ...[
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Flow Intensity',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _buildFlowChip(0, 'None',   '○'),
            const SizedBox(width: 8),
            _buildFlowChip(1, 'Light',  '🌧'),
            const SizedBox(width: 8),
            _buildFlowChip(2, 'Medium', '🌊'),
            const SizedBox(width: 8),
            _buildFlowChip(3, 'Heavy',  '🌊🌊'),
          ]),
        ],
      ]),
    );
  }

  Widget _buildFlowChip(int level, String label, String emoji) {
    final isSelected = _flowIntensity == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _flowIntensity = level),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFE53935)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isSelected
                    ? const Color(0xFFE53935)
                    : Colors.white12),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }

  // ── Symptoms Grid ─────────────────────────────────────────────────────────

  Widget _buildSymptomsGrid() {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: _symptoms.keys.map((symptom) {
        final isSelected = _symptoms[symptom]!;
        final icon       = _symptomIcons[symptom]!;
        return GestureDetector(
          onTap: () => setState(() => _symptoms[symptom] = !isSelected),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEC407A).withOpacity(0.2)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFEC407A)
                    : Colors.white12,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [const BoxShadow(color: Color(0x33EC407A), blurRadius: 8)]
                  : [],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? const Color(0xFFEC407A)
                      : Colors.white38),
              const SizedBox(width: 6),
              Text(symptom,
                  style: TextStyle(
                      color: isSelected
                          ? const Color(0xFFEC407A)
                          : Colors.white54,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── Cycle Settings ────────────────────────────────────────────────────────

  Widget _buildCycleSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: [
        _buildSettingSlider(
          'Cycle Length', _cycleLength.toDouble(), 21, 35,
          (val) => setState(() => _cycleLength = val.toInt()),
          const Color(0xFFEC407A), '$_cycleLength days',
        ),
        const SizedBox(height: 20),
        _buildSettingSlider(
          'Period Length', _periodLength.toDouble(), 2, 10,
          (val) => setState(() => _periodLength = val.toInt()),
          const Color(0xFFE53935), '$_periodLength days',
        ),
      ]),
    );
  }

  Widget _buildSettingSlider(
      String label, double value, double min, double max,
      Function(double) onChanged, Color color, String display) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w600)),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Text(display,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor:   color,
          inactiveTrackColor: color.withOpacity(0.1),
          thumbColor:         Colors.white,
          overlayColor:       color.withOpacity(0.2),
          trackHeight:        4,
        ),
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          onChanged: onChanged,
        ),
      ),
    ]);
  }

  // ── Save Button ───────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity, height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFEC407A), Color(0xFFAB47BC)],
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x55EC407A),
              blurRadius: 20,
              offset: Offset(0, 6)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.favorite_rounded, color: Colors.white),
        label: Text(_saving ? 'Saving...' : 'Save Tracker',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor:     Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _db.savePeriodData(_uid, {
      'cycleLength':     _cycleLength,
      'periodLength':    _periodLength,
      'isPeriodActive':  _isPeriodActive,
      'flowIntensity':   _flowIntensity,
      'lastPeriodStart': _lastPeriodStart.toIso8601String(),
      'symptoms':        _symptoms,
      'updatedAt':       DateTime.now().toIso8601String(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🌸 Period data saved!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFFEC407A),
      ),
    );
  }

  // ── Misc helpers ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Text(subtitle,
            style: const TextStyle(
                fontSize: 13, color: Colors.white38)),
      ],
    );
  }

  Color _dayColor(int day) {
    if (day <= _periodLength) return const Color(0xFFE53935);
    if (day <= 13) return const Color(0xFFEC407A);
    if (day <= 15) return const Color(0xFFAB47BC);
    return const Color(0xFF7E57C2);
  }

  Color _labelColor(String label) {
    const map = {
      'Happy':     Color(0xFFFFA726),
      'Calm':      Color(0xFF26A69A),
      'Excited':   Color(0xFFEC407A),
      'Focused':   Color(0xFF6C63FF),
      'Grateful':  Color(0xFFAB47BC),
      'Okay':      Color(0xFF78909C),
      'Tired':     Color(0xFF8D6E63),
      'Sad':       Color(0xFF42A5F5),
      'Stressed':  Color(0xFFEF5350),
      'Anxious':   Color(0xFFFF7043),
    };
    return map[label] ?? const Color(0xFF78909C);
  }

  String _labelEmoji(String label) {
    const map = {
      'Happy': '😊', 'Calm': '😌', 'Excited': '🤩',
      'Focused': '🧘', 'Grateful': '🙏', 'Okay': '😐',
      'Tired': '😴', 'Sad': '😔', 'Stressed': '😤', 'Anxious': '😰',
    };
    return map[label] ?? '😐';
  }
}
