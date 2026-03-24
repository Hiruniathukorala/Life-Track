import 'package:flutter/material.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Insights')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mood Trends', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBar(context, 'Mon', 0.4, Colors.redAccent),
                  _buildBar(context, 'Tue', 0.6, Colors.orangeAccent),
                  _buildBar(context, 'Wed', 0.8, Colors.green),
                  _buildBar(context, 'Thu', 0.5, Colors.amber),
                  _buildBar(context, 'Fri', 0.9, Colors.blue),
                  _buildBar(context, 'Sat', 0.7, Colors.purple),
                  _buildBar(context, 'Sun', 0.3, Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('Activity Distribution', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildStatRow(context, 'Work', 0.5, Colors.blue),
            _buildStatRow(context, 'Exercise', 0.3, Colors.green),
            _buildStatRow(context, 'Social', 0.1, Colors.purple),
            _buildStatRow(context, 'Relax', 0.1, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context, String day, double heightFraction, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Flexible bar container
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: 16,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  FractionallySizedBox(
                    heightFactor: heightFraction,
                    child: Container(
                      width: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 4), // reduce spacing slightly
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              day,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(BuildContext context, String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 16)),
          ),
          SizedBox(
            width: 100,
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey[800],
              color: color,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Text('${(value * 100).toInt()}%'),
        ],
      ),
    );
  }
}
