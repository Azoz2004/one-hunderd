import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _fullNameController;
  late TextEditingController _bioController;
  late TextEditingController _financialGoalController;
  
  String _selectedStatus = 'شاب';
  String _selectedGoal = 'بيت';
  DateTime? _selectedBirthDate;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SavingsProvider>();
    final userProfile = provider.userProfile;
    
    _fullNameController = TextEditingController(text: userProfile?.fullName ?? '');
    _bioController = TextEditingController(text: userProfile?.bio ?? '');
    _financialGoalController = TextEditingController(
      text: userProfile?.financialGoal.toStringAsFixed(2) ?? '5050',
    );
    
    _selectedStatus = userProfile?.maritalStatus ?? 'شاب';
    if (!['شاب', 'شابة', 'متزوج', 'متزوجة'].contains(_selectedStatus)) {
      _selectedStatus = 'شاب';
    }

    _selectedGoal = userProfile?.goal ?? 'بيت';
    if (!['زواج', 'بيت', 'صحة', 'ترك التدخين'].contains(_selectedGoal)) {
      _selectedGoal = 'بيت';
    }

    _selectedBirthDate = userProfile?.birthDate;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _financialGoalController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.charcoal,
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

  int _calcAge(DateTime? date) {
    if (date == null) return 0;
    final now = DateTime.now();
    int age = now.year - date.year;
    if (now.month < date.month || (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age;
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
        fullName: _fullNameController.text.trim(),
        bio: _bioController.text.trim(),
        maritalStatus: _selectedStatus,
        goal: _selectedGoal,
        financialGoal: goalValue,
        birthDate: _selectedBirthDate,
      );

      if (mounted) {
        AppSnackbar.show(
          context: context,
          message: 'تم حفظ بيانات الملف الشخصي بنجاح ✏️',
          isSuccess: true,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context: context,
          message: 'خطأ أثناء الحفظ: $e',
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calculatedAge = _calcAge(_selectedBirthDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'تعديل الملف الشخصي',
          style: TextStyle(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w800,
            fontSize: 19,
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
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: const [
                        Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'عدّل اسمك، نبذتك الشخصية، وتاريخ ميلادك ليظهر ملفك بشكل مميز وخاص.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // الاسم الكامل
                  _buildLabel('الاسم الكامل'),
                  _StyledField(
                    controller: _fullNameController,
                    icon: Icons.person_outline_rounded,
                    hint: 'أدخل اسمك الكامل',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'الاسم الكامل مطلوب';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // النبذة العامة / البايو
                  _buildLabel('النبذة العامة (البايو)'),
                  _StyledField(
                    controller: _bioController,
                    icon: Icons.article_outlined,
                    hint: 'اكتب نبذة مختصرة عن نفسك أو رسالتك التحفيزية...',
                    maxLines: 3,
                    maxLength: 120,
                  ),
                  const SizedBox(height: 20),

                  // تاريخ الميلاد والـ Age
                  _buildLabel('تاريخ الميلاد (العمر)'),
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
                        textDirection: TextDirection.rtl,
                        children: [
                          const Icon(Icons.cake_rounded, color: AppColors.charcoal, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedBirthDate != null
                                  ? '${_selectedBirthDate!.year}/${_selectedBirthDate!.month.toString().padLeft(2, '0')}/${_selectedBirthDate!.day.toString().padLeft(2, '0')} (${calculatedAge > 0 ? '$calculatedAge سنة' : 'تاريخ جديد'})'
                                  : 'انقر لاختيار تاريخ ميلادك',
                              style: TextStyle(
                                color: _selectedBirthDate != null ? AppColors.charcoal : AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
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
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.charcoal),
                        isExpanded: true,
                        dropdownColor: AppColors.cardFill,
                        style: const TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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

                  // الهدف المالي
                  _buildLabel('الهدف المالي (دينار أردني JD)'),
                  _StyledField(
                    controller: _financialGoalController,
                    icon: Icons.savings_outlined,
                    hint: 'الهدف المالي',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'أدخل المبلغ';
                      final val = double.tryParse(v);
                      if (val == null || val <= 0) return 'مبلغ غير صالح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // زر الحفظ
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.charcoal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'حفظ التعديلات',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),
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
        textAlign: TextAlign.right,
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
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;

  const _StyledField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textDirection: TextDirection.rtl,
      style: const TextStyle(
        color: AppColors.charcoal,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
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
          borderSide: const BorderSide(color: AppColors.charcoal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}
