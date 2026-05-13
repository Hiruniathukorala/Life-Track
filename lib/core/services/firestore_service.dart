import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── User Profile ──────────────────────────────────────────────────────────

  Future<void> createUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data);
    // Mirror email → uid in a public lookup collection so family invite search
    // never needs to scan the restricted users collection.
    final email = data['email'] as String?;
    if (email != null && email.isNotEmpty) {
      await _db.collection('userEmails').doc(email.toLowerCase()).set(
          {'uid': uid}, SetOptions(merge: true));
    }
  }

  Stream<Map<String, dynamic>?> userProfileStream(String uid) =>
      _db.collection('users').doc(uid).snapshots().map((s) => s.data());

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
    final email = data['email'] as String?;
    if (email != null && email.isNotEmpty) {
      await _db.collection('userEmails').doc(email.toLowerCase()).set(
          {'uid': uid}, SetOptions(merge: true));
    }
  }

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

  Future<void> setHabitCompletion(
      String uid, String habit, String date, bool completed) =>
      _db.collection('users').doc(uid).collection('habits')
          .doc('${habit}_$date').set({
        'habit': habit,
        'date': date,
        'completed': completed,
      });

  Stream<List<Map<String, dynamic>>> habitsForDateStream(
      String uid, String date) =>
      _db.collection('users').doc(uid).collection('habits')
          .where('date', isEqualTo: date)
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());

  // ── Habit Alarms ──────────────────────────────────────────────────────────

  /// Save or update a daily reminder time for a habit.
  /// [hour] and [minute] are in 24-hour format.
  Future<void> saveHabitAlarm(
      String uid, String habit, int hour, int minute) =>
      _db.collection('users').doc(uid).collection('habit_alarms')
          .doc(habit).set({
        'habit': habit,
        'hour': hour,
        'minute': minute,
        'enabled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteHabitAlarm(String uid, String habit) =>
      _db.collection('users').doc(uid).collection('habit_alarms')
          .doc(habit).delete();

  Stream<List<Map<String, dynamic>>> habitAlarmsStream(String uid) =>
      _db.collection('users').doc(uid).collection('habit_alarms')
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());

  // ── Family Members ────────────────────────────────────────────────────────

  /// Looks up a user by email.
  /// 1. Tries the fast /userEmails lookup first (O(1)).
  /// 2. Falls back to a /users collection query for accounts that pre-date
  ///    the userEmails collection (they haven't logged in since the migration).
  ///    On a successful fallback it back-fills userEmails so the next lookup
  ///    is instant.
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    final normalised = email.trim().toLowerCase();

    // ── Fast path ──────────────────────────────────────────────────────────
    final emailDoc = await _db.collection('userEmails').doc(normalised).get();
    if (emailDoc.exists) {
      final uid = emailDoc.data()?['uid'] as String?;
      if (uid != null) return {'uid': uid};
    }

    // ── Fallback: scan /users (works now that rules allow authenticated reads)
    final snap = await _db.collection('users')
        .where('email', isEqualTo: normalised)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;

    final uid = snap.docs.first.id;

    // Best-effort back-fill — ignored if rules haven't been updated yet.
    try {
      await _db.collection('userEmails').doc(normalised)
          .set({'uid': uid}, SetOptions(merge: true));
    } catch (_) {}

    return {'uid': uid};
  }

  /// One-way link (legacy). New code uses [sendFamilyInvite].
  Future<void> linkFamilyMember(
      String uid, String linkedUid, String role) =>
      _db.collection('users').doc(uid).collection('family').doc(linkedUid)
          .set({
        'linkedUid': linkedUid,
        'role': role,
        'addedAt': FieldValue.serverTimestamp(),
      });

  Stream<Map<String, dynamic>?> linkedUserProfileStream(String linkedUid) =>
      _db.collection('users').doc(linkedUid).snapshots()
          .map((s) => s.exists ? {'uid': s.id, ...s.data()!} : null);

  Stream<List<Map<String, dynamic>>> familyLinksStream(String uid) =>
      _db.collection('users').doc(uid).collection('family')
          .snapshots()
          .map((s) => s.docs
              .map((d) => {'id': d.id, ...d.data()}).toList());

  Future<DocumentReference> addFamilyMember(
      String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).collection('family').add(data);

  Stream<List<Map<String, dynamic>>> familyStream(String uid) =>
      familyLinksStream(uid);

  Future<void> updateFamilyMember(
      String uid, String memberId, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).collection('family')
          .doc(memberId).update(data);

  Future<void> deleteFamilyMember(String uid, String memberId) =>
      _db.collection('users').doc(uid).collection('family')
          .doc(memberId).delete();

  // ── Family Invites ────────────────────────────────────────────────────────

  /// Send an invite to [toUid].
  /// Writes to the TOP-LEVEL /invites collection so the sender only needs
  /// write permission on their own uid — no cross-user subcollection write.
  Future<void> sendFamilyInvite({
    required String fromUid,
    required String toUid,
    required String role,
  }) async {
    final fromDoc  = await _db.collection('users').doc(fromUid).get();
    final fromData = fromDoc.data() ?? {};
    final fromName  = fromData['name']  as String? ?? 'A LifeTrack user';
    final fromEmail = fromData['email'] as String? ?? '';

    // Deterministic doc ID prevents duplicate invites from the same person.
    final inviteId = '${fromUid}_$toUid';
    await _db.collection('invites').doc(inviteId).set({
      'fromUid':   fromUid,
      'fromName':  fromName,
      'fromEmail': fromEmail,
      'toUid':     toUid,
      'role':      role,
      'sentAt':    FieldValue.serverTimestamp(),
      'status':    'pending',
    });
  }

  /// Stream of pending invites addressed to [uid].
  /// Reads from the top-level /invites collection filtered by toUid.
  Stream<List<Map<String, dynamic>>> pendingInvitesStream(String uid) =>
      _db.collection('invites')
          .where('toUid',  isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((s) => s.docs
              .map((d) => {'id': d.id, ...d.data()}).toList());

  /// Accept an invite: creates mutual family links, deletes the invite.
  Future<void> acceptFamilyInvite({
    required String myUid,
    required String fromUid,
    required String role,
  }) async {
    final batch = _db.batch();
    final now   = FieldValue.serverTimestamp();

    batch.set(
      _db.collection('users').doc(myUid).collection('family').doc(fromUid),
      {'linkedUid': fromUid, 'role': role, 'addedAt': now},
    );
    batch.set(
      _db.collection('users').doc(fromUid).collection('family').doc(myUid),
      {'linkedUid': myUid, 'role': role, 'addedAt': now},
    );
    // Delete from top-level invites collection (new location)
    batch.delete(
      _db.collection('invites').doc('${fromUid}_$myUid'),
    );
    await batch.commit();
  }

  /// Decline an invite — deletes from top-level invites collection.
  Future<void> declineFamilyInvite({
    required String myUid,
    required String fromUid,
  }) =>
      _db.collection('invites').doc('${fromUid}_$myUid').delete();

  // ── Period Tracker ────────────────────────────────────────────────────────

  Future<void> savePeriodData(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).collection('period_tracker')
          .doc('current').set(data);

  Stream<Map<String, dynamic>?> periodDataStream(String uid) =>
      _db.collection('users').doc(uid).collection('period_tracker')
          .doc('current')
          .snapshots().map((s) => s.data());

  // ── Period Mood Storage ───────────────────────────────────────────────────

  /// Save a mood entry specifically during an active period.
  /// [extraFields] must include cycleDay, flowIntensity, symptoms.
  Future<void> savePeriodMoodEntry(
      String uid, Map<String, dynamic> moodMap, Map<String, dynamic> extraFields) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _db.collection('users').doc(uid).collection('period_moods').add({
      ...moodMap,
      ...extraFields,
      'date': today,
      'capturedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of mood entries from the current period (since [periodStartDate]).
  Stream<List<Map<String, dynamic>>> periodMoodsThisPeriodStream(
      String uid, String periodStartDate) {
    return _db.collection('users').doc(uid).collection('period_moods')
        .where('date', isGreaterThanOrEqualTo: periodStartDate)
        .orderBy('date', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// All period mood entries ever — used for cross-period pattern detection.
  Stream<List<Map<String, dynamic>>> allPeriodMoodsStream(String uid) =>
      _db.collection('users').doc(uid).collection('period_moods')
          .orderBy('capturedAt', descending: false)
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  // ── Points & Streak ───────────────────────────────────────────────────────

  Future<void> addPoints(String uid, int points) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _db.collection('users').doc(uid).set({
      'totalPoints': FieldValue.increment(points),
      'dailyPoints': FieldValue.increment(points),
      'lastActiveDate': today,
    }, SetOptions(merge: true));
  }

  Future<void> updateStreak(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return;
    final data  = doc.data()!;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastActive = data['lastActiveDate'] as String?;
    final yesterday  = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    int streak = data['currentStreak'] ?? 0;
    final Map<String, dynamic> update = {};

    if (lastActive == yesterday) {
      streak += 1;
    } else if (lastActive != today) {
      streak = 1;
    }

    update['currentStreak']  = streak;
    update['lastActiveDate'] = today;

    // Reset dailyPoints at start of a new day
    if (lastActive != null && lastActive != today) {
      update['dailyPoints'] = 0;
    }

    await _db.collection('users').doc(uid)
        .set(update, SetOptions(merge: true));
  }

  // ── Mood Detection & Analysis ─────────────────────────────────────────────

  Future<void> saveMoodEntry(String uid, Map<String, dynamic> moodMap) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _db.collection('users').doc(uid).set({
      'currentMood':  moodMap,
      'lastMoodDate': today,
    }, SetOptions(merge: true));
    await _db.collection('users').doc(uid).collection('moods').add({
      ...moodMap,
      'date': today,
      'capturedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<Map<String, dynamic>?> currentMoodStream(String uid) =>
      _db.collection('users').doc(uid).snapshots().map((s) {
        if (!s.exists) return null;
        final data = s.data()!;
        final mood = data['currentMood'];
        return mood is Map ? Map<String, dynamic>.from(mood) : null;
      });

  Stream<List<Map<String, dynamic>>> weeklyMoodsStream(String uid) {
    final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 7)));
    return _db.collection('users').doc(uid).collection('moods')
        .where('capturedAt', isGreaterThan: cutoff)
        .orderBy('capturedAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Stream<Map<String, int>> categoryStatsStream(String uid) =>
      _db.collection('users').doc(uid).collection('logs').snapshots().map((s) {
        final counts = <String, int>{};
        for (final doc in s.docs) {
          final cat = doc.data()['category'] as String? ?? 'Other';
          counts[cat] = (counts[cat] ?? 0) + 1;
        }
        return counts;
      });

  Future<String?> getLastMoodLabel(String uid) async {
    final snap = await _db.collection('users').doc(uid).collection('moods')
        .orderBy('capturedAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['label'] as String?;
  }

  Stream<List<Map<String, dynamic>>> allLogsStream(String uid) =>
      _db.collection('users').doc(uid).collection('logs')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Stream<int> moodCountStream(String uid) =>
      _db.collection('users').doc(uid).collection('moods').snapshots()
          .map((s) => s.docs.length);

  // ── Reset ─────────────────────────────────────────────────────────────────

  Future<void> resetUserData(String uid) async {
    await _db.collection('users').doc(uid).update({
      'totalPoints':   0,
      'dailyPoints':   0,
      'currentStreak': 0,
      'lastActiveDate': FieldValue.delete(),
      'currentMood':    FieldValue.delete(),
      'lastMoodDate':   FieldValue.delete(),
    });
    for (final sub in [
      'logs', 'habits', 'moods', 'period_tracker',
      'family', 'period_moods', 'habit_alarms', 'invites',
    ]) {
      final snap = await _db.collection('users').doc(uid).collection(sub).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }
  }
}
