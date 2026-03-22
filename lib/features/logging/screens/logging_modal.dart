import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:life_track/core/data/mock_data.dart';
import '../../../core/services/firestore_service.dart';

class LoggingModal extends StatefulWidget {
  const LoggingModal({super.key});

  @override
  State<LoggingModal> createState() => _LoggingModalState();
}

class _LoggingModalState extends State<LoggingModal> {
  final _db = FirestoreService();
  String? _selectedCategory;
  String? _selectedItem;
  double _measureValue = 0;
  String _measureUnit = '';
  bool _saving = false;

  void _selectItem(String item) {
    // Initialise measure defaults immediately — no postFrameCallback needed.
    double val = 0;
    String unit = '';
    if (item == 'Drinking Water') {
      unit = 'ml';
      val = 250;
    } else if (_selectedCategory == 'Fitness') {
      unit = 'min';
      val = 30;
    } else if (_selectedCategory == 'Moods') {
      unit = '/10';
      val = 5;
    } else if (_selectedCategory == 'Daily Plans') {
      unit = 'hrs';
      val = 1;
    }
    setState(() {
      _selectedItem = item;
      _measureUnit = unit;
      _measureValue = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCategory == null 
                    ? 'Quick Log' 
                    : _selectedItem == null 
                        ? 'Select $_selectedCategory'
                        : 'Log $_selectedItem',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedCategory == null 
                ? _buildCategoryList(context)
                : _selectedItem == null 
                    ? _buildItemGrid(context)
                    : _buildMeasureSection(context),
            ),
          ),

          if (_selectedItem != null)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      _getCategoryColor(),
                      _getCategoryColor().withOpacity(0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getCategoryColor().withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saving ? null : () async {
                    setState(() => _saving = true);
                    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                    final now = DateTime.now();
                    final timeStr =
                        '${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
                    try {
                      await _db.addLog(uid, {
                        'activity': _selectedItem,
                        'category': _selectedCategory,
                        'mood': _measureUnit.isNotEmpty
                            ? '${_measureValue.toInt()}$_measureUnit'
                            : 'Logged',
                        'time': timeStr,
                        'color': _getCategoryColor().toARGB32(),
                      });
                      await _db.addPoints(uid, 30);
                      await _db.updateStreak(uid);
                    } catch (e) {
                      debugPrint('Log save error: $e');
                    }

                    if (!mounted) return;
                    setState(() => _saving = false);
                    Navigator.pop(context);
                    String logMsg = 'Logged $_selectedItem';
                    if (_measureValue > 0) logMsg += ': ${_measureValue.toInt()}$_measureUnit';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(logMsg),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: _getCategoryColor(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Log',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          
          if (_selectedCategory != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TextButton.icon(
                onPressed: () => setState(() {
                  if (_selectedItem != null) {
                    _selectedItem = null;
                  } else {
                    _selectedCategory = null;
                  }
                }),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(_selectedItem == null ? 'Back to Categories' : 'Back to Items'),
                style: TextButton.styleFrom(foregroundColor: Colors.white60),
              ),
            ),
            
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildMeasureSection(BuildContext context) {
    Color color = _getCategoryColor();
    
    if (_selectedItem == 'Drinking Water') {
      return _buildWaterMeasure(color);
    } else if (_selectedCategory == 'Fitness') {
      return _buildFitnessMeasure(color);
    } else if (_selectedCategory == 'Moods') {
      return _buildMoodMeasure(color);
    } else if (_selectedCategory == 'Daily Plans') {
      return _buildDailyPlanMeasure(color);
    } else {
      return _buildGenericMeasure(color);
    }
  }

  Widget _buildDailyPlanMeasure(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Duration: ${_measureValue.toInt()} hours', 
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: List.generate(8, (index) {
              final val = index + 1;
              final isSelected = _measureValue == val.toDouble();
              return GestureDetector(
                onTap: () => setState(() => _measureValue = val.toDouble()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? Colors.white : Colors.white10),
                    boxShadow: isSelected ? [
                      BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)
                    ] : [],
                  ),
                  child: Center(
                    child: Text('${val}h', 
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 18
                      )
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterMeasure(Color color) {
    final amounts = [250, 500, 750, 1000];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How much did you drink?', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: amounts.map((amount) {
              final isSelected = _measureValue == amount.toDouble();
              return GestureDetector(
                onTap: () => setState(() => _measureValue = amount.toDouble()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? Colors.white : Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.local_drink_rounded, color: isSelected ? Colors.white : color),
                      const SizedBox(height: 8),
                      Text('${amount}ml', style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFitnessMeasure(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Duration: ${_measureValue.toInt()} minutes', 
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.1),
              thumbColor: Colors.white,
              overlayColor: color.withOpacity(0.2),
            ),
            child: Slider(
              value: _measureValue,
              min: 5,
              max: 180,
              divisions: 35,
              onChanged: (val) => setState(() => _measureValue = val),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('5m', style: TextStyle(color: Colors.white38)),
              Text('180m', style: TextStyle(color: Colors.white38)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoodMeasure(Color color) {
    final emojis = ['😫', '☹️', '😕', '😐', '🙂', '😊', '😁', '🤩', '🔥', '✨'];
    final labels = ['Very Low', 'Low', 'Mild', 'Neutral', 'Good', 'Cheerful', 'Very Happy', 'Excited', 'Peak', 'Legendary'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${emojis[_measureValue.toInt() - 1]} ${labels[_measureValue.toInt() - 1]} (${_measureValue.toInt()}/10)', 
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: List.generate(10, (index) {
              final val = index + 1;
              final isSelected = _measureValue == val.toDouble();
              return GestureDetector(
                onTap: () => setState(() => _measureValue = val.toDouble()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? Colors.white : Colors.white10),
                    boxShadow: isSelected ? [
                      BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)
                    ] : [],
                  ),
                  child: Center(
                    child: Text('${emojis[index]}', style: const TextStyle(fontSize: 20)),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericMeasure(Color color) {
    return const Center(child: Text('Logging current progress...', style: TextStyle(color: Colors.white60)));
  }

  Widget _buildCategoryList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView(
        key: const ValueKey('categories'),
        shrinkWrap: true,
        children: [
          _buildCategoryCard('Habits', Icons.auto_awesome_rounded, const Color(0xFF4285F4)),
          const SizedBox(height: 16),
          _buildCategoryCard('Fitness', Icons.fitness_center_rounded, const Color(0xFF34A853)),
          const SizedBox(height: 16),
          _buildCategoryCard('Moods', Icons.wb_sunny_rounded, const Color(0xFFFBBC05)),
          const SizedBox(height: 16),
          _buildCategoryCard('Daily Plans', Icons.calendar_today_rounded, const Color(0xFF8E24AA)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color) {
    return InkWell(
      onTap: () => setState(() => _selectedCategory = title),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                icon,
                size: 120,
                color: color.withOpacity(0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemGrid(BuildContext context) {
    List<String> items = [];
    IconData icon = Icons.check_circle_outline_rounded;
    Color color = _getCategoryColor();

    if (_selectedCategory == 'Habits') {
      items = MockData.habits;
      icon = Icons.star_rounded;
    } else if (_selectedCategory == 'Fitness') {
      items = MockData.fitness;
      icon = Icons.bolt_rounded;
    } else if (_selectedCategory == 'Moods') {
      items = MockData.moods;
      icon = Icons.face_rounded;
    } else if (_selectedCategory == 'Daily Plans') {
      items = MockData.dailyPlans;
      icon = Icons.event_note_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView.separated(
        key: const ValueKey('items'),
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = _selectedItem == item;
          
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _selectItem(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutQuint,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? color.withOpacity(0.15) 
                    : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? color : Colors.white.withOpacity(0.08),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    )
                  ] : [],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? color : color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 17,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 24,
                      )
                    else
                      Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.white.withOpacity(0.2),
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getCategoryColor() {
    if (_selectedCategory == 'Habits') return const Color(0xFF4285F4);
    if (_selectedCategory == 'Fitness') return const Color(0xFF34A853);
    if (_selectedCategory == 'Moods') return const Color(0xFFFBBC05);
    if (_selectedCategory == 'Daily Plans') return const Color(0xFF8E24AA);
    return Theme.of(context).primaryColor;
  }
}
