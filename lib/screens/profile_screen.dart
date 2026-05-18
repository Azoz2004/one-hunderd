import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

// ─── Faceless Avatar Styles ───────────────────────────────────────────────────
const _avatarBgColors = [
  Color(0xFFC17F5A), Color(0xFF8A9E7A), Color(0xFF7A8FA0), Color(0xFF9A88B0),
  Color(0xFFB5906A), Color(0xFFC4A84A), Color(0xFFB08080), Color(0xFF6A8E72),
];
const _hairColors = [
  Color(0xFF1A1A1A), Color(0xFF4A3020), Color(0xFF7A5030), Color(0xFFC8A040),
  Color(0xFF404040), Color(0xFF8A4030), Color(0xFF2A4030), Color(0xFF5A3060),
];

class FacelessAvatar extends StatelessWidget {
  final int index;
  final double size;
  const FacelessAvatar({super.key, required this.index, this.size = 56});
  @override
  Widget build(BuildContext context) {
    final i = index % 8;
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(painter: _AvatarPainter(style: i)),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final int style;
  const _AvatarPainter({required this.style});
  static const _skin = Color(0xFFEDD5B0);

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2; final r = s.width / 2;
    final bg = Paint()..color = _avatarBgColors[style];
    final skin = Paint()..color = _skin;
    final hair = Paint()..color = _hairColors[style];
    // BG circle
    canvas.drawCircle(Offset(cx, cy), r, bg);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, s.width, s.height)));
    // Body
    final bodyPath = Path()
      ..moveTo(cx - r * .4, s.height)
      ..quadraticBezierTo(cx - r * .4, s.height * .75, cx, s.height * .72)
      ..quadraticBezierTo(cx + r * .4, s.height * .75, cx + r * .4, s.height)
      ..close();
    canvas.drawPath(bodyPath, skin);
    // Head
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy * .85), width: r, height: r * 1.1), skin);
    // Hair
    _drawHair(canvas, s, cx, cy, r, hair, skin);
    canvas.restore();
  }

  void _drawHair(Canvas canvas, Size s, double cx, double cy, double r, Paint hair, Paint skin) {
    switch (style) {
      case 0: // Short
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy * .72), width: r * 1.08, height: r * .7), hair);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy * .9), width: r * .96, height: r * .72), skin);
      case 1: // Afro
        canvas.drawCircle(Offset(cx, cy * .72), r * .54, hair);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy * .86), width: r * .88, height: r * .8), skin);
      case 2: // Long
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy * .9), width: r * 1.1, height: r * 1.4), const Radius.circular(8)), hair);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy * .82), width: r * .94, height: r * 1.0), skin);
      case 3: // Hijab
        canvas.drawCircle(Offset(cx, cy * .78), r * .55, hair);
        final hp = Path()
          ..moveTo(cx - r * .55, cy * .9)
          ..quadraticBezierTo(cx - r * .6, cy * 1.2, cx - r * .3, cy * 1.3)
          ..lineTo(cx + r * .3, cy * 1.3)
          ..quadraticBezierTo(cx + r * .6, cy * 1.2, cx + r * .55, cy * .9)
          ..close();
        canvas.drawPath(hp, hair);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy * .82), width: r * .72, height: r * .78), skin);
      case 4: // Bald
        final thinHair = Paint()..color = _hairColors[style]..strokeWidth = r * .06..style = PaintingStyle.stroke;
        canvas.drawArc(Rect.fromCenter(center: Offset(cx, cy * .82), width: r * 1.04, height: r * 1.08), 3.5, 5.5, false, thinHair);
      case 5: // Wavy
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy * .68), width: r * 1.1, height: r * .82), hair);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx - r * .52, cy * .88), width: r * .18, height: r * .4), hair);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx + r * .52, cy * .88), width: r * .18, height: r * .4), hair);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy * .88), width: r * .88, height: r * .86), skin);
      case 6: // Bun
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy * .7), width: r * 1.06, height: r * .7), hair);
        canvas.drawCircle(Offset(cx, cy * .32), r * .18, hair);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy * .92), width: r * .88, height: r * .62), skin);
      default: // Side-swept
        final sp = Path()
          ..moveTo(cx - r * .5, cy * .5)
          ..lineTo(cx + r * .54, cy * .42)
          ..lineTo(cx + r * .54, cy * .8)
          ..quadraticBezierTo(cx + r * .1, cy * .9, cx - r * .5, cy * .8)
          ..close();
        canvas.drawPath(sp, hair);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy * .9), width: r * .94, height: r * .72), skin);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) setState(() { _data = doc.data(); _loading = false; });
  }

  Future<void> _updateFirestore(Map<String, dynamic> fields) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update(fields);
    await _loadData();
  }

  int _calcAge(String? iso) {
    if (iso == null) return 0;
    final bd = DateTime.tryParse(iso);
    if (bd == null) return 0;
    final now = DateTime.now();
    int age = now.year - bd.year;
    if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) age--;
    return age;
  }

  double _totalSaved() {
    final deps = _data?['deposits_v1'] as List<dynamic>? ?? [];
    return deps.fold(0.0, (s, d) => s + ((d['amount'] as num?)?.toDouble() ?? 0));
  }

  String _joinedSince() {
    final dt = FirebaseAuth.instance.currentUser?.metadata.creationTime;
    if (dt == null) return '—';
    const months = [
      'يناير','فبراير','مارس','أبريل','مايو','يونيو',
      'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  void _showAvatarPicker() {
    final currentIdx = _data?['avatarIndex'] as int? ?? 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: AppColors.cardFill,
      builder: (ctx) => SafeArea(
        child: _AvatarPickerSheet(
          currentIndex: currentIdx,
          onPick: (idx) async {
            Navigator.pop(ctx);
            await _updateFirestore({'avatarIndex': idx});
          },
        ),
      ),
    );
  }

  void _showEditProfile() {
    final profile = _data?['user_profile_v1'] as Map<String, dynamic>? ?? {};
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: _EditProfileDialog(
            fullName: profile['fullName'] as String? ?? '',
            contact: profile['contact'] as String? ?? '',
            birthDate: profile['birthDate'] as String?,
            onSave: (name, contact, bDate) async {
              final updated = Map<String, dynamic>.from(profile)
                ..['fullName'] = name
                ..['contact'] = contact
                ..['birthDate'] = bDate;
              await _updateFirestore({'user_profile_v1': updated});
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ),
      ),
    );
  }

  void _showLockedSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textDirection: TextDirection.rtl),
      backgroundColor: AppColors.charcoal,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.charcoal)),
      );
    }

    final profile = _data?['user_profile_v1'] as Map<String, dynamic>? ?? {};
    final fullName = profile['fullName'] as String? ?? 'User';
    final contact = profile['contact'] as String? ?? '';
    final birthDateStr = profile['birthDate'] as String?;
    final age = _calcAge(birthDateStr);
    final goal = (profile['financialGoal'] as num?)?.toDouble() ?? 5050.0;
    final totalSaved = _totalSaved();
    final streak = _data?['current_streak_v1'] as int? ?? 0;
    final coins = _data?['wooden_coins_v1'] as int? ?? 0;
    final avatarIndex = _data?['avatarIndex'] as int? ?? 0;
    final progress = goal > 0 ? (totalSaved / goal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        backgroundColor: AppColors.background,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.charcoal,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              ProfileHeader(
                fullName: fullName,
                contact: contact,
                age: age,
                avatarIndex: avatarIndex,
                onAvatarTap: _showAvatarPicker,
              ),
              const SizedBox(height: 16),

              // ── Edit Button ──
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _showEditProfile,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text(
                    'تعديل الملف الشخصي',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.charcoal,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Account Overview ──
              _SectionLabel(label: 'نظرة عامة'),
              const SizedBox(height: 12),
              AccountOverview(
                totalSaved: totalSaved,
                goal: goal,
                progress: progress,
                streak: streak,
                coins: coins,
                joinedSince: _joinedSince(),
              ),
              const SizedBox(height: 24),

              // ── Weekly Badges ──
              _SectionLabel(label: 'شارات الأسبوع'),
              const SizedBox(height: 12),
              BadgesSection(onTap: (msg) => _showLockedSnack(msg)),
              const SizedBox(height: 24),

              // ── Achievements ──
              _SectionLabel(label: 'الإنجازات'),
              const SizedBox(height: 12),
              AchievementsSection(onTap: (msg) => _showLockedSnack(msg)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section Label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Text(
      label,
      textAlign: TextAlign.right,
      style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800, fontSize: 17),
    ),
  );
}

