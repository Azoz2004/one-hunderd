import 'package:flutter/material.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';
import 'package:one_hunderd/features/profile/screens/edit_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'الإعدادات',
          style: TextStyle(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.charcoal, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // قسم الحساب
              _buildSectionTitle('الحساب'),
              _buildSettingsTile(
                context,
                icon: Icons.person_outline_rounded,
                title: 'تعديل بيانات الحساب',
                isUnderDevelopment: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  );
                },
              ),
              const SizedBox(height: 24),

              // قسم التفضيلات
              _buildSectionTitle('التفضيلات (قريباً)'),
              _buildSettingsTile(
                context,
                icon: Icons.notifications_none_rounded,
                title: 'إدارة الإشعارات',
                isUnderDevelopment: true,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.language_rounded,
                title: 'اللغة (Language)',
                isUnderDevelopment: true,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.dark_mode_outlined,
                title: 'المظهر (داكن/فاتح)',
                isUnderDevelopment: true,
              ),
              const SizedBox(height: 24),

              // قسم إضافي
              _buildSectionTitle('أخرى (قريباً)'),
              _buildSettingsTile(
                context,
                icon: Icons.cloud_upload_outlined,
                title: 'النسخ الاحتياطي',
                isUnderDevelopment: true,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.support_agent_rounded,
                title: 'تواصل معنا / الدعم',
                isUnderDevelopment: true,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.privacy_tip_outlined,
                title: 'سياسة الخصوصية',
                isUnderDevelopment: true,
              ),
              const SizedBox(height: 40),

              // الإصدار
              Center(
                child: Text(
                  'الإصدار 1.0.0',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.charcoal,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isUnderDevelopment,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: isUnderDevelopment
            ? () {
                AppSnackbar.show(
                  context: context,
                  message: 'هذه الميزة قيد التطوير وسيتم إضافتها قريباً!',
                  isSuccess: false,
                  isInfo: true,
                );
              }
            : onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isUnderDevelopment 
                ? AppColors.textSecondary.withValues(alpha: 0.1) 
                : Colors.orangeAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isUnderDevelopment ? AppColors.textSecondary : Colors.orangeAccent,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isUnderDevelopment ? AppColors.textSecondary : AppColors.charcoal,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: isUnderDevelopment
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'قيد التطوير',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
      ),
    );
  }
}
