import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import '../models/mood_result.dart';

/// On-device face analysis using Google ML Kit.
/// No internet connection or API key required — runs fully offline.
class FaceMoodService {
  static final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // gives smile + eye-open probabilities
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  /// Analyse [imageBytes] (JPEG) and return a MoodResult based on facial features.
  Future<MoodResult?> detectFromFace(Uint8List imageBytes) async {
    File? tempFile;
    try {
      // ML Kit needs a file path for JPEG input
      final dir = await getTemporaryDirectory();
      tempFile = File('${dir.path}/face_scan_tmp.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final faces      = await _detector.processImage(inputImage);

      if (faces.isEmpty) {
        debugPrint('[FaceMood] No face detected');
        return null;
      }

      // Pick the largest face (closest to camera)
      final face = faces.reduce(
          (a, b) => a.boundingBox.width > b.boundingBox.width ? a : b);

      final smile    = face.smilingProbability       ?? 0.5;
      final leftEye  = face.leftEyeOpenProbability   ?? 0.8;
      final rightEye = face.rightEyeOpenProbability  ?? 0.8;
      final avgEye   = (leftEye + rightEye) / 2;

      debugPrint('[FaceMood] smile=${smile.toStringAsFixed(2)} '
          'eye=${avgEye.toStringAsFixed(2)}');

      final label      = _classifyMood(smile, avgEye);
      final confidence = _confidence(label, smile, avgEye);
      final desc       = _buildDescription(label, smile, avgEye);
      final sugg       = _buildSuggestions(label);

      return MoodResult.fromLabel(
        label,
        description: desc,
        confidence:  confidence,
        detectedFrom: 'ai_face',
        suggestions: sugg,
      );
    } catch (e) {
      debugPrint('[FaceMood] Error: $e');
      return null;
    } finally {
      try { await tempFile?.delete(); } catch (_) {}
    }
  }

  // ── Mood classification ──────────────────────────────────────────────────

  String _classifyMood(double smile, double eye) {
    if (smile > 0.80 && eye > 0.70) return 'Excited';
    if (smile > 0.65)               return 'Happy';
    if (smile > 0.45 && eye > 0.65) return 'Calm';
    if (smile > 0.40)               return 'Grateful';
    if (eye   < 0.40)               return 'Tired';
    if (eye   < 0.52)               return 'Tired';
    if (smile < 0.15 && eye > 0.70) return 'Focused';
    if (smile < 0.20 && eye > 0.55) return 'Stressed';
    if (smile < 0.20)               return 'Sad';
    return 'Okay';
  }

  double _confidence(String mood, double smile, double eye) {
    return switch (mood) {
      'Excited'  => ((smile - 0.80) / 0.20 + (eye - 0.70) / 0.30).clamp(0.72, 0.96),
      'Happy'    => smile.clamp(0.68, 0.92),
      'Tired'    => ((1 - eye) / 0.5).clamp(0.65, 0.91),
      'Focused'  => ((1 - smile) * 0.8).clamp(0.64, 0.88),
      'Stressed' => ((1 - smile) * 0.7).clamp(0.60, 0.85),
      'Sad'      => ((1 - smile) * 0.75).clamp(0.60, 0.86),
      'Calm'     => 0.74,
      _          => 0.65,
    };
  }

  // ── Description builder ──────────────────────────────────────────────────

  String _buildDescription(String mood, double smile, double eye) {
    final smilePct = (smile * 100).round();
    final eyePct   = (eye   * 100).round();
    return switch (mood) {
      'Excited'  => 'Your big smile ($smilePct%) and bright open eyes say you\'re absolutely thrilled right now!',
      'Happy'    => 'Your face is showing a genuine smile ($smilePct%) — you\'re in a great mood! Keep that energy going.',
      'Calm'     => 'A soft smile and relaxed expression — you look peaceful and grounded.',
      'Grateful' => 'Your expression reads warm and content. You look like someone who appreciates what\'s around them.',
      'Tired'    => 'Your eyes look a little heavy ($eyePct% open) — your face is showing fatigue. Rest up!',
      'Focused'  => 'Steady, neutral expression with wide-open eyes ($eyePct%) — you look locked in.',
      'Stressed' => 'Your expression looks a little tense. Take a breath — you\'ve got this.',
      'Sad'      => 'Your expression looks downcast. It\'s okay not to be okay — be kind to yourself.',
      _          => 'Your expression looks steady and balanced today.',
    };
  }

  // ── Suggestions ──────────────────────────────────────────────────────────

  List<String> _buildSuggestions(String mood) {
    return switch (mood) {
      'Excited'  => ['Channel this energy into your top priority', 'Share your excitement with someone', 'Set a bold new goal while you feel this way'],
      'Happy'    => ['Write down what made you happy today', 'Share your good mood with someone you love', 'Set a challenge goal while feeling great'],
      'Calm'     => ['Use this calm to plan your week ahead', 'Try 5 minutes of journaling', 'Enjoy a slow mindful break'],
      'Grateful' => ['Write 3 things you\'re thankful for', 'Send a kind message to someone', 'Reflect on how far you\'ve come'],
      'Tired'    => ['Take a short 10-minute power nap', 'Drink water — dehydration drains energy', 'Do light stretching to wake up'],
      'Focused'  => ['Block distractions for 30 minutes', 'Tackle your hardest task now', 'Review your goals and adjust if needed'],
      'Stressed' => ['Take 5 slow deep breaths right now', 'Write worries down, pick one to solve', 'Break your to-do list into smaller steps'],
      'Sad'      => ['Reach out to someone you trust', 'Go outside for 5 minutes of fresh air', 'Be kind to yourself — rest counts'],
      _          => ['Do one thing that usually lifts your mood', 'Take a 5-minute break outside', 'Check off one habit to build momentum'],
    };
  }
}