// ─── Profile Header ───────────────────────────────────────────────────────────
class ProfileHeader extends StatelessWidget {
  final String fullName, contact;
  final int age, avatarIndex;
  final VoidCallback onAvatarTap;

  const ProfileHeader({
    super.key,
    required this.fullName,
    required this.contact,
    required this.age,
    required this.avatarIndex,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          // Avatar ─ on the LEFT (physical)
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              children: [
                ClipOval(child: FacelessAvatar(index: avatarIndex, size: 72)),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.charcoal, shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cardFill, width: 2),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 11, color: AppColors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Info ─ right-aligned text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fullName,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800, fontSize: 18),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(child: Text(contact,
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 4),
                    const Icon(Icons.alternate_email_rounded, size: 13, color: AppColors.textSecondary),
                  ],
                ),
                if (age > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('العمر: $age سنة',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(width: 4),
                      const Icon(Icons.cake_rounded, size: 13, color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar Picker Sheet ───────────────────────────────────────────────────
class _AvatarPickerSheet extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onPick;
  const _AvatarPickerSheet({required this.currentIndex, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('اختر صورة الملف', textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.charcoal)),
          const SizedBox(height: 4),
          const Text('اضغط على أي شخصية لاختيارها', textAlign: TextAlign.right,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 16, crossAxisSpacing: 16,
              childAspectRatio: 1,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 8,
            itemBuilder: (_, i) {
              final selected = i == currentIndex;
              return GestureDetector(
                onTap: () => onPick(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.charcoal : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(child: FacelessAvatar(index: i, size: 72)),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── Edit Profile Dialog ──────────────────────────────────────────────────────
class _EditProfileDialog extends StatefulWidget {
  final String fullName, contact;
  final String? birthDate;
  final Future<void> Function(String, String, String?) onSave;
  const _EditProfileDialog({required this.fullName, required this.contact, required this.birthDate, required this.onSave});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late TextEditingController _nameCtrl, _contactCtrl;
  DateTime? _birthDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.fullName);
    _contactCtrl = TextEditingController(text: widget.contact);
    if (widget.birthDate != null) _birthDate = DateTime.tryParse(widget.birthDate!);
  }

  @override
  void dispose() { _nameCtrl.dispose(); _contactCtrl.dispose(); super.dispose(); }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1920), lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.charcoal, onPrimary: AppColors.white),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _birthDate = d);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('تعديل الملف الشخصي',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.charcoal)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            textDirection: TextDirection.rtl,
            decoration: _dec('الاسم الكامل', Icons.person_outline_rounded),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactCtrl,
            decoration: _dec('البريد / الجوال', Icons.alternate_email_rounded),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(Icons.cake_rounded, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    _birthDate != null
                        ? '${_birthDate!.year}/${_birthDate!.month}/${_birthDate!.day}'
                        : 'تاريخ الميلاد',
                    style: TextStyle(
                      color: _birthDate != null ? AppColors.charcoal : AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : () async {
                    setState(() => _saving = true);
                    await widget.onSave(
                      _nameCtrl.text.trim(),
                      _contactCtrl.text.trim(),
                      _birthDate?.toIso8601String(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                    : const Text('حفظ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
    filled: true, fillColor: AppColors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.charcoal, width: 1.5)),
  );
}

// ─── Account Overview ─────────────────────────────────────────────────────────
class AccountOverview extends StatelessWidget {
  final double totalSaved, goal, progress;
  final int streak, coins;
  final String joinedSince;

  const AccountOverview({
    super.key,
    required this.totalSaved, required this.goal, required this.progress,
    required this.streak, required this.coins, required this.joinedSince,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toInt();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          // Circular Progress
          SizedBox(
            width: 120, height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120, height: 120,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: AppColors.borderLight,
                    valueColor: const AlwaysStoppedAnimation(AppColors.charcoal),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$pct%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.charcoal)),
          const Text('من الهدف', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats Row
          Row(
            children: [
              _MiniStat(icon: Icons.account_balance_wallet_outlined, label: 'الرصيد', value: '${totalSaved.toStringAsFixed(0)} JD'),
              _Divider(),
              _MiniStat(icon: Icons.local_fire_department_rounded, label: 'أيام الالتزام', value: '$streak', iconColor: Colors.deepOrange),
              _Divider(),
              _MiniStat(icon: Icons.generating_tokens_rounded, label: 'العملات', value: '$coins', iconColor: Colors.orange),
            ],
          ),
          const SizedBox(height: 16),

          // Joined Since
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('عضو منذ: $joinedSince',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color iconColor;
  const _MiniStat({required this.icon, required this.label, required this.value, this.iconColor = AppColors.charcoal});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, size: 20, color: iconColor),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.charcoal)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
    ]),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 40, color: AppColors.borderLight);
}

// ─── Badges Section (horizontal scroll — no overflow) ────────────────────────
class BadgesSection extends StatelessWidget {
  final ValueChanged<String> onTap;
  const BadgesSection({super.key, required this.onTap});

  static const _badges = [
    ('🔥', 'سبعة أيام', 'حافظ على الستريك 7 أيام لفتح هذه الشارة!'),
    ('⚡', 'مدخر سريع', 'وفّر خلال الساعة الأولى لمدة 5 أيام لفتح هذه الشارة!'),
    ('🌙', 'بومة الليل', 'سجّل إيداعاتك بعد الساعة 10 مساءً لمدة 3 أيام لفتح هذه الشارة!'),
    ('💎', 'المدخر الماسي', 'أكمل 30 يوماً لفتح هذه الشارة!'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _badges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final b = _badges[i];
          return GestureDetector(
            onTap: () => onTap(b.$3),
            child: _LockedBadge(emoji: b.$1, label: b.$2),
          );
        },
      ),
    );
  }
}

class _LockedBadge extends StatelessWidget {
  final String emoji, label;
  const _LockedBadge({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 80,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.borderLight.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(emoji, style: TextStyle(fontSize: 26, color: AppColors.charcoal.withValues(alpha: 0.18))),
                const Icon(Icons.lock_rounded, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

// ─── Achievements Section (horizontal scroll) ─────────────────────────────────
class AchievementsSection extends StatelessWidget {
  final ValueChanged<String> onTap;
  const AchievementsSection({super.key, required this.onTap});

  static const _achievements = [
    ('🏆', 'أول إيداع', 'سجّل أول إيداع لك لفتح هذا الإنجاز!'),
    ('🎯', 'حادد الهدف', 'حدد هدفاً مالياً بقيمة 5000 JD لفتح هذا الإنجاز!'),
    ('📅', 'بطل 30 يوماً', 'حافظ على الستريك 30 يوماً لفتح هذا الإنجاز!'),
    ('💰', 'نصف الطريق', 'وفّر 50% من هدفك لفتح هذا الإنجاز!'),
    ('🚀', 'اكتمال التحدي', 'أكمل 100 يوم لفتح هذا الإنجاز!'),
    ('👑', 'ملك العملات', 'اكسب 1000 عملة خشبية لفتح هذا الإنجاز!'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _achievements.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final a = _achievements[i];
          return GestureDetector(
            onTap: () => onTap(a.$3),
            child: _LockedAchievement(emoji: a.$1, label: a.$2),
          );
        },
      ),
    );
  }
}

class _LockedAchievement extends StatelessWidget {
  final String emoji, label;
  const _LockedAchievement({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 84,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.borderLight.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(emoji, style: TextStyle(fontSize: 28, color: AppColors.charcoal.withValues(alpha: 0.18))),
                const Icon(Icons.lock_rounded, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}
