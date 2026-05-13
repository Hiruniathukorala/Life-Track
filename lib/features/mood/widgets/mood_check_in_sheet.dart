import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/mood_result.dart';
import '../services/mood_ai_service.dart';
import '../services/face_mood_service.dart';
import '../../../core/services/firestore_service.dart';

/// Opens the front camera inside the bottom sheet, scans the user's face,
/// and sends the selfie to Gemini Vision for emotion detection.
class MoodCheckInSheet extends StatefulWidget {
  const MoodCheckInSheet({super.key});

  @override
  State<MoodCheckInSheet> createState() => _MoodCheckInSheetState();

  /// Shows the mood scan sheet every time the app opens.
  /// Manual tap from mood card uses [force] = true (same behaviour, kept for API compat).
  static Future<void> showIfNeeded(BuildContext context,
      {bool force = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // If the user has never completed their profile (no name set), silently
    // skip the scan on auto-trigger — the AI would have no context and the
    // result would be meaningless.  Manual taps (force = true) always show.
    if (!force) {
      final db      = FirestoreService();
      final profile = await db.userProfileStream(uid).first;
      final name    = profile?['name'] as String?;
      if (name == null || name.trim().isEmpty) return;
    }

    // No cooldown — scan fires on every app open so the user always gets a
    // fresh mood reading.  The Firestore save in _saveMood() still writes
    // lastMoodDate so the history / insights pages have accurate data.
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => const MoodCheckInSheet(),
    );
  }
}

// ── Internal types ────────────────────────────────────────────────────────────

class _Step {
  final String label;
  _StepState state;
  _Step(this.label, {this.state = _StepState.pending});
}

enum _StepState { pending, running, done }
enum _Phase { scanning, detecting, result }

// ── State ─────────────────────────────────────────────────────────────────────

