import 'package:flutter/material.dart';
import 'package:life_track/core/data/mock_data.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome Back,'),
            Text(
              'Hiruni', 
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.orangeAsync, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${MockData.currentStreak} Day Streak',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Progress
            _buildProgressCard(context),
            const SizedBox(height: 24),

            // Recent Logs
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...MockData.recentLogs.map((log) => _buildLogItem(context, log)).toList(),

            const SizedBox(height: 24),
            
            // Daily Habits
            Text(
              'Daily Habits',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...MockData.dailyHabits.map((habit) => _buildHabitItem(context, habit)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Goal', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${MockData.dailyPoints} / 300 pts',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              CircularProgressIndicator(
                value: MockData.dailyPoints / 300,
                backgroundColor: Colors.grey[800],
                color: Theme.of(context).primaryColor,
                strokeWidth: 8,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(BuildContext context, Map<String, dynamic> log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(log['color'] as int),
          child: const Icon(Icons.check, color: Colors.white, size: 16),
        ),
        title: Text(log['activity']),
        subtitle: Text(log['mood']),
        trailing: Text(log['time']),
      ),
    );
  }

  Widget _buildHabitItem(BuildContext context, String habit) {
    return CheckboxListTile(
      value: false, // Make interactive later
      onChanged: (val) {},
      title: Text(habit),
      secondary: const Icon(Icons.repeat),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: EdgeInsets.zero,
    );
  }
}
