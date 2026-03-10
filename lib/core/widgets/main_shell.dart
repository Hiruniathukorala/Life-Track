import 'package:flutter/material.dart';
import '../../features/dashboard/screens/home_dashboard.dart';
import '../../features/insights/screens/insights_screen.dart';
import '../../features/period_tracker/screens/period_tracker_screen.dart';
import '../../features/gamification/screens/achievements_screen.dart';
import '../../features/family/screens/family_screen.dart';
import '../../features/settings/screens/profile_screen.dart';
import '../../features/logging/screens/logging_modal.dart';
import '../../features/mood/widgets/mood_check_in_sheet.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Show the AI mood check-in on every app open, after the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) MoodCheckInSheet.showIfNeeded(context);
      });
    });
  }
  final List<Widget> _screens = const [
    HomeDashboard(),
    InsightsScreen(),
    PeriodTrackerScreen(),
    AchievementsScreen(),
    FamilyScreen(),
    ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _showLoggingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LoggingModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF3F3D56)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showLoggingModal,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 36, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
            _buildNavItem(icon: Icons.bar_chart_rounded, label: 'Insights', index: 1),
            _buildNavItem(icon: Icons.favorite_rounded, label: 'Cycle', index: 2, activeColor: const Color(0xFFEC407A)),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(icon: Icons.emoji_events_rounded, label: 'Awards', index: 3),
            _buildNavItem(icon: Icons.group_rounded, label: 'Family', index: 4),
            _buildNavItem(icon: Icons.person_rounded, label: 'Profile', index: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index, Color? activeColor}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? (activeColor ?? Theme.of(context).primaryColor) : Colors.grey.withOpacity(0.6);
    return Expanded( 
      child: InkWell(
        onTap: () => _onTabTapped(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? icon : _getOutlineIcon(icon), 
                size: 24, 
                color: color
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color, 
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getOutlineIcon(IconData icon) {
    if (icon == Icons.home_rounded) return Icons.home_outlined;
    if (icon == Icons.bar_chart_rounded) return Icons.bar_chart_outlined;
    if (icon == Icons.favorite_rounded) return Icons.favorite_outline_rounded;
    if (icon == Icons.emoji_events_rounded) return Icons.emoji_events_outlined;
    if (icon == Icons.group_rounded) return Icons.group_outlined;
    if (icon == Icons.person_rounded) return Icons.person_outline_rounded;
    return icon;
  }
}