class _MoodCheckInSheetState extends State<MoodCheckInSheet>
    with TickerProviderStateMixin {

  _Phase _phase = _Phase.scanning;
  MoodResult? _result;
  bool _showPicker = false;
  bool _saving = false;
  int _countdown = 10;
  bool _flashVisible = false;

  // Camera
  CameraController? _cameraController;
  bool _cameraReady = false;
  Uint8List? _faceBytes;

  // Services
  final _textCtrl = TextEditingController();
  final _db       = FirestoreService();
  final _ai       = MoodAiService();
  final _faceAi   = FaceMoodService();

  // Animations
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  late final AnimationController _scanCtrl;
  late final Animation<double>   _scanAnim;

  Timer? _dismissTimer;
  UserContext? _ctx;

  late final List<_Step> _steps = [
    _Step('Reading your facial expression'),
    _Step('Loading profile, streak & habits'),
    _Step('AI finalising your mood result'),
  ];

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.93, end: 1.07)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _scanAnim = Tween<double>(begin: 0.05, end: 0.95)
        .animate(CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut));

    _startFaceScan();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    _textCtrl.dispose();
    _dismissTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ── Face scanning ─────────────────────────────────────────────────────────

  Future<void> _startFaceScan() async {
    Uint8List? captured;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No cameras found');

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);

      // Give user 2.5 s to centre their face while scan line runs
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return;

      // Shutter flash
      setState(() => _flashVisible = true);
      await Future.delayed(const Duration(milliseconds: 110));
      if (mounted) setState(() => _flashVisible = false);

      // Capture
      final xFile = await _cameraController!.takePicture();
      captured = await xFile.readAsBytes();
    } catch (e) {
      debugPrint('[Camera] $e');
    } finally {
      // Set _cameraReady = false BEFORE disposing so Flutter's next frame
      // renders the fallback container instead of CameraPreview on a dead controller.
      if (mounted) setState(() => _cameraReady = false);
      await _cameraController?.dispose();
      _cameraController = null;
    }

    _faceBytes = captured;
    if (mounted) _runDetection();
  }

  // ── Detection ─────────────────────────────────────────────────────────────

  Future<void> _runDetection({String? userText}) async {
    for (final s in _steps) s.state = _StepState.pending;
    if (mounted) setState(() => _phase = _Phase.detecting);

    // Step 0 — face AI
    _advanceStep(0);
    MoodResult? faceResult;
    if (_faceBytes != null && userText == null) {
      faceResult = await _faceAi.detectFromFace(_faceBytes!);
    }
    _completeStep(0);

    // Step 1 — profile + habits
    _advanceStep(1);
    final profile = await _db.userProfileStream(_uid).first;
    final p = profile ?? {};
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final habits = await _db.habitsForDateStream(_uid, today).first;
    final habitsCompleted = habits.where((h) => h['completed'] == true).length;
    _completeStep(1);

    // Step 2 — context AI / text fallback
    _advanceStep(2);
    final streak   = (p['currentStreak'] as int?) ?? 0;
    final dailyPts = (p['dailyPoints']   as int?) ?? 0;
    final prevMood = await _db.getLastMoodLabel(_uid);

    _ctx = UserContext(
      name:              p['name']       as String?,
      age:               p['age']        as int?,
      gender:            p['gender']     as String?,
      profession:        p['profession'] as String?,
      healthConditions:  p['diseases']   as String?,
      currentStreak:     streak,
      dailyPoints:       dailyPts,
      habitsCompleted:   habitsCompleted,
      totalHabits:       4,
      previousMoodLabel: prevMood,
      userText:          userText,
    );

    MoodResult result;
    if (faceResult != null) {
      result = faceResult;
    } else {
      try {
        result = await _ai.detectMood(_ctx!);
      } catch (_) {
        result = MoodResult.fromLabel(
          'Okay',
          description: 'Could not fully analyse your mood right now.',
          confidence: 0.5,
          suggestions: [
            'Take a deep breath and check in with yourself',
            'Log one habit to start your day right',
            'Drink a glass of water right now',
          ],
        );
      }
    }
    _completeStep(2);

    if (!mounted) return;
    setState(() {
      _result    = result;
      _phase     = _Phase.result;
      _countdown = 10;
    });
    _startCountdown();
  }

  void _advanceStep(int i) {
    if (!mounted) return;
    setState(() => _steps[i].state = _StepState.running);
  }

  void _completeStep(int i) {
    if (!mounted) return;
    setState(() => _steps[i].state = _StepState.done);
  }

  void _startCountdown() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) { t.cancel(); _saveMood(_result!); }
    });
  }

  Future<void> _saveMood(MoodResult mood) async {
    if (!mounted) return;
    _dismissTimer?.cancel();
    setState(() => _saving = true);
    try {
      // Always save to normal moods collection
      await _db.saveMoodEntry(_uid, mood.toMap());

      // If period is currently active → also save to period_moods
      final periodData = await _db.periodDataStream(_uid).first;
      if (periodData != null && periodData['isPeriodActive'] == true) {
        final cycleDay = _computeCycleDay(periodData);
        final symptoms = (periodData['symptoms'] as Map<String, dynamic>?)
                ?.entries
                .where((e) => e.value == true)
                .map((e) => e.key)
                .toList() ??
            [];
        await _db.savePeriodMoodEntry(_uid, mood.toMap(), {
          'cycleDay':      cycleDay,
          'flowIntensity': periodData['flowIntensity'] ?? 0,
          'symptoms':      symptoms,
          'phase':         _phaseFromCycleDay(
              cycleDay, (periodData['periodLength'] as num?)?.toInt() ?? 5),
        });
      }
    } catch (e) {
      debugPrint('[MoodSheet] save error: $e');
    }
    if (mounted) Navigator.pop(context);
  }

  int _computeCycleDay(Map<String, dynamic> periodData) {
    final startStr    = periodData['lastPeriodStart'] as String?;
    final cycleLength = (periodData['cycleLength'] as num?)?.toInt() ?? 28;
    if (startStr == null) return 1;
    final start = DateTime.tryParse(startStr) ?? DateTime.now();
    final diff  = DateTime.now().difference(start).inDays;
    return (diff % cycleLength) + 1;
  }

  String _phaseFromCycleDay(int day, int periodLength) {
    if (day <= periodLength) return 'Menstrual';
    if (day <= 13) return 'Follicular';
    if (day <= 15) return 'Ovulation';
    return 'Luteal';
  }

  Future<void> _refineWithText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _dismissTimer?.cancel();
    await _runDetection(userText: text);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.face_retouching_natural_rounded,
                  color: Color(0xFF6C63FF), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Face Mood Scan',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 17)),
                Text('Gemini Vision · reads your expression',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white38, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          const SizedBox(height: 14),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                    begin: const Offset(0, 0.06), end: Offset.zero)
                    .animate(anim),
                child: child,
              ),
            ),
            child: switch (_phase) {
              _Phase.scanning  => _buildScanning(),
              _Phase.detecting => _buildDetecting(),
              _Phase.result    => _buildResult(),
            },
          ),
        ],
      ),
    );
  }

  // ── Scanning phase ────────────────────────────────────────────────────────

  Widget _buildScanning() {
    return SizedBox(
      key: const ValueKey('scanning'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _scanAnim,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                // Camera preview or placeholder
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    width: double.infinity,
                    height: 290,
                    child: _cameraReady && _cameraController != null
                        ? CameraPreview(_cameraController!)
                        : Container(
                            color: const Color(0xFF1A1A2E),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 32, height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation(
                                        Color(0xFF6C63FF)),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text('Opening camera…',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.45),
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                  ),
                ),
                // Oval guide + scan line overlay
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    width: double.infinity,
                    height: 290,
                    child: CustomPaint(
                      painter: _FaceOverlayPainter(
                        scanProgress: _cameraReady ? _scanAnim.value : -1,
                      ),
                    ),
                  ),
                ),
                // Shutter flash
                if (_flashVisible)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: double.infinity,
                      height: 290,
                      color: Colors.white.withOpacity(0.55),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: Text(
              _cameraReady
                  ? 'Hold still…  scanning your expression'
                  : 'Opening front camera…',
              key: ValueKey(_cameraReady),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _cameraReady ? 'Keep your face centred in the oval' : '',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Detecting phase ───────────────────────────────────────────────────────

  Widget _buildDetecting() {
    return SizedBox(
      key: const ValueKey('detecting'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C63FF).withOpacity(0.10),
                border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.30), width: 2),
              ),
              child: const Center(
                child: SizedBox(
                  width: 30, height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Processing your mood…',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          ...List.generate(_steps.length, (i) => _buildStepRow(_steps[i])),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStepRow(_Step step) {
    Widget leading;
    Color color;
    switch (step.state) {
      case _StepState.done:
        leading = const Icon(Icons.check_circle_rounded,
            size: 18, color: Color(0xFF66BB6A));
        color = Colors.white60;
      case _StepState.running:
        leading = const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Color(0xFF6C63FF))),
        );
        color = Colors.white;
      case _StepState.pending:
        leading = const Icon(Icons.radio_button_unchecked_rounded,
            size: 18, color: Colors.white24);
        color = Colors.white30;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        leading,
        const SizedBox(width: 12),
        Text(step.label,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: step.state == _StepState.running
                    ? FontWeight.w600 : FontWeight.normal)),
      ]),
    );
  }

  // ── Result phase ──────────────────────────────────────────────────────────

  Widget _buildResult() {
    final mood = _result!;
    return SizedBox(
      key: const ValueKey('result'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: mood.color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: mood.color.withOpacity(0.28)),
            ),
            child: Column(children: [
              ScaleTransition(
                scale: _pulseAnim,
                child: Text(mood.emoji,
                    style: const TextStyle(fontSize: 54)),
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(mood.label,
                    style: TextStyle(
                        color: mood.color,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: mood.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${(mood.confidence * 100).round()}% match',
                      style: TextStyle(
                          color: mood.color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(mood.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 13, height: 1.5)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  switch (mood.detectedFrom) {
                    'ai_face'   => Icons.face_retouching_natural_rounded,
                    'ai_gemini' => Icons.auto_awesome_rounded,
                    _           => Icons.analytics_rounded,
                  },
                  size: 11, color: Colors.white24,
                ),
                const SizedBox(width: 4),
                Text(
                  switch (mood.detectedFrom) {
                    'ai_face'   => 'Detected from your face · Gemini Vision',
                    'ai_gemini' => 'Detected by Gemini AI',
                    _           => 'Detected by smart analysis',
                  },
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 10)),
              ]),
            ]),
          ),

          if (mood.suggestions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.lightbulb_rounded,
                        size: 15, color: mood.color.withOpacity(0.8)),
                    const SizedBox(width: 6),
                    Text('Personalised Tips',
                        style: TextStyle(
                            color: mood.color.withOpacity(0.9),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ]),
                  const SizedBox(height: 10),
                  ...mood.suggestions.map((tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                              color: mood.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(tip,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          if (!_showPicker) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(children: [
                const Icon(Icons.edit_rounded,
                    size: 15, color: Colors.white38),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Tell the AI how you actually feel…',
                      hintStyle: TextStyle(
                          color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _refineWithText(),
                  ),
                ),
                if (_textCtrl.text.isNotEmpty)
                  GestureDetector(
                    onTap: _refineWithText,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.send_rounded,
                          size: 14, color: Color(0xFF6C63FF)),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          if (_showPicker) _buildMoodPicker(),

          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _dismissTimer?.cancel();
                  setState(() => _showPicker = !_showPicker);
                },
                icon: Icon(
                    _showPicker
                        ? Icons.close_rounded
                        : Icons.swap_horiz_rounded,
                    size: 16),
                label: Text(_showPicker ? 'Cancel' : 'Change mood'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white12),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saving ? null : () => _saveMood(_result!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mood.color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text("That's me! (${_countdown}s)",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Mood picker ───────────────────────────────────────────────────────────

  Widget _buildMoodPicker() {
    const moods = [
      ('😊', 'Happy'),    ('😌', 'Calm'),      ('🤩', 'Excited'),
      ('🧘', 'Focused'),  ('💪', 'Motivated'), ('⚡', 'Energetic'),
      ('🙏', 'Grateful'), ('😐', 'Okay'),      ('😴', 'Tired'),
      ('😔', 'Sad'),      ('😤', 'Stressed'),  ('😰', 'Anxious'),
    ];
    return Column(children: [
      const Text('Pick your actual mood:',
          style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: moods.map((m) {
          final isSelected = _result?.label == m.$2;
          final ref = MoodResult.fromLabel(m.$2);
          return GestureDetector(
            onTap: () {
              _dismissTimer?.cancel();
              setState(() {
                _result     = MoodResult.fromLabel(m.$2,
                    confidence: 1.0,
                    detectedFrom: 'user_selected',
                    suggestions: _result?.suggestions ?? []);
                _showPicker = false;
                _countdown  = 10;
              });
              _startCountdown();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? ref.color.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected
                        ? ref.color.withOpacity(0.5)
                        : Colors.white12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(m.$1, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(m.$2,
                    style: TextStyle(
                        color: isSelected ? ref.color : Colors.white54,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold : FontWeight.normal)),
              ]),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
    ]);
  }
}

// ── Face guide overlay painter ────────────────────────────────────────────────

class _FaceOverlayPainter extends CustomPainter {
  final double scanProgress; // -1 = not ready, 0.0–1.0 = scan position

  const _FaceOverlayPainter({required this.scanProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width  * 0.30;
    final ry = size.height * 0.41;

    final ovalRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    );

    // Dark vignette outside oval
    final vignette = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(vignette, Paint()..color = Colors.black.withOpacity(0.48));

    // Oval border glow
    canvas.drawOval(ovalRect,
        Paint()
          ..color = const Color(0xFF6C63FF).withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawOval(ovalRect,
        Paint()
          ..color = const Color(0xFF8880FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);

    // Corner brackets
    final bp = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const bl = 20.0;
    for (final (x, y, dx, dy) in [
      (ovalRect.left,  ovalRect.top,     1,  1),
      (ovalRect.right, ovalRect.top,    -1,  1),
      (ovalRect.left,  ovalRect.bottom,  1, -1),
      (ovalRect.right, ovalRect.bottom, -1, -1),
    ]) {
      final o = Offset(x, y);
      canvas.drawLine(o, o + Offset(dx * bl, 0), bp);
      canvas.drawLine(o, o + Offset(0, dy * bl), bp);
    }

    // Animated scan line
    if (scanProgress >= 0) {
      final scanY = ovalRect.top + ovalRect.height * scanProgress;
      final dy = scanY - cy;
      if (dy.abs() < ry) {
        final hw = rx * math.sqrt(1 - (dy * dy) / (ry * ry));
        canvas.drawLine(Offset(cx - hw + 2, scanY), Offset(cx + hw - 2, scanY),
            Paint()
              ..color = const Color(0xFF6C63FF).withOpacity(0.45)
              ..strokeWidth = 8
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        canvas.drawLine(Offset(cx - hw + 2, scanY), Offset(cx + hw - 2, scanY),
            Paint()
              ..color = const Color(0xFFB0A8FF).withOpacity(0.9)
              ..strokeWidth = 1.6);
      }
    }
  }

  @override
  bool shouldRepaint(_FaceOverlayPainter old) =>
      old.scanProgress != scanProgress;
}
