import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import 'family_member_detail_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _db = FirestoreService();
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static const List<Color> _colors = [
    Color(0xFF6C63FF), Color(0xFFEC407A), Color(0xFF29B6F6),
    Color(0xFF26A69A), Color(0xFFFFA726), Color(0xFF66BB6A),
  ];

  final _roles = ['Partner', 'Mother', 'Father', 'Sister', 'Brother',
      'Son', 'Daughter', 'Grandmother', 'Grandfather', 'Friend', 'Other'];

  Color _colorFor(String uid) {
    final idx = uid.codeUnits.fold(0, (a, b) => a + b) % _colors.length;
    return _colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.familyLinksStream(_uid),
      builder: (context, snap) {
        final links = snap.data ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          appBar: AppBar(
            title: const Text('Family', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_rounded),
                onPressed: () => _showAddMemberSheet(context),
                tooltip: 'Link family member',
              ),
            ],
          ),
          body: links.isEmpty
              ? _buildEmptyState(context)
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // Info banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF6C63FF), size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Linked family members see each other\'s live stats.',
                              style: TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Family Members',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
                          TextButton.icon(
                            onPressed: () => _showAddMemberSheet(context),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add'),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF6C63FF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Each link card listens to the linked user's live profile
                      ...links.map((link) => _buildLiveCard(context, link)),
                      const SizedBox(height: 32),
                      if (links.isNotEmpty) ...[
                        const Text('Leaderboard 🏆',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
                        const SizedBox(height: 12),
                        _buildLeaderboard(links),
                        const SizedBox(height: 40),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildLiveCard(BuildContext context, Map<String, dynamic> link) {
    final linkedUid = link['linkedUid'] as String? ?? link['id'] as String;
    final role = link['role'] as String? ?? 'Family';
    final color = _colorFor(linkedUid);

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _db.linkedUserProfileStream(linkedUid),
      builder: (context, profileSnap) {
        final profile = profileSnap.data;
        final name = profile?['name'] as String? ?? 'Loading...';
        final points = profile?['totalPoints'] as int? ?? 0;
        final streak = profile?['currentStreak'] as int? ?? 0;
        final dailyPts = profile?['dailyPoints'] as int? ?? 0;
        final isLoading = profileSnap.connectionState == ConnectionState.waiting && profile == null;

        return GestureDetector(
          onTap: isLoading
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FamilyMemberDetailScreen(
                        linkedUid: linkedUid,
                        role: role,
                      ),
                    ),
                  ),
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.25), width: 1.5),
          ),
          child: isLoading
              ? Row(children: [
                  CircleAvatar(radius: 26, backgroundColor: color.withOpacity(0.1),
                      child: Icon(Icons.person_outline_rounded, color: color)),
                  const SizedBox(width: 16),
                  const CircularProgressIndicator(strokeWidth: 2),
                ])
              : Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: color.withOpacity(0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                              child: Text(name,
                                  style: const TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(role,
                                  style: TextStyle(color: color, fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(Icons.star_rounded, size: 14, color: Colors.amber[400]),
                            const SizedBox(width: 4),
                            Text('$points XP total',
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(width: 12),
                            const Icon(Icons.local_fire_department_rounded,
                                size: 14, color: Colors.deepOrange),
                            const SizedBox(width: 4),
                            Text('${streak}d streak',
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(width: 12),
                            Icon(Icons.bolt_rounded, size: 14,
                                color: Colors.greenAccent[400]),
                            const SizedBox(width: 4),
                            Text('$dailyPts pts today',
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ]),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white24, size: 20),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white38),
                      color: const Color(0xFF1A1A1A),
                      onSelected: (val) {
                        if (val == 'remove') _confirmRemove(context, link, name);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'remove',
                            child: Row(children: [
                              Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 18),
                              SizedBox(width: 10),
                              Text('Unlink member', style: TextStyle(color: Colors.redAccent)),
                            ])),
                      ],
                    ),
                  ],
                ),
          ),
        );
      },
    );
  }

  void _confirmRemove(BuildContext context, Map<String, dynamic> link, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Unlink $name?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'This will remove the link. They will no longer appear in your family list.',
            style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              final memberId = link['id'] as String;
              _db.deleteFamilyMember(_uid, memberId);
              Navigator.pop(context);
            },
            child: const Text('Unlink',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(List<Map<String, dynamic>> links) {
    // We show a leaderboard by collecting live profiles — rendered as
    // separate StreamBuilders combined inside a FutureBuilder snapshot.
    return Column(
      children: links.asMap().entries.map((entry) {
        final link = entry.value;
        final linkedUid = link['linkedUid'] as String? ?? link['id'] as String;
        final color = _colorFor(linkedUid);
        final medals = ['🥇', '🥈', '🥉'];

        return StreamBuilder<Map<String, dynamic>?>(
          stream: _db.linkedUserProfileStream(linkedUid),
          builder: (context, snap) {
            final p = snap.data;
            final name = p?['name'] as String? ?? '...';
            final pts = p?['totalPoints'] as int? ?? 0;
            final role = link['role'] as String? ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: entry.key == 0 ? Colors.amber.withOpacity(0.07) : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: entry.key == 0 ? Colors.amber.withOpacity(0.3) : Colors.white10),
              ),
              child: Row(children: [
                Text(medals[entry.key < 3 ? entry.key : 2],
                    style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withOpacity(0.15),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(role, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ])),
                Text('$pts XP',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_outlined, size: 72, color: Colors.white12),
            const SizedBox(height: 20),
            const Text('No family members linked',
                style: TextStyle(color: Colors.white38, fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Link another LifeTrack user by their email to see their live stats and compete on the leaderboard.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 13),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _showAddMemberSheet(context),
              icon: const Icon(Icons.link_rounded),
              label: const Text('Link Family Member'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemberSheet(BuildContext context) {
    String email = '';
    String role = 'Partner';
    bool loading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text('Link Family Member',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 6),
                const Text('Enter their LifeTrack account email',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 20),

                // Email field
                const Text('Their Email', style: TextStyle(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (v) => email = v,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. partner@example.com',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),

                // Role dropdown
                const Text('Your Relationship', style: TextStyle(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: role, isExpanded: true,
                      dropdownColor: const Color(0xFF1A1A1A),
                      items: _roles.map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r, style: const TextStyle(color: Colors.white)))
                      ).toList(),
                      onChanged: (v) => setSheet(() => role = v!),
                    ),
                  ),
                ),

                // Error message
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(error!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                    ]),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: loading ? null : () async {
                      final trimmed = email.trim().toLowerCase();
                      if (trimmed.isEmpty) {
                        setSheet(() => error = 'Please enter an email address.');
                        return;
                      }
                      setSheet(() { loading = true; error = null; });
                      try {
                        final found = await _db.findUserByEmail(trimmed);
                        if (found == null) {
                          setSheet(() {
                            loading = false;
                            error = 'No LifeTrack account found for "$trimmed".';
                          });
                          return;
                        }
                        final linkedUid = found['uid'] as String;
                        if (linkedUid == _uid) {
                          setSheet(() {
                            loading = false;
                            error = 'You cannot link yourself.';
                          });
                          return;
                        }
                        await _db.linkFamilyMember(_uid, linkedUid, role);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setSheet(() {
                          loading = false;
                          error = 'Something went wrong. Please try again.';
                        });
                      }
                    },
                    child: loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Link Member',
                            style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
