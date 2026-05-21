import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/savings_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

// ─── Main Auth Screen (4-step wizard) ────────────────────────────────────────
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoginMode = true;

  // Step-1
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Step-2
  String _selectedStatus = '';
  DateTime? _selectedBirthDate;

  // Step-3
  String _selectedGoal = '';
  final _targetAmountController = TextEditingController();

  // Step-4
  String _selectedChallengeType = '';

  // ── Validators ───────────────────────────────────────────────────────────
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final _phoneRegex = RegExp(r'^(\+962|00962|0)(7[0-9]{8})$');

  String? _validateContact(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'الرجاء إدخال الإيميل أو رقم الهاتف';
    }
    final t = value.trim();
    if (!_emailRegex.hasMatch(t) && !_phoneRegex.hasMatch(t)) {
      return 'أدخل إيميل صحيح أو رقم أردني (+962…)';
    }
    return null;
  }

  String _getValidEmail() {
    final contact = _contactController.text.trim();
    if (!contact.contains('@')) {
      return '$contact@onehundred.app';
    }
    return contact;
  }

  // ── Navigation ───────────────────────────────────────────────────────────
  void _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final email = _getValidEmail();
      final password = _passwordController.text;
      await context.read<SavingsProvider>().login(email, password);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'حدث خطأ';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
        msg = 'البريد الإلكتروني أو الرمز السري غير صحيح.';
      } else if (e.code == 'invalid-email') {
        msg = 'صيغة الإيميل غير صحيحة.';
      } else if (e.code == 'operation-not-allowed') {
        msg = 'يجب تفعيل Email/Password من Firebase Console';
      }
      _showSnack('خطأ: $msg');
    } catch (e) {
      _showSnack('خطأ غير متوقع: $e');
    }
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
      if (!_isLoginMode && _nameController.text.trim().isEmpty) {
        _showSnack('الرجاء إدخال اسمك');
        return;
      }
    }
    if (_currentStep == 1) {
      if (_selectedStatus.isEmpty) {
        _showSnack('الرجاء اختيار حالتك الاجتماعية');
        return;
      }
      if (_selectedBirthDate == null) {
        _showSnack('الرجاء إدخال تاريخ ميلادك');
        return;
      }
    }
    if (_currentStep == 2) {
      if (_selectedGoal.isEmpty) {
        _showSnack('الرجاء اختيار هدفك');
        return;
      }
      if (_targetAmountController.text.trim().isEmpty) {
        _showSnack('الرجاء إدخال مبلغ الهدف');
        return;
      }
    }

    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: AppColors.charcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _finish() async {
    if (_selectedChallengeType.isEmpty) {
      _showSnack('الرجاء اختيار نوع التحدي');
      return;
    }
    
    final targetAmountText = _targetAmountController.text.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    final double? parsedAmount = double.tryParse(targetAmountText);

    try {
      await context.read<SavingsProvider>().signUp(
        email: _getValidEmail(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        gender:
            _selectedStatus.contains('شابة') || _selectedStatus.contains('متزوجة')
            ? 'Female'
            : 'Male',
        contact: _contactController.text.trim(),
        financialGoal: parsedAmount ?? 5050.0,
        maritalStatus: _selectedStatus,
        goal: _selectedGoal,
        challengeType: _selectedChallengeType,
        birthDate: _selectedBirthDate,
      );

      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'حدث خطأ غير معروف';
      if (e.code == 'email-already-in-use') {
        msg = 'هذا الحساب موجود مسبقاً، الرجاء تسجيل الدخول.';
      } else if (e.code == 'invalid-email') {
        msg = 'صيغة الإيميل غير صحيحة.';
      } else if (e.code == 'operation-not-allowed') {
        msg = 'تسجيل الدخول بالبريد الإلكتروني غير مفعل في Firebase Console.';
      } else if (e.code == 'weak-password') {
        msg = 'الرمز السري ضعيف جداً.';
      }
      _showSnack('خطأ في التسجيل: $msg');
    } catch (e) {
      _showSnack('خطأ غير متوقع: $e');
    }
  }

  void _signInWithGoogle() {
    // Google Sign-In سيتم تفعيله لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تسجيل الدخول بـ Google سيتوفر قريباً ✨',
            textDirection: TextDirection.rtl),
        backgroundColor: AppColors.charcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress dots (always visible at top) ──
            const SizedBox(height: 16),
            if (!_isLoginMode) _StepDots(currentStep: _currentStep),
            const SizedBox(height: 8),

            // ── Pages ──
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Page 1: has logo + greeting inside
                  _Step1InfoPage(
                    formKey: _formKey,
                    isLoginMode: _isLoginMode,
                    nameController: _nameController,
                    contactController: _contactController,
                    passwordController: _passwordController,
                    obscurePassword: _obscurePassword,
                    validateContact: _validateContact,
                    onTogglePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onToggleMode: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                        _formKey.currentState?.reset();
                      });
                    },
                    onLogin: _login,
                    onNextStep: _nextStep,
                    onGoogleSignIn: _signInWithGoogle,
                  ),
                  // Pages 2-4: title inside the page, no logo
                  _Step2StatusPage(
                    selected: _selectedStatus,
                    selectedDate: _selectedBirthDate,
                    onSelect: (v) => setState(() => _selectedStatus = v),
                    onSelectDate: (v) => setState(() => _selectedBirthDate = v),
                  ),
                  _Step3GoalPage(
                    selected: _selectedGoal,
                    amountController: _targetAmountController,
                    onSelect: (v) => setState(() => _selectedGoal = v),
                  ),
                  _Step4ChallengePage(
                    selected: _selectedChallengeType,
                    onSelect: (v) => setState(() => _selectedChallengeType = v),
                  ),
                ],
              ),
            ),

            // ── Bottom nav: only show on pages 2-4 ──
            if (_currentStep > 0)
              _BottomNav(
                currentStep: _currentStep,
                onBack: _prevStep,
                onNext: _nextStep,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Step Dots ────────────────────────────────────────────────────────────────
class _StepDots extends StatelessWidget {
  final int currentStep;
  const _StepDots({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final active = i == currentStep;
        final done = i < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: done || active ? AppColors.charcoal : AppColors.borderLight,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─── Step 1 – Name / Contact / Password (has logo inside) ────────────────────
class _Step1InfoPage extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool isLoginMode;
  final TextEditingController nameController;
  final TextEditingController contactController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final String? Function(String?) validateContact;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleMode;
  final VoidCallback onLogin;
  final VoidCallback onNextStep;
  final VoidCallback onGoogleSignIn;

  const _Step1InfoPage({
    required this.formKey,
    required this.isLoginMode,
    required this.nameController,
    required this.contactController,
    required this.passwordController,
    required this.obscurePassword,
    required this.validateContact,
    required this.onTogglePassword,
    required this.onToggleMode,
    required this.onLogin,
    required this.onNextStep,
    required this.onGoogleSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            // ── Logo + greeting (step 1 only) ──
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isLoginMode ? 'أهلاً بك مجدداً! 👋' : 'أهلاً بك! 👋',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isLoginMode ? 'سجل دخولك لمتابعة تحدي الادخار' : 'ابدأ رحلة الادخار الآن بإنشاء حسابك',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 28),

            // ── Full Name
            if (!isLoginMode) ...[
              _StyledField(
                controller: nameController,
                label: 'الاسم الكامل',
                hint: 'أدخل اسمك',
                icon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (!isLoginMode && (v == null || v.trim().isEmpty)) ? 'الرجاء إدخال اسمك' : null,
              ),
              const SizedBox(height: 14),
            ],

            // ── Email or Phone
            _StyledField(
              controller: contactController,
              label: 'الإيميل أو رقم الهاتف',
              hint: 'example@mail.com  أو  +962791234567',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: validateContact,
            ),
            const SizedBox(height: 14),

            // ── Password
            _StyledField(
              controller: passwordController,
              label: 'الرمز السري',
              hint: '• • • • • • • •',
              icon: Icons.lock_outline_rounded,
              obscureText: obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: onTogglePassword,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'الرجاء إدخال الرمز السري';
                if (v.length < 6) return 'الرمز يجب أن يكون 6 أحرف على الأقل';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Sign In / Next button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: isLoginMode ? onLogin : onNextStep,
                child: Text(
                  isLoginMode ? 'تسجيل الدخول' : 'التالي',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Toggle Login/Register
            TextButton(
              onPressed: onToggleMode,
              child: Text(
                isLoginMode ? 'ليس لديك حساب؟ إنشاء حساب جديد' : 'لديك حساب بالفعل؟ تسجيل الدخول',
                style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),

            // ── Divider
            Row(
              children: [
                const Expanded(
                  child: Divider(color: AppColors.border, height: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'أو',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Expanded(
                  child: Divider(color: AppColors.border, height: 1),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Google Sign-In (قريباً)
            Opacity(
              opacity: 0.55,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onGoogleSignIn,
                      icon: const Text(
                        'G',
                        style: TextStyle(
                          color: AppColors.googleBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      label: const Text('تسجيل الدخول بـ Google'),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.charcoal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('قريباً',
                          style: TextStyle(color: AppColors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Shared styled text field ─────────────────────────────────────────────────
class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _StyledField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }
}

// ─── Shared page title widget (used by steps 2, 3, 4) ────────────────────────
class _PageTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PageTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.charcoal,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 2 – Marital Status ──────────────────────────────────────────────────
class _Step2StatusPage extends StatelessWidget {
  final String selected;
  final DateTime? selectedDate;
  final ValueChanged<String> onSelect;
  final ValueChanged<DateTime?> onSelectDate;

  const _Step2StatusPage({
    required this.selected,
    required this.selectedDate,
    required this.onSelect,
    required this.onSelectDate,
  });

  static const _options = [
    StatusOption(
      label: 'شاب',
      icon: Icons.man_rounded,
      description: 'أعزب / غير متزوج',
    ),
    StatusOption(
      label: 'شابة',
      icon: Icons.woman_rounded,
      description: 'عزباء / غير متزوجة',
    ),
    StatusOption(
      label: 'متزوج',
      icon: Icons.people_rounded,
      description: 'رجل متزوج',
    ),
    StatusOption(
      label: 'متزوجة',
      icon: Icons.favorite_rounded,
      description: 'امرأة متزوجة',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PageTitle(
          title: 'ما هي حالتك؟',
          subtitle: 'اختر وضعك الاجتماعي',
        ),
        
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _options.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _SelectionCard(
              label: _options[i].label,
              icon: _options[i].icon,
              description: _options[i].description,
              isSelected: selected == _options[i].label,
              onTap: () => onSelect(_options[i].label),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Date Picker
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'تاريخ الميلاد',
                style: TextStyle(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime(2000),
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.charcoal,
                            onPrimary: AppColors.white,
                            onSurface: AppColors.charcoal,
                          ),
                          textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.charcoal,
                            ),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    onSelectDate(date);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary, size: 20),
                      Text(
                        selectedDate != null
                            ? '${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}'
                            : 'اختر تاريخ ميلادك',
                        style: TextStyle(
                          color: selectedDate != null ? AppColors.charcoal : AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: selectedDate != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class StatusOption {
  final String label;
  final IconData icon;
  final String description;
  const StatusOption({
    required this.label,
    required this.icon,
    required this.description,
  });
}

// ─── Step 3 – Goal ───────────────────────────────────────────────────────────
class _Step3GoalPage extends StatelessWidget {
  final String selected;
  final TextEditingController amountController;
  final ValueChanged<String> onSelect;

  const _Step3GoalPage({
    required this.selected,
    required this.amountController,
    required this.onSelect,
  });

  static const _options = [
    GoalOption(
      label: 'زواج',
      icon: Icons.volunteer_activism_rounded,
      description: 'ادخار للزواج والارتباط',
    ),
    GoalOption(
      label: 'بيت',
      icon: Icons.home_rounded,
      description: 'شراء أو بناء منزل',
    ),
    GoalOption(
      label: 'ترك التدخين',
      icon: Icons.smoke_free_rounded,
      description: 'طريقك نحو حياة أكثر صحة',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PageTitle(title: 'ما هو هدفك؟', subtitle: 'حدد ما تسعى إليه'),
        
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _options.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _SelectionCard(
              label: _options[i].label,
              icon: _options[i].icon,
              description: _options[i].description,
              isSelected: selected == _options[i].label,
              onTap: () => onSelect(_options[i].label),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Target Amount Field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'مبلغ الهدف',
                style: TextStyle(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('JD', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  filled: true,
                  fillColor: AppColors.cardFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.charcoal, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class GoalOption {
  final String label;
  final IconData icon;
  final String description;
  const GoalOption({
    required this.label,
    required this.icon,
    required this.description,
  });
}

// ─── Step 4 – Challenge Type ──────────────────────────────────────────────────
class _Step4ChallengePage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _Step4ChallengePage({required this.selected, required this.onSelect});

  static const _options = [
    ChallengeOption(
      label: 'فردي',
      icon: Icons.person_rounded,
      description: 'تحدَّ نفسك وحدك',
    ),
    ChallengeOption(
      label: 'تعاوني',
      icon: Icons.groups_rounded,
      description: 'ادخر مع شريك أو مجموعة',
    ),
    ChallengeOption(
      label: 'تنافسي',
      icon: Icons.emoji_events_rounded,
      description: 'تنافس مع الآخرين',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PageTitle(
          title: 'نوع التحدي',
          subtitle: 'كيف تريد أن تتحدى نفسك؟',
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _options.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _SelectionCard(
              label: _options[i].label,
              icon: _options[i].icon,
              description: _options[i].description,
              isSelected: selected == _options[i].label,
              onTap: () => onSelect(_options[i].label),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class ChallengeOption {
  final String label;
  final IconData icon;
  final String description;
  const ChallengeOption({
    required this.label,
    required this.icon,
    required this.description,
  });
}

// ─── Shared Selection Card ────────────────────────────────────────────────────
class _SelectionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.label,
    required this.icon,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.charcoal : AppColors.cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.charcoal : AppColors.border,
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.charcoal.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // Icon box – rounded square matching image style
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.18)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 26,
                    color: isSelected
                        ? AppColors.white
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.white
                              : AppColors.charcoal,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.72)
                              : AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Check indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.white : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.white : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: AppColors.charcoal,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Navigation (pages 2-4 only) ──────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentStep;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomNav({
    required this.currentStep,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderLight, width: 1)),
      ),
      child: Row(
        children: [
          // ── Back button (square pill, left side)
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.cardFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.charcoal,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── Next / Finish button
          Expanded(
            child: GestureDetector(
              onTap: onNext,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.charcoal,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLast ? 'ابدأ التحدي' : 'التالي',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLast
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                      color: AppColors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
