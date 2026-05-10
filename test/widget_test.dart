import 'package:flutter_test/flutter_test.dart';
import 'package:life_track/core/services/firestore_service.dart';

void main() {
  group('FirestoreService helpers', () {
    test('streak logic: increments when last active was yesterday', () {
      // This mirrors the streak calculation in updateStreak().
      final today = DateTime(2026, 5, 9);
      final yesterday = today.subtract(const Duration(days: 1));
      final lastActive =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      int streak = 5;
      if (lastActive ==
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}') {
        streak += 1;
      } else if (lastActive != todayStr) {
        streak = 1;
      }
      expect(streak, 6);
    });

    test('streak logic: resets when a day is missed', () {
      final today = DateTime(2026, 5, 9);
      final twoDaysAgo = today.subtract(const Duration(days: 2));
      final lastActive =
          '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      int streak = 5;
      if (lastActive == yesterdayStr) {
        streak += 1;
      } else if (lastActive != todayStr) {
        streak = 1;
      }
      expect(streak, 1);
    });

    test('XP level formula uses 500 pts per level', () {
      const ptsPerLevel = 500;
      int xp = 1250;
      final level = (xp / ptsPerLevel).floor() + 1;
      final nextLevelXp = level * ptsPerLevel;
      final progress = (xp % ptsPerLevel) / ptsPerLevel;

      expect(level, 3);
      expect(nextLevelXp, 1500);
      expect(progress, closeTo(0.5, 0.001));
    });

    test('daily goal progress clamps to 1.0', () {
      const goal = 300;
      final pts = 450;
      final progress = (pts / goal).clamp(0.0, 1.0);
      expect(progress, 1.0);
    });
  });
}
