
class MockData {
  static const int currentStreak = 5;
  static const int dailyPoints = 150;
  static const int totalPoints = 1240;

  static final List<String> dailyHabits = [
    'Morning Hydration',
    'Review Goals',
    '30m Reading',
    'Evening Reflection',
  ];

  static final List<Map<String, dynamic>> recentLogs = [
    {
      'activity': 'Gym Session',
      'mood': 'Energized',
      'time': '10:30 AM',
      'color': 0xFF6C63FF,
    },
    {
      'activity': 'Client Meeting',
      'mood': 'Productive',
      'time': '02:00 PM',
      'color': 0xFF4CAF50,
    },
    {
      'activity': 'Evening Walk',
      'mood': 'Relaxed',
      'time': '06:45 PM',
      'color': 0xFFFF6584,
    },
  ];
}
