import 'package:flutter/material.dart';
import 'package:life_track/core/data/mock_data.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Icon(Icons.star, size: 64, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text(
                    '${MockData.totalPoints} XP',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Level 5 Tracker', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 24),
                  LinearProgressIndicator(
                    value: 0.7,
                    backgroundColor: Colors.grey[800],
                    color: Colors.amber,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 8),
                  const Text('350 XP to Next Level', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              delegate: SliverChildListDelegate(
                [
                  _buildBadge(context, Icons.rocket_launch, 'Early Bird', true),
                  _buildBadge(context, Icons.bolt, '7-Day Streak', true),
                  _buildBadge(context, Icons.book, 'Reader', false),
                  _buildBadge(context, Icons.directions_run, 'Fitness', false),
                  _buildBadge(context, Icons.nightlight_round, 'Night Owl', true),
                  _buildBadge(context, Icons.local_cafe, 'Balanced', false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, IconData icon, String label, bool earned) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: earned ? Theme.of(context).primaryColor : Colors.grey[850],
            shape: BoxShape.circle,
            border: Border.all(
              color: earned ? Theme.of(context).primaryColor : Colors.grey[700]!,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            size: 32,
            color: earned ? Colors.white : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: earned ? Colors.white : Colors.grey,
            fontWeight: earned ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
