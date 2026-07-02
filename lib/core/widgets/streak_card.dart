import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/features/challenges/widgets/gamification_dialogs.dart';

/// Two side-by-side cards matching the sticker reference design.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingsProvider>();
    final streak = provider.currentStreak;

    String streakSubtitle;
    if (streak == 0) {
      streakSubtitle = 'سجّل إيداعك الأول!';
    } else if (streak < 7) {
      streakSubtitle = 'بداية رائعة!';
    } else if (streak < 30) {
      streakSubtitle = 'واصل الالتزام!';
    } else {
      streakSubtitle = 'أنت بطل! 🏆';
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StreakHalfCard(
              streak: streak,
              subtitleText: streakSubtitle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LifebuoyHalfCard(
              lifebuoys: provider.lifebuoys,
              onTap: () => showLifebuoyDialog(context, manualTrigger: true),
            ),
          ),
        ],
      ),
    );
  }
}

const _cardShadow = [
  BoxShadow(
    color: Color(0x1F6B4E31), // softer shadow
    blurRadius: 10,
    spreadRadius: 0,
    offset: Offset(0, 4),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Streak Half Card
// ─────────────────────────────────────────────────────────────────────────────

class _StreakHalfCard extends StatelessWidget {
  final int streak;
  final String subtitleText;

  const _StreakHalfCard({
    required this.streak,
    required this.subtitleText,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg    = Color(0xFFFFF8EE);
    const borderClr = Color(0xFFEDE0CB);
    // Darker, more readable text colors
    const labelClr  = Color(0xFF6B5234);   // dark warm brown (was 9C836A)
    const numClr    = Color(0xFFE07820);   // vibrant orange

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderClr, width: 1),
        boxShadow: _cardShadow,
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Decorative sparkles ──
          Positioned(
            top: 10, right: 16,
            child: Text('✦',
                style: TextStyle(
                    fontSize: 10,
                    color: labelClr.withValues(alpha: 0.4))),
          ),
          Positioned(
            top: 24, right: 30,
            child: Text('✧',
                style: TextStyle(
                    fontSize: 7,
                    color: labelClr.withValues(alpha: 0.3))),
          ),

          // ── Fire image with Glow and 3D effect (Centered behind text) ──
          Positioned(
            bottom: 0, // Rest on the bottom edge so it doesn't get cut off
            left: 0,
            right: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Ambient Fire Glow (Light Source behind the fire)
                Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xCCFF7300), // Intense vibrant orange
                        blurRadius: 35,
                        spreadRadius: 25,
                      ),
                      BoxShadow(
                        color: Color(0xAAFF2200), // Brighter red core
                        blurRadius: 20,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                ),
                // 2. 3D Drop Shadow for the Fire PNG itself
                Transform.translate(
                  offset: const Offset(-3, 4), // slightly softer drop shadow offset
                  child: Image.asset(
                    'assets/images/Fire.png',
                    height: 100, // Reverted to original large size
                    color: const Color(0x306B4E31), // softer drop shadow color
                    fit: BoxFit.contain,
                  ),
                ),
                // 3. The actual Fire image
                Image.asset(
                  'assets/images/Fire.png',
                  height: 100, // Reverted to original large size
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),

          // ── Main content ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0), // squeezed padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Label — bigger & darker
                const Text(
                  'الالتزام',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 16,
                    fontWeight: FontWeight.w900, // bolder
                    color: Color(0xFF4A3723), // very dark warm brown
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2), // squeezed

                // 🔥 + number
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('🔥',
                        style: TextStyle(fontSize: 20, height: 1.1)),
                    const SizedBox(width: 4),
                    Text(
                      '$streak',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: numClr,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                
                // Subtitle removed to prevent overlap and make room for the large flame

                // Space for the flame
                const SizedBox(height: 40), // ensures the 100px flame fits without clipping
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lifebuoy Half Card
// ─────────────────────────────────────────────────────────────────────────────

class _LifebuoyHalfCard extends StatelessWidget {
  final int lifebuoys;
  final VoidCallback onTap;

  const _LifebuoyHalfCard({
    required this.lifebuoys,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg    = Color(0xFFFFF8EE);
    const borderClr = Color(0xFFEDE0CB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // squeezed vertical padding
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderClr, width: 1),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Realistic 3D Drop Shadow for Lifebuoy
              Transform.translate(
                offset: const Offset(-4, 6), // bigger offset
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), // Add blur for realistic shadow
                  child: Image.asset(
                    'assets/images/Lifebuoy.png',
                    height: 56, // smaller image
                    color: const Color(0x666B4E31), // darker, more visible warm brown shadow
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Image.asset(
                'assets/images/Lifebuoy.png',
                height: 56, // smaller image
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 4), // squeezed
          const Text(
            'طوق النجاة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'تخطي يوم واحد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8), // squeezed
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.cardFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderClr),
              ),
              child: Text(
                'المتبقي: $lifebuoys',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
