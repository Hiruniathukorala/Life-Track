import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DemoSeeder {
  static const String demoEmail = 'demo@lifetrack.app';
  static const String demoPassword = 'Demo@12345';
  static const String demoName = 'Sanchitha';

  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static Future<String?> loginAndSeed() async {
    try {
      UserCredential cred;
      try {
        cred = await _auth.signInWithEmailAndPassword(
            email: demoEmail, password: demoPassword);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          cred = await _auth.createUserWithEmailAndPassword(
              email: demoEmail, password: demoPassword);
        } else {
          return e.message;
        }
      }

      final uid = cred.user!.uid;
      await _seedAll(uid);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> _seedAll(String uid) async {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);

    // ── User Profile ──────────────────────────────────────────────────────
    await _db.collection('users').doc(uid).set({
      'name': demoName,
      'email': demoEmail,
      'totalPoints': 1240,
      'dailyPoints': 180,
      'currentStreak': 7,
      'lastActiveDate': todayStr,
      'level': 5,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ── Activity Logs ─────────────────────────────────────────────────────
    final logs = [
      {
        'activity': 'Morning Run',
        'mood': 'Energized 🏃',
        'notes': '5km in 28 minutes, felt great!',
        'time': '7:30 AM',
        'color': 0xFF6C63FF,
        'points': 30,
        'timestamp': Timestamp.fromDate(
            today.subtract(const Duration(hours: 2))),
      },
      {
        'activity': 'Meditation',
        'mood': 'Calm 🧘',
        'notes': '15 min mindfulness session',
        'time': '8:00 AM',
        'color': 0xFF4CAF50,
        'points': 30,
        'timestamp': Timestamp.fromDate(
            today.subtract(const Duration(hours: 1, minutes: 30))),
      },
      {
        'activity': 'Healthy Breakfast',
        'mood': 'Happy 😊',
        'notes': 'Oats with fruits and nuts',
        'time': '8:30 AM',
        'color': 0xFFFF9800,
        'points': 30,
        'timestamp': Timestamp.fromDate(
            today.subtract(const Duration(hours: 1))),
      },
      {
        'activity': 'Study Session',
        'mood': 'Focused 📚',
        'notes': 'Flutter development – 2 hours deep work',
        'time': '10:00 AM',
        'color': 0xFF2196F3,
        'points': 30,
        'timestamp': Timestamp.fromDate(
            today.subtract(const Duration(minutes: 30))),
      },
      {
        'activity': 'Evening Walk',
        'mood': 'Relaxed 🌅',
        'notes': 'Walked with family around the neighbourhood',
        'time': '6:00 PM',
        'color': 0xFFE91E63,
        'points': 30,
        'timestamp': Timestamp.fromDate(
            today.subtract(const Duration(days: 1, hours: 2))),
      },
    ];

    final logsRef = _db.collection('users').doc(uid).collection('logs');
    // Clear old demo logs
    final existing = await logsRef.limit(20).get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }
    for (final log in logs) {
      await logsRef.add(log);
    }

    // ── Habits ────────────────────────────────────────────────────────────
    final habits = [
      'Morning Hydration',
      'Review Goals',
      '30m Reading',
      'Evening Reflection',
    ];
    for (int i = 0; i < habits.length; i++) {
      await _db
          .collection('users')
          .doc(uid)
          .collection('habits')
          .doc('${habits[i]}_$todayStr')
          .set({
        'habit': habits[i],
        'date': todayStr,
        'completed': i < 2, // First 2 completed
      });
    }

    // ── Family Members ────────────────────────────────────────────────────
    final familyRef =
        _db.collection('users').doc(uid).collection('family');
    final existingFamily = await familyRef.get();
    for (final doc in existingFamily.docs) {
      await doc.reference.delete();
    }

    final familyMembers = [
      {
        'name': 'Amma',
        'relation': 'Mother',
        'age': '48',
        'health': 'Diabetic – check sugar levels weekly',
        'notes': 'Prefers low-carb meals',
        'color': 0xFFE91E63,
      },
      {
        'name': 'Appa',
        'relation': 'Father',
        'age': '52',
        'health': 'Hypertension – on medication',
        'notes': 'Daily morning walk',
        'color': 0xFF2196F3,
      },
      {
        'name': 'Ravi',
        'relation': 'Brother',
        'age': '22',
        'health': 'Healthy',
        'notes': 'Gym 4x per week',
        'color': 0xFF4CAF50,
      },
    ];
    for (final member in familyMembers) {
      await familyRef.add(member);
    }

    // ── Period Tracker ────────────────────────────────────────────────────
    final lastPeriod =
        today.subtract(const Duration(days: 14));
    await _db
        .collection('users')
        .doc(uid)
        .collection('period_tracker')
        .doc('current')
        .set({
      'lastPeriodDate': lastPeriod.toIso8601String().substring(0, 10),
      'cycleLength': '28',
      'periodLength': '5',
      'symptoms': 'Mild cramps on day 1-2',
      'notes': 'Regular cycle, track next period around '
          '${today.add(const Duration(days: 14)).toIso8601String().substring(0, 10)}',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
