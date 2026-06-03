import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/savings_provider.dart';
import '../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _financialGoalController;
  
  String _selectedStatus = 'شاب';
  String _selectedGoal = 'بيت';
  DateTime? _selectedBirthDate;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SavingsProvider>();
    final userProfile = provider.userProfile;
    
    _emailController = TextEditingController(text: userProfile?.contact ?? '');
    _passwordController = TextEditingController(); // Empty, only used if they want to change it
    _financialGoalController = TextEditingController(text: userProfile?.financialGoal.toStringAsFixed(0) ?? '5050');
    
    _selectedStatus = userProfile?.maritalStatus ?? 'شاب';
    _selectedGoal = userProfile?.goal ?? 'بيت';
    _selectedBirthDate = userProfile?.birthDate;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _financialGoalController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.orangeAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.charcoal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedBirthDate = date);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final provider = context.read<SavingsProvider>();
      
      final goalValue = double.tryParse(_financialGoalController.text.trim());
      if (goalValue == null || goalValue <= 0) {
        throw Exception('يرجى إدخال مبلغ مالي صحيح.');
      }
      
      await provider.updateAccountDetails(
        newEmail: _emailController.text.trim(),
        newPassword: _passwordController.text.isEmpty ? null : _passwordController.text,
        maritalStatus: _selectedStatus,
        goal: _selectedGoal,
        financialGoal: goalValue,
        birthDate: _selectedBirthDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ البيانات بنجاح!', textDirection: TextDirection.rtl),
          backgroundColor: AppColors.green,
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'حدث خطأ';
      if (e.code == 'requires-recent-login') {
        msg = 'لأسباب أمنية (تغيير الإيميل أو الرمز)، يرجى تسجيل الخروج والدخول مجدداً ثم المحاولة.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $msg', textDirection: TextDirection.rtl), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e', textDirection: TextDirection.rtl), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'تعديل الحساب',
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
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'يمكنك تعديل بياناتك في أي وقت لتحديث ملفك الشخصي.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

                  // الايميل
                  _buildLabel('البريد الإلكتروني'),
                  _StyledField(
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    hint: 'أدخل بريدك الإلكتروني',
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'البريد الإلكتروني مطلوب';
                      if (!v.contains('@')) return 'بريد غير صالح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // الرمز السري
                  _buildLabel('الرمز السري (اختياري)'),
                  _StyledField(
                    controller: _passwordController,
                    icon: Icons.lock_outline_rounded,
                    hint: 'اتركه فارغاً إذا لم ترد تغييره',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length < 6) {
                        return 'يجب أن يكون الرمز 6 أحرف على الأقل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // الحالة الاجتماعية
                  _buildLabel('الحالة الاجتماعية'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.charcoal),
                        isExpanded: true,
                        dropdownColor: AppColors.cardFill,
                        style: const TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Cairo', // assuming app font
                        ),
                        items: ['شاب', 'شابة', 'متزوج', 'متزوجة'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) setState(() => _selectedStatus = newValue);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // تاريخ الميلاد
                  _buildLabel('تاريخ الميلاد'),
                  GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.cardFill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: Colors.orangeAccent, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            _selectedBirthDate != null
                                ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
                                : 'اختر تاريخ ميلادك',
                            style: TextStyle(
                              color: _selectedBirthDate != null ? AppColors.charcoal : AppColors.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // الهدف
                  _buildLabel('هدفك من التوفير'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGoal,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.charcoal),
                        isExpanded: true,
                        dropdownColor: AppColors.cardFill,
                        style: const TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Cairo',
                        ),
                        items: ['زواج', 'بيت', 'صحة'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) setState(() => _selectedGoal = newValue);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // الهدف المالي
                  _buildLabel('الهدف المالي المراد جمعه'),
                  _StyledField(
                    controller: _financialGoalController,
                    icon: Icons.attach_money_rounded,
                    hint: 'الهدف المالي',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'أدخل المبلغ';
                      final val = double.tryParse(v);
                      if (val == null || val <= 0) return 'مبلغ غير صالح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),

                  // زر الحفظ
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: Colors.orangeAccent.withValues(alpha: 0.4),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'حفظ التعديلات',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.charcoal,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;

  const _StyledField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: AppColors.charcoal,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.cardFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.orangeAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}
