import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';
import 'package:one_hunderd/features/home/screens/home_screen.dart';

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
  bool _isLoading = false;

  // ── Rate Limiting ──────────────────────────────────────────────────────────
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 2);

  // Step-1
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Step-2
  String _selectedGender = 'ذكر';
  String _selectedStatus = 'أعزب';
  DateTime? _selectedBirthDate;

  // Step-3
  String _selectedGoal = '';
  final _targetAmountController = TextEditingController();

  // Challenge Type (Default: فردي)
  final String _selectedChallengeType = 'فردي';

  // Step-4 Avatar
  int _selectedAvatarIndex = 0;

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

  // ── Loading helper ────────────────────────────────────────────────────────
  void _setLoading(bool value) {
    if (mounted) setState(() => _isLoading = value);
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  /// Returns remaining lockout seconds (0 = not locked)
  int _remainingLockoutSeconds() {
    if (_lockoutUntil == null) return 0;
    final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void _login() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    // ── Client-side lockout check ──
    final remaining = _remainingLockoutSeconds();
    if (remaining > 0) {
      _showSnack('كثرة المحاولات. انتظر $remaining ثانية قبل المحاولة مجدداً.');
      return;
    }

    _setLoading(true);
    try {
      final email = _getValidEmail();
      final password = _passwordController.text;
      await context.read<SavingsProvider>().login(email, password);
      // ── Reset attempts on success ──
      setState(() {
        _failedAttempts = 0;
        _lockoutUntil = null;
      });
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'حدث خطأ';
      bool isCredentialError = false;
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
        isCredentialError = true;
        msg = 'البريد الإلكتروني أو الرمز السري غير صحيح.';
      } else if (e.code == 'invalid-email') {
        msg = 'صيغة الإيميل غير صحيحة.';
      } else if (e.code == 'too-many-requests') {
        msg = 'تم تجاوز عدد المحاولات المسموح بها. حاول مرة أخرى لاحقاً.';
      } else if (e.code == 'operation-not-allowed') {
        msg = 'يجب تفعيل Email/Password من Firebase Console';
      }
      // ── Increment local counter on credential errors ──
      if (isCredentialError) {
        setState(() {
          _failedAttempts++;
          if (_failedAttempts >= _maxAttempts) {
            _lockoutUntil = DateTime.now().add(_lockoutDuration);
            _failedAttempts = 0;
            msg = 'لقد تجاوزت $_maxAttempts محاولات فاشلة. يُرجى الانتظار دقيقتين.';
          }
        });
      }
      _showSnack('خطأ: $msg');
    } catch (e) {
      _showSnack('خطأ غير متوقع: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ── Forgot Password ───────────────────────────────────────────────────────
  void _showForgotPassword() {
    final ctrl = TextEditingController(
      text: _contactController.text.trim().contains('@')
          ? _contactController.text.trim()
          : '',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(emailController: ctrl),
    );
  }

  void _nextStep() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
      if (!_isLoginMode && _nameController.text.trim().isEmpty) {
        _showSnack('الرجاء إدخال اسمك');
        return;
      }
      if (!_isLoginMode) {
        final email = _getValidEmail();
        final password = _passwordController.text;
        _setLoading(true);
        try {
          // ── فحص الإيميل بالإنشاء ثم الحذف الفوري (بدون حسابات مهجورة) ──
          final tempCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          await tempCred.user?.delete(); // حذف الحساب المؤقت فوراً
        } on FirebaseAuthException catch (e) {
          _setLoading(false);
          String msg = e.message ?? 'حدث خطأ في التسجيل';
          if (e.code == 'email-already-in-use') {
            msg = 'هذا البريد الإلكتروني مسجل مسبقاً، الرجاء تسجيل الدخول.';
          } else if (e.code == 'invalid-email') {
            msg = 'صيغة الإيميل غير صحيحة.';
          } else if (e.code == 'weak-password') {
            msg = 'الرمز السري ضعيف جداً (6 خانات على الأقل).';
          }
          _showSnack(msg);
          return;
        } catch (e) {
          _setLoading(false);
          _showSnack('حدث خطأ: $e');
          return;
        }
        _setLoading(false);
      }
    }
    if (_currentStep == 1) {
      if (_selectedGender.isEmpty) {
        _showSnack('الرجاء اختيار الجنس');
        return;
      }
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
      final amountText = _targetAmountController.text.trim();
      if (amountText.isEmpty) {
        _showSnack('الرجاء إدخال مبلغ الهدف');
        return;
      }
      final amount = double.tryParse(amountText.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (amount == null || amount < 10) {
        _showSnack('مبلغ الهدف يجب أن يكون 10 دينار أو أكثر');
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
    AppSnackbar.show(
      context: context,
      message: msg,
      isSuccess: false, // assuming error/info for these snacks
    );
  }

  void _finish() async {
    if (_isLoading) return;
    final targetAmountText = _targetAmountController.text.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    final double? parsedAmount = double.tryParse(targetAmountText);

    final isFemale = _selectedGender == 'أنثى';

    _setLoading(true);
    try {
      await context.read<SavingsProvider>().signUp(
        email: _getValidEmail(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        gender: isFemale ? 'Female' : 'Male',
        contact: _contactController.text.trim(),
        financialGoal: parsedAmount ?? 5050.0,
        maritalStatus: _selectedStatus.isNotEmpty ? _selectedStatus : (isFemale ? 'عزباء' : 'أعزب'),
        goal: _selectedGoal,
        challengeType: _selectedChallengeType.isNotEmpty ? _selectedChallengeType : 'فردي',
        birthDate: _selectedBirthDate,
        avatarIndex: _selectedAvatarIndex,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
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
    } finally {
      _setLoading(false);
    }
  }

  void _signInWithGoogle() {
    // Google Sign-In سيتم تفعيله لاحقاً
    AppSnackbar.show(
      context: context,
      message: 'تسجيل الدخول بـ Google سيتوفر قريباً ✨',
      isSuccess: false,
      isInfo: true,
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
                    isLoading: _isLoading,
                    onToggleMode: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                        _formKey.currentState?.reset();
                        // مسح الحقول لمنع تسرب البيانات بين الوضعين
                        _nameController.clear();
                        _contactController.clear();
                        _passwordController.clear();
                      });
                    },
                    onLogin: _login,
                    onNextStep: _nextStep,
                    onForgotPassword: _showForgotPassword,
                    onGoogleSignIn: _signInWithGoogle,
                  ),
                  // Pages 2-4: title inside the page, no logo
                  _Step2StatusPage(
                    selectedGender: _selectedGender,
                    selectedStatus: _selectedStatus,
                    selectedDate: _selectedBirthDate,
                    onSelectGender: (v) => setState(() {
                      _selectedGender = v;
                      _selectedAvatarIndex = (v == 'أنثى') ? 2 : 0;
                    }),
                    onSelectStatus: (v) {
                      setState(() {
                        _selectedStatus = v;
                        if ((v == 'متزوج' || v == 'متزوجة') && _selectedGoal == 'زواج') {
                          _selectedGoal = '';
                        }
                      });
                    },
                    onSelectDate: (v) => setState(() => _selectedBirthDate = v),
                  ),
                  _Step3GoalPage(
                    selectedStatus: _selectedStatus,
                    selected: _selectedGoal,
                    amountController: _targetAmountController,
                    onSelect: (v) => setState(() => _selectedGoal = v),
                  ),
                  _Step4AvatarPage(
                    selectedIndex: _selectedAvatarIndex,
                    onSelect: (idx) => setState(() => _selectedAvatarIndex = idx),
                  ),
                ],
              ),
            ),

            // ── Bottom nav: only show on pages 2-4 ──
            if (_currentStep > 0)
              _BottomNav(
                currentStep: _currentStep,
                isLoading: _isLoading,
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
  final bool isLoading;
  final TextEditingController nameController;
  final TextEditingController contactController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final String? Function(String?) validateContact;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleMode;
  final VoidCallback onLogin;
  final VoidCallback onNextStep;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogleSignIn;

  const _Step1InfoPage({
    required this.formKey,
    required this.isLoginMode,
    required this.isLoading,
    required this.nameController,
    required this.contactController,
    required this.passwordController,
    required this.obscurePassword,
    required this.validateContact,
    required this.onTogglePassword,
    required this.onToggleMode,
    required this.onLogin,
    required this.onNextStep,
    required this.onForgotPassword,
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
              child: Image.asset(
                'assets/images/Logo.png',
                height: 80,
                fit: BoxFit.contain,
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
                validator: (v) {
                  if (!isLoginMode) {
                    if (v == null || v.trim().isEmpty) return 'الرجاء إدخال اسمك';
                    if (v.trim().length < 2) return 'الاسم يجب أن يكون حرفين على الأقل';
                    if (v.trim().length > 50) return 'الاسم طويل جداً (50 حرف كحد أقصى)';
                  }
                  return null;
                },
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
            const SizedBox(height: 12),

            // ── Forgot password (login mode only)
            if (isLoginMode)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onForgotPassword,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'نسيت الرمز السري؟',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // ── Sign In / Next button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: isLoading ? null : (isLoginMode ? onLogin : onNextStep),
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isLoginMode ? 'تسجيل الدخول' : 'التالي',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 12),

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

// ─── Step 2 – Gender & Marital Status ──────────────────────────────────────────
class _Step2StatusPage extends StatelessWidget {
  final String selectedGender;
  final String selectedStatus;
  final DateTime? selectedDate;
  final ValueChanged<String> onSelectGender;
  final ValueChanged<String> onSelectStatus;
  final ValueChanged<DateTime?> onSelectDate;

  const _Step2StatusPage({
    required this.selectedGender,
    required this.selectedStatus,
    required this.selectedDate,
    required this.onSelectGender,
    required this.onSelectStatus,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final isFemale = selectedGender == 'أنثى';
    final statusOption1 = isFemale ? 'عزباء' : 'أعزب';
    final statusOption2 = isFemale ? 'متزوجة' : 'متزوج';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PageTitle(
            title: 'معلوماتك الشخصية',
            subtitle: 'اختر الجنس والحالة الاجتماعية لتخصيص تجربتك',
          ),
          
          // ── Section 1: Gender
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'الجنس',
                  style: TextStyle(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _CompactSelectionCard(
                        label: 'ذكر',
                        icon: Icons.man_rounded,
                        isSelected: selectedGender == 'ذكر',
                        onTap: () => onSelectGender('ذكر'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CompactSelectionCard(
                        label: 'أنثى',
                        icon: Icons.woman_rounded,
                        isSelected: selectedGender == 'أنثى',
                        onTap: () => onSelectGender('أنثى'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Section 2: Marital Status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'الحالة الاجتماعية',
                  style: TextStyle(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _CompactSelectionCard(
                        label: statusOption1,
                        icon: isFemale ? Icons.female_rounded : Icons.male_rounded,
                        isSelected: selectedStatus == statusOption1 || selectedStatus == 'أعزب' || selectedStatus == 'عزباء' || selectedStatus == 'شاب' || selectedStatus == 'شابة',
                        onTap: () => onSelectStatus(statusOption1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CompactSelectionCard(
                        label: statusOption2,
                        icon: Icons.people_rounded,
                        isSelected: selectedStatus == statusOption2 || selectedStatus == 'متزوج' || selectedStatus == 'متزوجة',
                        onTap: () => onSelectStatus(statusOption2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

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
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    final initialDate = selectedDate ?? DateTime(2000, 6, 15);
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (BuildContext ctx) {
                        return _CustomDatePickerModal(
                          initialDate: initialDate,
                          onConfirm: (date) {
                            onSelectDate(date);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    );
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
      ),
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
  final String selectedStatus;
  final String selected;
  final TextEditingController amountController;
  final ValueChanged<String> onSelect;

  const _Step3GoalPage({
    required this.selectedStatus,
    required this.selected,
    required this.amountController,
    required this.onSelect,
  });

  static const _allOptions = [
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
    final isMarried = selectedStatus == 'متزوج' || selectedStatus == 'متزوجة';
    final options = _allOptions.where((opt) {
      if (isMarried && opt.label == 'زواج') return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PageTitle(title: 'ما هو هدفك؟', subtitle: 'حدد ما تسعى إليه'),
        
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: options.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _SelectionCard(
              label: options[i].label,
              icon: options[i].icon,
              description: options[i].description,
              isSelected: selected == options[i].label,
              onTap: () => onSelect(options[i].label),
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
                keyboardType: TextInputType.number,
                maxLength: 7,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'مثال: 5050',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('JD', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'sans-serif')),
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

// ─── Step 4 – Avatar Selection ──────────────────────────────────────────────
class _Step4AvatarPage extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _Step4AvatarPage({
    required this.selectedIndex,
    required this.onSelect,
  });

  static const _avatars = [
    'assets/images/AVATAR.webp',
    'assets/images/AVATAR-3.webp',
    'assets/images/AVATAR-4.webp',
    'assets/images/AVATAR-5.webp',
    'assets/images/AVATAR-6.png',
    'assets/images/AVATAR-1.webp',
    'assets/images/AVATAR-2.webp',
    'assets/images/AVATAR-7.webp',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PageTitle(
          title: 'اختر شخصيتك',
          subtitle: 'اختر الصورة الرمزية التي تعبر عنك لتظهر في التحدي والقائمة الرئيسية',
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.95,
            ),
            itemCount: _avatars.length,
            itemBuilder: (context, index) {
              final isSelected = selectedIndex == index;
              return GestureDetector(
                onTap: () => onSelect(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.charcoal.withValues(alpha: 0.08) : AppColors.cardFill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.charcoal : AppColors.border,
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.charcoal.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: ClipOval(
                          child: Image.asset(
                            _avatars[index],
                            fit: BoxFit.cover,
                            width: 68,
                            height: 68,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.charcoal,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
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

// ─── Compact Selection Card (used for side-by-side grids) ─────────────────────
class _CompactSelectionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompactSelectionCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      height: 52,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.charcoal : AppColors.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.charcoal : AppColors.border,
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.charcoal.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? AppColors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.white : AppColors.charcoal,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Navigation (pages 2-3 only) ──────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentStep;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomNav({
    required this.currentStep,
    required this.isLoading,
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
          // ── Back button
          GestureDetector(
            onTap: isLoading ? null : onBack,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isLoading ? AppColors.borderLight : AppColors.cardFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: isLoading ? AppColors.textSecondary : AppColors.charcoal,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── Next / Finish button
          Expanded(
            child: GestureDetector(
              onTap: isLoading ? null : onNext,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  color: isLoading
                      ? AppColors.charcoal.withValues(alpha: 0.6)
                      : AppColors.charcoal,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
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
          ),
        ],
      ),
    );
  }
}

// ─── Custom Date Picker ──────────────────────────────────────────────────────
class _CustomDatePickerModal extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onConfirm;

  const _CustomDatePickerModal({
    required this.initialDate,
    required this.onConfirm,
  });

  @override
  State<_CustomDatePickerModal> createState() => _CustomDatePickerModalState();
}

class _CustomDatePickerModalState extends State<_CustomDatePickerModal> {
  late int selectedYear;
  late int selectedMonth;
  late int selectedDay;

  final int minYear = 1920;
  final int maxYear = DateTime.now().year;

  final List<String> monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  late FixedExtentScrollController yearController;
  late FixedExtentScrollController monthController;
  late FixedExtentScrollController dayController;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
    selectedMonth = widget.initialDate.month;
    selectedDay = widget.initialDate.day;

    yearController = FixedExtentScrollController(initialItem: selectedYear - minYear);
    monthController = FixedExtentScrollController(initialItem: selectedMonth - 1);
    dayController = FixedExtentScrollController(initialItem: selectedDay - 1);
  }

  @override
  void dispose() {
    yearController.dispose();
    monthController.dispose();
    dayController.dispose();
    super.dispose();
  }

  int getDaysInMonth(int year, int month) {
    if (month == 2) {
      return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  void updateDayController() {
    int daysInCurrentMonth = getDaysInMonth(selectedYear, selectedMonth);
    if (selectedDay > daysInCurrentMonth) {
      setState(() {
        selectedDay = daysInCurrentMonth;
      });
      dayController.jumpToItem(selectedDay - 1);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Text(
            'اختر تاريخ ميلادك',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: SizedBox(
                height: 120, // Exactly fits 3 items of 40px each (limits view to 1 above, 1 selected, 1 below)
                child: Directionality(
                  textDirection: TextDirection.ltr, // strictly LTR: Year(Left), Month(Center), Day(Right)
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Continuous selection overlay with borders
                      Container(
                        height: 40,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.borderLight.withValues(alpha: 0.3),
                          border: const Border(
                            top: BorderSide(color: AppColors.border, width: 1.5),
                            bottom: BorderSide(color: AppColors.border, width: 1.5),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          // Year (Left)
                          Expanded(
                            flex: 1,
                            child: CupertinoPicker.builder(
                              scrollController: yearController,
                              itemExtent: 40,
                              diameterRatio: 1.5,
                              squeeze: 1.1,
                              selectionOverlay: const SizedBox(), // custom overlay is drawn underneath
                              onSelectedItemChanged: (index) {
                                selectedYear = minYear + index;
                                updateDayController();
                              },
                              childCount: maxYear - minYear + 1,
                              itemBuilder: (context, index) {
                                final isSelected = (minYear + index) == selectedYear;
                                return Center(
                                  child: Text(
                                    '${minYear + index}',
                                    style: GoogleFonts.tajawal(
                                      fontSize: isSelected ? 20 : 16,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.charcoal : AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Month (Center)
                          Expanded(
                            flex: 2,
                            child: CupertinoPicker.builder(
                              scrollController: monthController,
                              itemExtent: 40,
                              diameterRatio: 1.5,
                              squeeze: 1.1,
                              selectionOverlay: const SizedBox(),
                              onSelectedItemChanged: (index) {
                                selectedMonth = index + 1;
                                updateDayController();
                              },
                              childCount: 12,
                              itemBuilder: (context, index) {
                                final isSelected = (index + 1) == selectedMonth;
                                return Center(
                                  child: Text(
                                    '${monthNames[index]} (${index + 1})',
                                    style: GoogleFonts.tajawal(
                                      fontSize: isSelected ? 18 : 15,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.charcoal : AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Day (Right)
                          Expanded(
                            flex: 1,
                            child: CupertinoPicker.builder(
                              scrollController: dayController,
                              itemExtent: 40,
                              diameterRatio: 1.5,
                              squeeze: 1.1,
                              selectionOverlay: const SizedBox(),
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedDay = index + 1;
                                });
                              },
                              childCount: getDaysInMonth(selectedYear, selectedMonth),
                              itemBuilder: (context, index) {
                                final isSelected = (index + 1) == selectedDay;
                                return Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.tajawal(
                                      fontSize: isSelected ? 20 : 16,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.charcoal : AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                widget.onConfirm(DateTime(selectedYear, selectedMonth, selectedDay));
              },
              child: const Text('تأكيد الاختيار', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Forgot Password Bottom Sheet ───────────────────────────────────────────────────────────────
class _ForgotPasswordSheet extends StatefulWidget {
  final TextEditingController emailController;
  const _ForgotPasswordSheet({required this.emailController});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  bool _isSending = false;
  bool _sent = false;
  final _formKey = GlobalKey<FormState>();
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: widget.emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      String msg = 'حدث خطأ غير متوقع';
      if (e.code == 'user-not-found') {
        msg = 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';
      } else if (e.code == 'invalid-email') {
        msg = 'صيغة الإيميل غير صحيحة.';
      } else if (e.code == 'too-many-requests') {
        msg = 'تم إرسال بريد بالفعل، أو تجاوزت عدد المحاولات.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(28),
      ),
      child: _sent ? _buildSuccessView() : _buildFormView(),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              color: Colors.green, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'تم إرسال البريد! ✅',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'افتح بريدك الإلكتروني واضغط على رابط إعادة تعيين الرمز السري لـ ${widget.emailController.text.trim()}',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('تمام',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_reset_rounded,
                    color: AppColors.charcoal, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نسيت الرمز السري؟',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'سنرسل لك رابط استعادة الوصول على بريدك',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Email field
          TextFormField(
            controller: widget.emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'بريدك الإلكتروني',
              hintText: 'example@mail.com',
              prefixIcon:
                  Icon(Icons.email_outlined, size: 20, color: AppColors.textSecondary),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'الرجاء إدخال بريدك الإلكتروني';
              }
              if (!_emailRegex.hasMatch(v.trim())) {
                return 'صيغة الإيميل غير صحيحة';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // ── Send button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSending ? null : _send,
              child: _isSending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('إرسال رابط الاستعادة',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
