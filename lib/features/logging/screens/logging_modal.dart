import 'package:flutter/material.dart';

class LoggingModal extends StatelessWidget {
  const LoggingModal({super.key});

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
        children: [
          Text(
            'Quick Log',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          // Form will go here
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save & Close'),
          ),
        ],
      ),
    );
  }
}
