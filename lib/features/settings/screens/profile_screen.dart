import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _db = FirestoreService();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  final _nameCtrl       = TextEditingController();
  final _ageCtrl        = TextEditingController();
  final _professionCtrl = TextEditingController();
  final _diseasesCtrl   = TextEditingController();

  String _gender = 'Female';
  bool _notificationsEnabled = true;
  bool _privateMode = false;
  bool _loading = true;
  bool _saving = false;
  bool _resetting = false;

  final List<Map<String, dynamic>> _dailyPlans = [
    {'label': 'Study',            'icon': Icons.menu_book_rounded,         'hours': 0},
    {'label': 'Sleeping',         'icon': Icons.bedtime_rounded,           'hours': 0},
    {'label': 'Meditation',       'icon': Icons.self_improvement_rounded,  'hours': 0},
    {'label': 'Work Focus',       'icon': Icons.laptop_rounded,            'hours': 0},
    {'label': 'Reading',          'icon': Icons.auto_stories_rounded,      'hours': 0},
    {'label': 'Skill Practice',   'icon': Icons.psychology_rounded,        'hours': 0},
    {'label': 'Project Work',     'icon': Icons.folder_special_rounded,    'hours': 0},
    {'label': 'Household Tasks',  'icon': Icons.home_repair_service_rounded,'hours': 0},
    {'label': 'Rest & Recovery',  'icon': Icons.spa_rounded,               'hours': 0},
    {'label': 'Planning Session', 'icon': Icons.event_note_rounded,        'hours': 0},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _professionCtrl.dispose();
    _diseasesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final snap = await _db.userProfileStream(_uid).first;
      if (snap != null && mounted) {
        setState(() {
          _nameCtrl.text       = snap['name'] ?? '';
          _ageCtrl.text        = (snap['age'] ?? '').toString();
          _professionCtrl.text = snap['profession'] ?? '';
          _diseasesCtrl.text   = snap['diseases'] ?? '';
          _gender              = snap['gender'] ?? 'Female';
          _notificationsEnabled= snap['notifications'] ?? true;
          _privateMode         = snap['privateMode'] ?? false;
          final plans = snap['dailyPlans'] as Map<String, dynamic>?;
          if (plans != null) {
            for (final plan in _dailyPlans) {
              plan['hours'] = plans[plan['label']] ?? 0;
            }
          }
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    final plansMap = {
      for (final p in _dailyPlans) p['label'] as String: p['hours'] as int
    };
    await _db.updateUserProfile(_uid, {
      'name':          _nameCtrl.text.trim(),
      'age':           int.tryParse(_ageCtrl.text.trim()) ?? 0,
      'profession':    _professionCtrl.text.trim(),
      'diseases':      _diseasesCtrl.text.trim(),
      'gender':        _gender,
      'notifications': _notificationsEnabled,
      'privateMode':   _privateMode,
      'dailyPlans':    plansMap,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Profile saved!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('User Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Sign Out',
            onPressed: () async => _auth.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Avatar ───────────────────────────────────────────────
              Center(
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.3)],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: theme.primaryColor.withOpacity(0.15),
                        child: Text(
                          _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: theme.primaryColor),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Personal Details ──────────────────────────────────────
              _buildSectionTitle('Personal Details'),
              const SizedBox(height: 16),
              _buildTextField(ctrl: _nameCtrl, label: 'Name', icon: Icons.person_outline_rounded),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildTextField(
                    ctrl: _ageCtrl, label: 'Age', icon: Icons.cake_outlined,
                    keyboardType: TextInputType.number,
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGenderDropdown()),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(ctrl: _professionCtrl, label: 'Profession', icon: Icons.work_outline_rounded),
              const SizedBox(height: 20),
              _buildTextField(
                ctrl: _diseasesCtrl, label: 'Health Conditions / Diseases',
                icon: Icons.medical_services_outlined, maxLines: 2,
              ),

              // ── App Settings ──────────────────────────────────────────
              const SizedBox(height: 40),
              _buildSectionTitle('App Settings'),
              const SizedBox(height: 8),
              _buildSwitchTile('Private Mode', 'Hide details from summary', _privateMode,
                  (v) => setState(() => _privateMode = v)),
              _buildSwitchTile('Notifications', 'Receive daily reminders', _notificationsEnabled,
                  (v) => setState(() => _notificationsEnabled = v)),

              // ── Daily Plans ───────────────────────────────────────────
              const SizedBox(height: 40),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E24AA).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF8E24AA), size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Daily Plans',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
              ]),
              const SizedBox(height: 6),
              const Text('Set your planned hours for each activity',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
              const SizedBox(height: 20),

              ..._dailyPlans.asMap().entries.map((entry) {
                final idx  = entry.key;
                final plan = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E24AA).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(plan['icon'] as IconData, color: const Color(0xFF8E24AA), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(plan['label'] as String,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                        const Spacer(),
                        if ((plan['hours'] as int) > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8E24AA).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${plan['hours']}h planned',
                                style: const TextStyle(
                                    color: Color(0xFF8E24AA), fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 8,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, hIdx) {
                            final h = hIdx + 1;
                            final isSelected = (plan['hours'] as int) == h;
                            return GestureDetector(
                              onTap: () => setState(
                                  () => _dailyPlans[idx]['hours'] = isSelected ? 0 : h),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF8E24AA)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF8E24AA) : Colors.white12,
                                  ),
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: const Color(0xFF8E24AA).withOpacity(0.3), blurRadius: 8)]
                                      : [],
                                ),
                                child: Center(
                                  child: Text('${h}h',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      )),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // ── Advanced ──────────────────────────────────────────────
              const SizedBox(height: 40),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings_rounded, color: Colors.white54, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Advanced',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
              ]),
              const SizedBox(height: 16),
              _buildAdvancedTile(Icons.dark_mode_rounded,     'Dark Theme',              'Optimized for night use',                const Color(0xFF7E57C2)),
              _buildAdvancedTile(Icons.download_rounded,      'Export My Data',          'Download your health data as CSV',       const Color(0xFF29B6F6)),
              _buildAdvancedTile(Icons.notifications_active_rounded,'Notification Schedule','Customize reminder times',           const Color(0xFFFFA726)),
              _buildAdvancedTile(Icons.security_rounded,      'Privacy & Security',      'Manage data and permissions',            const Color(0xFF66BB6A)),
              _buildAdvancedTile(Icons.accessibility_new_rounded,'Accessibility',         'Font size and contrast settings',        const Color(0xFFEC407A)),
              _buildAdvancedTile(Icons.info_outline_rounded,  'About LifeTrack',         'Version 1.0.0 · Open source',            Colors.white38),

              const SizedBox(height: 16),

              // Reset data
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    title: const Text('Reset All Data?',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    content: const Text(
                        'This will permanently delete all your logs, plans, and settings.',
                        style: TextStyle(color: Colors.white54, height: 1.5)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                      TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            setState(() => _resetting = true);
                            try {
                              await _db.resetUserData(_uid);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('All data has been reset.'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Reset failed. Please try again.'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _resetting = false);
                            }
                          },
                          child: _resetting
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.redAccent, strokeWidth: 2))
                              : const Text('Reset',
                                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 12),
                      Text('Reset All Data', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                      Spacer(),
                      Icon(Icons.chevron_right_rounded, color: Colors.redAccent, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Save Changes button ───────────────────────────────────
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: theme.primaryColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: () async => _auth.signOut(),
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  label: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) =>
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70));

  Widget _buildTextField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white38, size: 20),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender', style: TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _gender,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1A1A),
              items: ['Male', 'Female', 'Other'].map((v) =>
                  DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (v) => setState(() => _gender = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).primaryColor,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildAdvancedTile(IconData icon, String title, String subtitle, Color color) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title — coming soon!'), behavior: SnackBarBehavior.floating, backgroundColor: color),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5), size: 20),
        ]),
      ),
    );
  }
}
