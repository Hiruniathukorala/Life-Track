import 'package:flutter/material.dart';

class LoggingModal extends StatefulWidget {
  const LoggingModal({super.key});

  @override
  State<LoggingModal> createState() => _LoggingModalState();
}

class _LoggingModalState extends State<LoggingModal> {
  String _selectedMood = 'Okay';
  String _selectedActivity = 'Work';
  final TextEditingController _noteController = TextEditingController();

  final List<String> _moods = ['Great', 'Good', 'Okay', 'Bad', 'Awful'];
  final Map<String, IconData> _activities = {
    'Work': Icons.work,
    'Study': Icons.book,
    'Exercise': Icons.fitness_center,
    'Relax': Icons.weekend,
    'Social': Icons.people,
    'Chores': Icons.cleaning_services,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Log',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Text('How are you feeling?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _moods.map((mood) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ChoiceChip(
                  label: Text(mood),
                  selected: _selectedMood == mood,
                  onSelected: (selected) => setState(() => _selectedMood = mood),
                  selectedColor: Theme.of(context).primaryColor,
                  labelStyle: TextStyle(
                    color: _selectedMood == mood ? Colors.white : Colors.white70,
                  ),
                ),
              )).toList(),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text('What are you doing?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _activities.entries.map((entry) {
              final isSelected = _selectedActivity == entry.key;
              return InkWell(
                onTap: () => setState(() => _selectedActivity = entry.key),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        entry.value,
                        size: 18,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: () {
              // TODO: Save log
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log saved! (+10 pts)')),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Save Log'),
          ),
          // Add padding for keyboard if needed
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
