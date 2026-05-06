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

  int _cycleLength = 28;
  int _periodLength = 5;
  DateTime _lastPeriodStart = DateTime.now().subtract(const Duration(days: 14));
  bool _isPeriodActive = false;
  bool _saving = false;

  // Symptom state
  final Map<String, bool> _symptoms = {
    'Cramps': false,
    'Headache': false,
    'Bloating': false,
    'Fatigue': false,
    'Mood Swings': false,
    'Back Pain': false,
    'Nausea': false,
    'Spotting': false,
  };

  final Map<String, IconData> _symptomIcons = {
    'Cramps': Icons.bolt_rounded,
    'Headache': Icons.psychology_rounded,
    'Bloating': Icons.bubble_chart_rounded,
    'Fatigue': Icons.battery_2_bar_rounded,
    'Mood Swings': Icons.mood_rounded,
    'Back Pain': Icons.accessibility_new_rounded,
    'Nausea': Icons.sick_rounded,
    'Spotting': Icons.water_drop_rounded,
  };

  // Flow intensity
  int _flowIntensity = 0; // 0=none, 1=light, 2=medium, 3=heavy

  // Computed
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
      case 'Menstrual': return const Color(0xFFE53935);
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
        _cycleLength = (data['cycleLength'] as num?)?.toInt() ?? 28;
        _periodLength = (data['periodLength'] as num?)?.toInt() ?? 5;
        _isPeriodActive = data['isPeriodActive'] as bool? ?? false;
        _flowIntensity = (data['flowIntensity'] as num?)?.toInt() ?? 0;
        final savedStart = data['lastPeriodStart'] as String?;
        if (savedStart != null) {
          _lastPeriodStart =
              DateTime.tryParse(savedStart) ?? _lastPeriodStart;
        }
        final savedSymptoms = data['symptoms'] as Map<String, dynamic>?;
        if (savedSymptoms != null) {
          savedSymptoms.forEach((k, v) {
            if (_symptoms.containsKey(k)) _symptoms[k] = v as bool;
          });
        }
      });
    } else {
      // First launch — write defaults so the document exists in Firestore.
      await _db.savePeriodData(_uid, {
        'cycleLength': _cycleLength,
        'periodLength': _periodLength,
        'isPeriodActive': _isPeriodActive,
        'flowIntensity': _flowIntensity,
        'lastPeriodStart': _lastPeriodStart.toIso8601String(),
        'symptoms': _symptoms,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  double get _cycleProgress => (_dayInCycle - 1) / _cycleLength;

  Color _dayColor(int day) {
    if (day <= _periodLength) return const Color(0xFFE53935);
    if (day <= 13) return const Color(0xFFEC407A);
    if (day <= 15) return const Color(0xFFAB47BC);
    return const Color(0xFF7E57C2);
  }

  bool _isCurrentDay(int day) => day == _dayInCycle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Period Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
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

            // ── Phase Banner ────────────────────────────────────────────
            _buildPhaseBanner(),
            const SizedBox(height: 28),

            // ── 28-Day Cycle Calendar ────────────────────────────────────
            _buildSectionHeader('Cycle Calendar', 'Day $_dayInCycle of $_cycleLength'),
            const SizedBox(height: 16),
            _buildCycleCalendar(),
            const SizedBox(height: 28),

            // ── Quick Stats ──────────────────────────────────────────────
            _buildQuickStats(),
            const SizedBox(height: 28),

            // ── Period Toggle ────────────────────────────────────────────
            _buildSectionHeader('Period Status', 'Track your flow'),
            const SizedBox(height: 16),
            _buildPeriodControl(),
            const SizedBox(height: 28),

            // ── Symptoms ────────────────────────────────────────────────
            _buildSectionHeader('Symptoms', 'How are you feeling?'),
            const SizedBox(height: 16),
            _buildSymptomsGrid(),
            const SizedBox(height: 28),

            // ── Cycle Settings ───────────────────────────────────────────
            _buildSectionHeader('Cycle Settings', 'Customize your cycle'),
            const SizedBox(height: 16),
            _buildCycleSettings(),
            const SizedBox(height: 40),

            // ── Save Button ──────────────────────────────────────────────
            _buildSaveButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_phaseColor.withOpacity(0.3), _phaseColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _phaseColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          // Circular progress
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _cycleProgress,
                  strokeWidth: 8,
                  color: _phaseColor,
                  backgroundColor: _phaseColor.withOpacity(0.1),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_dayInCycle',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Text('day', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _phaseColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_currentPhase Phase',
                    style: TextStyle(color: _phaseColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _phaseDescription,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  _daysUntilNextPeriod == 0
                      ? '🌸 Period expected today'
                      : '🗓 Next period in $_daysUntilNextPeriod days',
                  style: TextStyle(color: _phaseColor, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleCalendar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          // Phase legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendDot('Period', const Color(0xFFE53935)),
              _buildLegendDot('Follicular', const Color(0xFFEC407A)),
              _buildLegendDot('Ovulation', const Color(0xFFAB47BC)),
              _buildLegendDot('Luteal', const Color(0xFF7E57C2)),
            ],
          ),
          const SizedBox(height: 16),
          // Day dots grid
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(_cycleLength, (index) {
              final day = index + 1;
              final color = _dayColor(day);
              final isCurrent = _isCurrentDay(day);
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
                  boxShadow: isCurrent ? [
                    BoxShadow(color: color.withOpacity(0.5), blurRadius: 10),
                  ] : [],
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isCurrent ? Colors.white : color,
                      fontSize: isCurrent ? 13 : 11,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Cycle Length', '$_cycleLength days', Icons.loop_rounded, const Color(0xFFEC407A))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Period Length', '$_periodLength days', Icons.water_drop_rounded, const Color(0xFFE53935))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Days Left', '$_daysUntilNextPeriod days', Icons.upcoming_rounded, const Color(0xFF7E57C2))),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildPeriodControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Period Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                    Text(
                      _isPeriodActive ? 'Tracking your period now' : 'Tap to mark period started',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
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
            ],
          ),
          if (_isPeriodActive) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Flow Intensity', style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildFlowChip(0, 'None', '○'),
                const SizedBox(width: 8),
                _buildFlowChip(1, 'Light', '🌧'),
                const SizedBox(width: 8),
                _buildFlowChip(2, 'Medium', '🌊'),
                const SizedBox(width: 8),
                _buildFlowChip(3, 'Heavy', '🌊🌊'),
              ],
            ),
          ],
        ],
      ),
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
            color: isSelected ? const Color(0xFFE53935) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? const Color(0xFFE53935) : Colors.white12),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymptomsGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _symptoms.keys.map((symptom) {
        final isSelected = _symptoms[symptom]!;
        final icon = _symptomIcons[symptom]!;
        return GestureDetector(
          onTap: () => setState(() => _symptoms[symptom] = !isSelected),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEC407A).withOpacity(0.2) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFFEC407A) : Colors.white12,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected ? [
                const BoxShadow(color: Color(0x33EC407A), blurRadius: 8),
              ] : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: isSelected ? const Color(0xFFEC407A) : Colors.white38),
                const SizedBox(width: 6),
                Text(
                  symptom,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFEC407A) : Colors.white54,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCycleSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _buildSettingSlider(
            'Cycle Length',
            _cycleLength.toDouble(),
            21,
            35,
            (val) => setState(() => _cycleLength = val.toInt()),
            const Color(0xFFEC407A),
            '${_cycleLength} days',
          ),
          const SizedBox(height: 20),
          _buildSettingSlider(
            'Period Length',
            _periodLength.toDouble(),
            2,
            10,
            (val) => setState(() => _periodLength = val.toInt()),
            const Color(0xFFE53935),
            '${_periodLength} days',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSlider(String label, double value, double min, double max, Function(double) onChanged, Color color, String display) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Text(display, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.1),
            thumbColor: Colors.white,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(value: value, min: min, max: max, divisions: (max - min).toInt(), onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFEC407A), Color(0xFFAB47BC)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x55EC407A), blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: ElevatedButton.icon(
        onPressed: _saving ? null : () async {
          setState(() => _saving = true);
          await _db.savePeriodData(_uid, {
            'cycleLength': _cycleLength,
            'periodLength': _periodLength,
            'isPeriodActive': _isPeriodActive,
            'flowIntensity': _flowIntensity,
            'lastPeriodStart': _lastPeriodStart.toIso8601String(),
            'symptoms': _symptoms,
            'updatedAt': DateTime.now().toIso8601String(),
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
        },
        icon: _saving
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.favorite_rounded, color: Colors.white),
        label: Text(_saving ? 'Saving...' : 'Save Tracker',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white38)),
      ],
    );
  }
}
