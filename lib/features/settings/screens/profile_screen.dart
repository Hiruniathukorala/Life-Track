import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _shareSummaries = false;
  bool _privateMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Privacy')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          const CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'), // Mock Profile
            backgroundColor: Colors.grey,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Hiruni',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Level 5 Explorer',
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
          ),
          const SizedBox(height: 32),
          
          ListTile(
            title: Text('Privacy Controls', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).primaryColor)),
          ),
          SwitchListTile(
            title: const Text('Private Mode'),
            subtitle: const Text('Hide sensitive details from dashboard'),
            value: _privateMode,
            onChanged: (val) => setState(() => _privateMode = val),
            activeThumbColor: Theme.of(context).primaryColor,
          ),
          SwitchListTile(
            title: const Text('Share Weekly Summaries'),
            subtitle: const Text('Allow sharing of aggregated stats'),
            value: _shareSummaries,
            onChanged: (val) => setState(() => _shareSummaries = val),
            activeThumbColor: Theme.of(context).primaryColor,
          ),
          
          const Divider(),
          
          ListTile(
            title: Text('Notifications', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).primaryColor)),
          ),
          SwitchListTile(
            title: const Text('Daily Reminders'),
            subtitle: const Text('Remind me at 8:00 PM'),
            value: _notificationsEnabled,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
            activeThumbColor: Theme.of(context).primaryColor,
          ),
          
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              // Mock Logout
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
    );
  }
}
