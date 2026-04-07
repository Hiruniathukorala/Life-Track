import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── User Profile ──────────────────────────────────────────────────────────

  Future<void> createUserProfile(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).set(data);

  Stream<Map<String, dynamic>?> userProfileStream(String uid) =>
      _db.collection('users').doc(uid).snapshots().map((s) => s.data());

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).update(data);

  // ── Activity Logs ─────────────────────────────────────────────────────────

  Future<void> addLog(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).collection('logs').add({
        ...data,
        'timestamp': FieldValue.serverTimestamp(),
      });

  Stream<List<Map<String, dynamic>>> logsStream(String uid) =>
      _db.collection('users').doc(uid).collection('logs')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Future<void> deleteLog(String uid, String logId) =>
      _db.collection('users').doc(uid).collection('logs').doc(logId).delete();

  // ── Habits ────────────────────────────────────────────────────────────────

  Future<void> setHabitCompletion(String uid, String habit, String date, bool completed) =>
      _db.collection('users').doc(uid).collection('habits').doc('${habit}_$date').set({
        'habit': habit,
        'date': date,
        'completed': completed,
      });

  Stream<List<Map<String, dynamic>>> habitsForDateStream(String uid, String date) =>
      _db.collection('users').doc(uid).collection('habits')
          .where('date', isEqualTo: date)
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());

  // ── Family Members (linked real users) ───────────────────────────────────

  /// Look up another registered user by their email address.
  /// Returns {uid, name, email, totalPoints, currentStreak, ...} or null.
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    final snap = await _db.collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return {'uid': snap.docs.first.id, ...snap.docs.first.data()};
  }

  /// Store a family link: saves the linked user's UID + role under the
  /// current user's family subcollection. The linked user's live stats are
  /// read via [linkedUserProfileStream].
  Future<void> linkFamilyMember(String uid, String linkedUid, String role) =>
      _db.collection('users').doc(uid).collection('family').doc(linkedUid).set({
        'linkedUid': linkedUid,
        'role': role,
        'addedAt': FieldValue.serverTimestamp(),
      });

  /// Live stream of a linked user's root profile (requires Firestore rules
  /// to allow authenticated reads on /users/{userId}).
  Stream<Map<String, dynamic>?> linkedUserProfileStream(String linkedUid) =>
      _db.collection('users').doc(linkedUid).snapshots()
          .map((s) => s.exists ? {'uid': s.id, ...s.data()!} : null);

  /// Stream of family links for [uid]. Each item contains
  /// {id (=linkedUid), linkedUid, role, addedAt}.
  Stream<List<Map<String, dynamic>>> familyLinksStream(String uid) =>
      _db.collection('users').doc(uid).collection('family')
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  /// Legacy — kept for compatibility; new code uses [linkFamilyMember].
  Future<DocumentReference> addFamilyMember(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).collection('family').add(data);

  /// Legacy stream — new code uses [familyLinksStream].
  Stream<List<Map<String, dynamic>>> familyStream(String uid) =>
      familyLinksStream(uid);

  Future<void> updateFamilyMember(String uid, String memberId, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).collection('family').doc(memberId).update(data);

  Future<void> deleteFamilyMember(String uid, String memberId) =>
      _db.collection('users').doc(uid).collection('family').doc(memberId).delete();

  // ── Period Tracker ────────────────────────────────────────────────────────

  Future<void> savePeriodData(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).collection('period_tracker').doc('current').set(data);

  Stream<Map<String, dynamic>?> periodDataStream(String uid) =>
      _db.collection('users').doc(uid).collection('period_tracker').doc('current')
          .snapshots().map((s) => s.data());

  // ── Points & Streak helpers ───────────────────────────────────────────────

  Future<void> addPoints(String uid, int points) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    // Use set+merge so it works even if the document doesn't exist yet
    await _db.collection('users').doc(uid).set({
      'totalPoints': FieldValue.increment(points),
      'dailyPoints': FieldValue.increment(points),
      'lastActiveDate': today,
    }, SetOptions(merge: true));
  }

  // ── Mood Detection & Analysis ─────────────────────────────────────────────

  /// Save a mood entry every time the app opens (auto-ID, keeps full history).
  Future<void> saveMoodEntry(String uid, Map<String, dynamic> moodMap) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    // Update current mood in profile (for dashboard card)
    await _db.collection('users').doc(uid).set({
      'currentMood': moodMap,
      'lastMoodDate': today,
    }, SetOptions(merge: true));
    // Save individual entry with auto-ID so every check-in is stored
    await _db
        .collection('users')
        .doc(uid)
        .collection('moods')
        .add({...moodMap, 'date': today, 'capturedAt': FieldValue.serverTimestamp()});
  }

  /// Stream of the user's current mood (from their profile doc).
  Stream<Map<String, dynamic>?> currentMoodStream(String uid) =>
      _db.collection('users').doc(uid).snapshots().map((s) {
        if (!s.exists) return null;
        final data = s.data()!;
        final mood = data['currentMood'];
        return mood is Map ? Map<String, dynamic>.from(mood) : null;
      });

  /// Stream of all mood entries captured in the last 7 days.
  Stream<List<Map<String, dynamic>>> weeklyMoodsStream(String uid) {
    final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 7)));
    return _db
        .collection('users')
        .doc(uid)
        .collection('moods')
        .where('capturedAt', isGreaterThan: cutoff)
        .orderBy('capturedAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Stream of activity category counts (for Insights breakdown).
  Stream<Map<String, int>> categoryStatsStream(String uid) =>
      _db.collection('users').doc(uid).collection('logs').snapshots().map((s) {
        final counts = <String, int>{};
        for (final doc in s.docs) {
          final cat = doc.data()['category'] as String? ?? 'Other';
          counts[cat] = (counts[cat] ?? 0) + 1;
        }
        return counts;
      });

  /// Returns the label of the most recently saved mood entry, or null.
  Future<String?> getLastMoodLabel(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('moods')
        .orderBy('capturedAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['label'] as String?;
  }

  /// All logs without limit — used by achievements badge logic.
  Stream<List<Map<String, dynamic>>> allLogsStream(String uid) =>
      _db.collection('users').doc(uid).collection('logs')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  /// Total number of saved mood entries — for Wellness badges.
  Stream<int> moodCountStream(String uid) =>
      _db.collection('users').doc(uid).collection('moods').snapshots()
          .map((s) => s.docs.length);

  /// Permanently deletes all user activity data and resets stats to zero.
  Future<void> resetUserData(String uid) async {
    await _db.collection('users').doc(uid).update({
      'totalPoints': 0,
      'dailyPoints': 0,
      'currentStreak': 0,
      'lastActiveDate': FieldValue.delete(),
      'currentMood': FieldValue.delete(),
      'lastMoodDate': FieldValue.delete(),
    });
    for (final sub in ['logs', 'habits', 'moods', 'period_tracker', 'family']) {
      final snap = await _db.collection('users').doc(uid).collection(sub).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }
  }

  Future<void> updateStreak(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    // Guard: if the profile document doesn't exist yet, skip streak update
    if (!doc.exists || doc.data() == null) return;
    final data = doc.data()!;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastActive = data['lastActiveDate'] as String?;
    final yesterday = DateTime.now().subtract(const Duration(days: 1))
        .toIso8601String().substring(0, 10);

    int streak = data['currentStreak'] ?? 0;
    if (lastActive == yesterday) {
      streak += 1;
    } else if (lastActive != today) {
      streak = 1;
    }
    await _db.collection('users').doc(uid).set({
      'currentStreak': streak,
      'lastActiveDate': today,
    }, SetOptions(merge: true));
  }
}
