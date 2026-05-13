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
      builder: (context, linksSnap) {
        final links = linksSnap.data ?? [];

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _db.pendingInvitesStream(_uid),
          builder: (context, inviteSnap) {
            final invites = inviteSnap.data ?? [];

            return Scaffold(
              backgroundColor: const Color(0xFF0F0F0F),
              appBar: AppBar(
                title: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Text('Family',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    if (invites.isNotEmpty)
                      Positioned(
                        top: -4, right: -12,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Color(0xFFEC407A),
                              shape: BoxShape.circle),
                          child: Text('${invites.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.person_add_rounded),
                    onPressed: () => _showAddMemberSheet(context),
                    tooltip: 'Invite family member',
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // ── Pending invites banner ──────────────────────────────
                    if (invites.isNotEmpty) ...[
                      _buildInvitesBanner(context, invites),
                      const SizedBox(height: 16),
                    ],

                    if (links.isEmpty && invites.isEmpty)
                      _buildEmptyState(context)
                    else ...[
                      // Info banner
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF6C63FF).withOpacity(0.2)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFF6C63FF), size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Linked family members see each other\'s live stats. Both sides must accept the invite.',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 13),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      if (links.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Family Members',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70)),
                            TextButton.icon(
                              onPressed: () =>
                                  _showAddMemberSheet(context),
                              icon: const Icon(Icons.add_rounded,
                                  size: 18),
                              label: const Text('Invite'),
                              style: TextButton.styleFrom(
                                  foregroundColor:
                                      const Color(0xFF6C63FF)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...links.map((link) =>
                            _buildLiveCard(context, link)),
                        const SizedBox(height: 32),
                        const Text('Leaderboard 🏆',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70)),
                        const SizedBox(height: 12),
                        _buildLeaderboard(links),
                        const SizedBox(height: 40),
                      ] else ...[
                        _buildEmptyState(context),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Pending Invites Banner ────────────────────────────────────────────────

  Widget _buildInvitesBanner(
      BuildContext context, List<Map<String, dynamic>> invites) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEC407A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFEC407A).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.mail_rounded,
                color: Color(0xFFEC407A), size: 18),
            const SizedBox(width: 8),
            Text(
              '${invites.length} Pending Invite${invites.length > 1 ? 's' : ''}',
              style: const TextStyle(
                  color: Color(0xFFEC407A),
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ]),
          const SizedBox(height: 12),
          ...invites.map((inv) => _buildInviteRow(context, inv)),
        ],
      ),
    );
  }

  Widget _buildInviteRow(
      BuildContext context, Map<String, dynamic> inv) {
    final fromName  = inv['fromName']  as String? ?? 'Someone';
    final fromEmail = inv['fromEmail'] as String? ?? '';
    final role      = inv['role']      as String? ?? 'Family';
    final fromUid   = inv['fromUid']   as String? ?? inv['id'] as String;
    final color     = _colorFor(fromUid);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withOpacity(0.15),
          child: Text(
            fromName.isNotEmpty ? fromName[0].toUpperCase() : '?',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fromName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Text('$fromEmail · as $role',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        // Accept button
        GestureDetector(
          onTap: () => _acceptInvite(context, inv),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF66BB6A).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF66BB6A).withOpacity(0.4)),
            ),
            child: const Text('Accept',
                style: TextStyle(
                    color: Color(0xFF66BB6A),
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ),
        const SizedBox(width: 8),
        // Decline button
        GestureDetector(
          onTap: () => _declineInvite(inv),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: const Text('Decline',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ),
      ]),
    );
  }

  Future<void> _acceptInvite(
      BuildContext context, Map<String, dynamic> inv) async {
    final fromUid = inv['fromUid'] as String? ?? inv['id'] as String;
    final role    = inv['role']    as String? ?? 'Family';
    try {
      await _db.acceptFamilyInvite(
          myUid: _uid, fromUid: fromUid, role: role);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Family member linked successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF66BB6A),
          ),
        );
      }
    } catch (e) {
      debugPrint('Accept invite error: $e');
    }
  }

  Future<void> _declineInvite(Map<String, dynamic> inv) async {
    final fromUid = inv['fromUid'] as String? ?? inv['id'] as String;
    await _db.declineFamilyInvite(myUid: _uid, fromUid: fromUid);
  }

  // ── Live member card ──────────────────────────────────────────────────────

  Widget _buildLiveCard(
      BuildContext context, Map<String, dynamic> link) {
    final linkedUid = link['linkedUid'] as String? ?? link['id'] as String;
    final role      = link['role'] as String? ?? 'Family';
    final color     = _colorFor(linkedUid);

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _db.linkedUserProfileStream(linkedUid),
      builder: (context, profileSnap) {
        final profile  = profileSnap.data;
        final name     = profile?['name']         as String? ?? 'Loading...';
        final points   = profile?['totalPoints']  as int? ?? 0;
        final streak   = profile?['currentStreak'] as int? ?? 0;
        final dailyPts = profile?['dailyPoints']  as int? ?? 0;
        final isLoading =
            profileSnap.connectionState == ConnectionState.waiting &&
                profile == null;

        return GestureDetector(
          onTap: isLoading
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FamilyMemberDetailScreen(
                          linkedUid: linkedUid, role: role),
                    ),
                  ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: color.withOpacity(0.25), width: 1.5),
            ),
            child: isLoading
                ? Row(children: [
                    CircleAvatar(
                        radius: 26,
                        backgroundColor: color.withOpacity(0.1),
                        child: Icon(Icons.person_outline_rounded,
                            color: color)),
                    const SizedBox(width: 16),
                    const CircularProgressIndicator(strokeWidth: 2),
                  ])
                : Row(children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: color.withOpacity(0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color),
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
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(role,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(Icons.star_rounded,
                                size: 14, color: Colors.amber[400]),
                            const SizedBox(width: 4),
                            Text('$points XP',
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12)),
                            const SizedBox(width: 12),
                            const Icon(
                                Icons.local_fire_department_rounded,
                                size: 14,
                                color: Colors.deepOrange),
                            const SizedBox(width: 4),
                            Text('${streak}d streak',
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12)),
                            const SizedBox(width: 12),
                            Icon(Icons.bolt_rounded,
                                size: 14,
                                color: Colors.greenAccent[400]),
                            const SizedBox(width: 4),
                            Text('$dailyPts pts today',
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12)),
                          ]),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white24, size: 20),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: Colors.white38),
                      color: const Color(0xFF1A1A1A),
                      onSelected: (val) {
                        if (val == 'remove')
                          _confirmRemove(context, link, name);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(children: [
                            Icon(Icons.link_off_rounded,
                                color: Colors.redAccent, size: 18),
                            SizedBox(width: 10),
                            Text('Unlink member',
                                style:
                                    TextStyle(color: Colors.redAccent)),
                          ]),
                        ),
                      ],
                    ),
                  ]),
          ),
        );
      },
    );
  }

  void _confirmRemove(BuildContext context,
      Map<String, dynamic> link, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Unlink $name?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'This removes the link. They will no longer appear in your family list.',
            style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              _db.deleteFamilyMember(_uid, link['id'] as String);
              Navigator.pop(context);
            },
            child: const Text('Unlink',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Leaderboard (sorted by XP) ────────────────────────────────────────────

  // Cache so the future isn't recreated on every StreamBuilder rebuild.
  Future<List<_LeaderEntry>>? _leaderFuture;
  int _lastLinkCount = -1;

  Widget _buildLeaderboard(List<Map<String, dynamic>> links) {
    // Rebuild the future only when the family member count changes.
    if (_lastLinkCount != links.length) {
      _lastLinkCount = links.length;
      _leaderFuture  = _buildLeaderEntries(links);
    }

    return FutureBuilder<List<_LeaderEntry>>(
      future: _leaderFuture,
      builder: (context, snap) {
        // Loading skeleton
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Column(
            children: List.generate(3, (_) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(18),
              ),
            )),
          );
        }

        final entries = snap.data ?? [];
        final medals  = ['🥇', '🥈', '🥉'];

        return Column(
          children: entries.asMap().entries.map((e) {
            final idx   = e.key;
            final entry = e.value;
            final color = _colorFor(entry.uid);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: idx == 0
                    ? Colors.amber.withOpacity(0.07)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: idx == 0
                        ? Colors.amber.withOpacity(0.3)
                        : Colors.white10),
              ),
              child: Row(children: [
                Text(medals[idx < 3 ? idx : 2],
                    style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withOpacity(0.15),
                  child: Text(
                    entry.name.isNotEmpty
                        ? entry.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text(entry.role,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                Text('${entry.pts} XP',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ]),
            );
          }).toList(),
        );
      },
    );
  }

  Future<List<_LeaderEntry>> _buildLeaderEntries(
      List<Map<String, dynamic>> links) async {
    final entries = <_LeaderEntry>[];

    // Always include the current user so they can see where they rank.
    final myProfile = await _db.linkedUserProfileStream(_uid).first;
    entries.add(_LeaderEntry(
      uid:  _uid,
      name: '${myProfile?['name'] as String? ?? 'You'} (You)',
      role: 'Me',
      pts:  myProfile?['totalPoints'] as int? ?? 0,
    ));

    for (final link in links) {
      final uid  = link['linkedUid'] as String? ?? link['id'] as String;
      final role = link['role'] as String? ?? '';
      final profile = await _db.linkedUserProfileStream(uid).first;
      entries.add(_LeaderEntry(
        uid:  uid,
        name: profile?['name']        as String? ?? '?',
        role: role,
        pts:  profile?['totalPoints'] as int? ?? 0,
      ));
    }
    entries.sort((a, b) => b.pts.compareTo(a.pts)); // sort by XP descending
    return entries;
  }

  // ── Empty State ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_outlined,
                size: 72, color: Colors.white12),
            const SizedBox(height: 20),
            const Text('No family members linked',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Invite a LifeTrack user by their email. They\'ll receive a request to accept before linking.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 13),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _showAddMemberSheet(context),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send Invite'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add / Invite sheet ────────────────────────────────────────────────────

  void _showAddMemberSheet(BuildContext context) {
    String email = '';
    String role  = 'Partner';
    bool loading = false;
    String? error;
    bool sent = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(36)),
            ),
            child: sent
                ? _buildSentConfirmation(ctx)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius:
                                    BorderRadius.circular(2))),
                      ),
                      const SizedBox(height: 20),
                      const Text('Invite Family Member',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      const Text(
                          'They\'ll receive a request and must accept before linking.',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13)),
                      const SizedBox(height: 20),

                      // Security notice
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF)
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF6C63FF)
                                  .withOpacity(0.2)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.verified_user_rounded,
                              color: Color(0xFF6C63FF), size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Privacy protected — the other person must approve before any data is shared.',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),

                      const Text('Their Email',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (v) => email = v,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'e.g. partner@example.com',
                          hintStyle: const TextStyle(
                              color: Colors.white24),
                          prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: Colors.white38),
                          filled: true,
                          fillColor:
                              Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                              borderSide: BorderSide.none),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Your Relationship',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius:
                                BorderRadius.circular(16)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: role,
                            isExpanded: true,
                            dropdownColor:
                                const Color(0xFF1A1A1A),
                            items: _roles
                                .map((r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r,
                                        style: const TextStyle(
                                            color:
                                                Colors.white))))
                                .toList(),
                            onChanged: (v) =>
                                setSheet(() => role = v!),
                          ),
                        ),
                      ),

                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                Colors.redAccent.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.redAccent
                                    .withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.redAccent,
                                size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(error!,
                                    style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 13))),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF6C63FF),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(18)),
                          ),
                          onPressed: loading
                              ? null
                              : () async {
                                  final trimmed = email
                                      .trim()
                                      .toLowerCase();
                                  if (trimmed.isEmpty) {
                                    setSheet(() => error =
                                        'Please enter an email address.');
                                    return;
                                  }
                                  setSheet(() {
                                    loading = true;
                                    error   = null;
                                  });
                                  try {
                                    final found = await _db
                                        .findUserByEmail(trimmed);
                                    if (found == null) {
                                      setSheet(() {
                                        loading = false;
                                        error =
                                            'No LifeTrack account found for "$trimmed".';
                                      });
                                      return;
                                    }
                                    final toUid =
                                        found['uid'] as String;
                                    if (toUid == _uid) {
                                      setSheet(() {
                                        loading = false;
                                        error =
                                            'You cannot invite yourself.';
                                      });
                                      return;
                                    }
                                    await _db.sendFamilyInvite(
                                      fromUid: _uid,
                                      toUid:   toUid,
                                      role:    role,
                                    );
                                    setSheet(
                                        () => sent = true);
                                  } catch (e) {
                                    debugPrint('Family invite error: $e');
                                    setSheet(() {
                                      loading = false;
                                      error = e.toString().contains('permission')
                                          ? 'Permission denied — please update Firestore rules in Firebase Console.'
                                          : 'Something went wrong: ${e.toString().split(']').last.trim()}';
                                    });
                                  }
                                },
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2))
                              : const Text('Send Invite',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.bold,
                                      color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      }),
    );
  }

  Widget _buildSentConfirmation(BuildContext ctx) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.check_circle_rounded,
            color: Color(0xFF66BB6A), size: 64),
        const SizedBox(height: 16),
        const Text('Invite Sent! 🎉',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'They\'ll see your invite in their Family screen.\nOnce accepted, you\'ll both be linked.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Helper data class ─────────────────────────────────────────────────────────

class _LeaderEntry {
  final String uid;
  final String name;
  final String role;
  final int    pts;
  const _LeaderEntry(
      {required this.uid,
      required this.name,
      required this.role,
      required this.pts});
}
