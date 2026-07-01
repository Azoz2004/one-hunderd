import 'package:flutter/material.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';

/// صفحة شرح أنظمة التحدي بـ PageView
///
/// الصفحة الأولى: شرح النظام التعاوني
/// الصفحة الثانية: شرح النظام التنافسي
/// يمكن التمرير بالأصبع يمين/شمال مع مؤشرات صفحات
class ChallengeExplanationScreen extends StatefulWidget {
  const ChallengeExplanationScreen({super.key});

  @override
  State<ChallengeExplanationScreen> createState() =>
      _ChallengeExplanationScreenState();
}

class _ChallengeExplanationScreenState
    extends State<ChallengeExplanationScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AppBar(
            title: const Text(
              'تعرف على الأنظمة',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            centerTitle: false,
            backgroundColor: AppColors.background,
            elevation: 0,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Page Indicators ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PageTab(
                  label: 'التعاوني',
                  isActive: _currentPage == 0,
                  onTap: () => _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                  ),
                ),
                const SizedBox(width: 12),
                _PageTab(
                  label: 'التنافسي',
                  isActive: _currentPage == 1,
                  onTap: () => _pageController.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                  ),
                ),
              ],
            ),
          ),

          // ── PageView ──
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) =>
                  setState(() => _currentPage = index),
              children: const [
                _CooperativeExplanation(),
                _CompetitiveExplanation(),
              ],
            ),
          ),

          // ── Dot Indicators ──
          Padding(
            padding: const EdgeInsets.only(bottom: 32, top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppColors.charcoal
                        : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Button ───────────────────────────────────────────────────────────────

class _PageTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PageTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.charcoal : AppColors.cardFill,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? AppColors.charcoal : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// شرح النظام التعاوني
// ═══════════════════════════════════════════════════════════════════════════════

class _CooperativeExplanation extends StatelessWidget {
  const _CooperativeExplanation();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          // ── Header Icon ──
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.handshake_rounded,
              size: 40,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'التحدي التعاوني',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.charcoal,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'جيب صديقك يساعدك تكمل التحدي! 🤝',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),

          // ── Feature Cards ──
          _FeatureCard(
            icon: Icons.group_rounded,
            iconColor: const Color(0xFF2196F3),
            title: 'حساب واحد مشترك',
            description:
                'أنت وصديقك بتصيروا حساب واحد! الأيام الـ 100 مشتركة بينكم والهدف واحد.',
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: Colors.deepOrange,
            title: 'ستريك مشترك',
            description:
                'يكفي واحد منكم يسجّل إيداع عشان الستريك ما ينقطع! تعاونوا على الاستمرار.',
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.generating_tokens_rounded,
            iconColor: Colors.orange,
            title: 'عملات مشتركة',
            description:
                'عملاتكم بتنجمع مع بعض وكلاكم تقدروا تصرفوا منها. طوق النجاة كمان مشترك!',
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF9C27B0),
            title: 'سجل واضح',
            description:
                'كل إيداع مسجل باسم الشخص اللي دفعه. بتقدر تشوف مين دفع وكم بأي يوم.',
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xFFFFC107),
            title: 'إنجاز مشترك',
            description:
                'لما تكملوا الـ 100 يوم سوا، الإنجاز بيكون لكلاكم! وبيظهر بملفاتكم الشخصية.',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// شرح النظام التنافسي
// ═══════════════════════════════════════════════════════════════════════════════

class _CompetitiveExplanation extends StatelessWidget {
  const _CompetitiveExplanation();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          // ── Header Icon ──
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              size: 40,
              color: Color(0xFFFF5722),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'التحدي التنافسي',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.charcoal,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'قريباً... ⏳',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),

          // ── Coming Soon Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.construction_rounded,
                  size: 48,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'هذا النظام قيد التطوير',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'نافس أصدقاءك وشوف مين بيوفر أكثر!\nترقبوا التحديث القادم 🚀',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Feature Card Widget ──────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
