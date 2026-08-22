import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:one_hunderd/features/challenges/providers/savings_provider.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';
import 'package:one_hunderd/core/widgets/app_snackbar.dart';
import 'package:one_hunderd/core/widgets/custom_date_picker_modal.dart';
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

  // Step-1: مفتاح واحد ثابت حتى لا يُعاد بناء Form عند تغيير الوضع
  final _step1FormKey = GlobalKey<FormState>();

  // Login Controllers
  final _loginContactController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // SignUp Controllers
  final _signUpNameController = TextEditingController();
  final _signUpContactController = TextEditingController();
  final _signUpPasswordController = TextEditingController();

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

  String _getValidEmail({required bool isLogin}) {
    final contact = isLogin
        ? _loginContactController.text.trim()
        : _signUpContactController.text.trim();
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
    if (!_step1FormKey.currentState!.validate()) return;

    // ── Client-side lockout check ──
    final remaining = _remainingLockoutSeconds();
    if (remaining > 0) {
      _showSnack('كثرة المحاولات. انتظر $remaining ثانية قبل المحاولة مجدداً.');
      return;
    }

    _setLoading(true);
    try {
      final email = _getValidEmail(isLogin: true);
      final password = _loginPasswordController.text;
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
    final contact = _loginContactController.text.trim().isNotEmpty
        ? _loginContactController.text.trim()
        : _signUpContactController.text.trim();
    final ctrl = TextEditingController(
      text: contact.contains('@') ? contact : '',
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
      if (_isLoginMode) {
        _login();
        return;
      }
      if (!_step1FormKey.currentState!.validate()) return;
      if (_signUpNameController.text.trim().isEmpty) {
        _showSnack('الرجاء إدخال اسمك');
        return;
      }
      final email = _getValidEmail(isLogin: false);
      final password = _signUpPasswordController.text;
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
        email: _getValidEmail(isLogin: false),
        password: _signUpPasswordController.text,
        fullName: _signUpNameController.text.trim(),
        gender: isFemale ? 'Female' : 'Male',
        contact: _signUpContactController.text.trim(),
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
      message: 'تسجيل الدخول بـ Google سيتوفر قريباً',
      isSuccess: false,
      isInfo: true,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _loginContactController.dispose();
    _loginPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpContactController.dispose();
    _signUpPasswordController.dispose();
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
                    formKey: _step1FormKey,
                    isLoginMode: _isLoginMode,
                    nameController: _signUpNameController,
                    contactController: _isLoginMode
                        ? _loginContactController
                        : _signUpContactController,
                    passwordController: _isLoginMode
                        ? _loginPasswordController
                        : _signUpPasswordController,
                    obscurePassword: _obscurePassword,
                    validateContact: _validateContact,
                    onTogglePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    isLoading: _isLoading,
                    onToggleMode: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
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

// ─── Animated Mode Tab Switcher ────────────────────────────────────────────────
class _AuthModeTabSwitcher extends StatelessWidget {
  final bool isLoginMode;
  final ValueChanged<bool> onTabChanged;

  const _AuthModeTabSwitcher({
    required this.isLoginMode,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.borderLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(25),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 8) / 2;
          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                alignment: isLoginMode ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: tabWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    borderRadius: BorderRadius.circular(21),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.charcoal.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  // تسجيل الدخول على اليسار (active slide goes left)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!isLoginMode) onTabChanged(true);
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontFamily: GoogleFonts.tajawal().fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isLoginMode ? AppColors.white : AppColors.charcoal,
                          ),
                          child: const Text('تسجيل الدخول', textDirection: TextDirection.rtl),
                        ),
                      ),
                    ),
                  ),
                  // حساب جديد على اليمين
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (isLoginMode) onTabChanged(false);
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontFamily: GoogleFonts.tajawal().fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: !isLoginMode ? AppColors.white : AppColors.charcoal,
                          ),
                          child: const Text('حساب جديد', textDirection: TextDirection.rtl),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
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
    double dragDelta = 0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => dragDelta = 0,
      onHorizontalDragUpdate: (details) => dragDelta += details.delta.dx,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        // سحب لليسار (dragDelta < -30 أو velocity < -100): الانتقال لـ "حساب جديد"
        if ((dragDelta < -30 || velocity < -100) && isLoginMode) {
          onToggleMode();
        }
        // سحب لليمين (dragDelta > 30 أو velocity > 100): الانتقال لـ "تسجيل الدخول"
        else if ((dragDelta > 30 || velocity > 100) && !isLoginMode) {
          onToggleMode();
        }
      },
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // ── Logo ──
              Center(
                child: Image.asset(
                  'assets/images/Logo.png',
                  height: 76,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 18),

              // ── Animated Header Text ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey<bool>(isLoginMode),
                  children: [
                    Text(
                      isLoginMode ? 'أهلاً بك مجدداً! 👋' : 'انضم إلينا اليوم! ✨',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w800,
                        fontSize: 23,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isLoginMode
                          ? 'سجّل دخولك لمتابعة تقدّمك في تحدي الـ 100 يوم'
                          : 'أنشئ حسابك وابدأ رحلة الادخار والالتزام',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Tab Switcher ──
              _AuthModeTabSwitcher(
                isLoginMode: isLoginMode,
                onTabChanged: (_) => onToggleMode(),
              ),
              const SizedBox(height: 22),

              // ── الحقول + الزر + خط "أو عبر" — انزلاق سلس ومثالي ──
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: ClipRect(
                  child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        ...previousChildren,
                        ?currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final isLoginForm = child.key == const ValueKey('login_form_key');
                    // Login على اليسار → يدخل من اليسار (-1.0)
                    // SignUp على اليمين → يدخل من اليمين (+1.0)
                    final Offset beginOffset = isLoginForm
                        ? const Offset(-1.0, 0.0)
                        : const Offset(1.0, 0.0);

                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: beginOffset,
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: isLoginMode
                      ? Column(
                          key: const ValueKey('login_form_key'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Email / Contact Field
                            _StyledField(
                              controller: contactController,
                              label: 'البريد الإلكتروني أو رقم الهاتف',
                              hint: 'example@mail.com أو +962791234567',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: validateContact,
                            ),
                            const SizedBox(height: 14),

                            // ── Password Field
                            _StyledField(
                              controller: passwordController,
                              label: 'كلمة المرور',
                              hint: '• • • • • • • •',
                              icon: Icons.lock_outline_rounded,
                              obscureText: obscurePassword,
                              suffixIcon: IconButton(
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    key: ValueKey<bool>(obscurePassword),
                                    color: AppColors.textSecondary,
                                    size: 22,
                                  ),
                                ),
                                onPressed: onTogglePassword,
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'الرجاء إدخال الرمز السري';
                                if (v.length < 6) return 'الرمز يجب أن يكون 6 أحرف على الأقل';
                                return null;
                              },
                            ),

                            // ── نسيت الرمز السري (تسجيل الدخول فقط)
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: onForgotPassword,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'نسيت الرمز السري؟',
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ── الزر الأسود (تسجيل الدخول)
                            _AnimatedSubmitButton(
                              isLoading: isLoading,
                              label: 'تسجيل الدخول',
                              onPressed: isLoading ? null : onLogin,
                            ),
                            const SizedBox(height: 18),

                            // ── خط "أو عبر"
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.border.withValues(alpha: 0.1),
                                          AppColors.border,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Text(
                                    'أو عبر',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.border,
                                          AppColors.border.withValues(alpha: 0.1),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          key: const ValueKey('signup_form_key'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Full Name (Sign Up)
                            _StyledField(
                              controller: nameController,
                              label: 'الاسم الكامل',
                              hint: 'أدخل اسمك الكريم',
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

                            // ── Email / Contact Field
                            _StyledField(
                              controller: contactController,
                              label: 'البريد الإلكتروني أو رقم الهاتف',
                              hint: 'example@mail.com أو +962791234567',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: validateContact,
                            ),
                            const SizedBox(height: 14),

                            // ── Password Field
                            _StyledField(
                              controller: passwordController,
                              label: 'كلمة المرور',
                              hint: '• • • • • • • •',
                              icon: Icons.lock_outline_rounded,
                              obscureText: obscurePassword,
                              suffixIcon: IconButton(
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    key: ValueKey<bool>(obscurePassword),
                                    color: AppColors.textSecondary,
                                    size: 22,
                                  ),
                                ),
                                onPressed: onTogglePassword,
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'الرجاء إدخال الرمز السري';
                                if (v.length < 6) return 'الرمز يجب أن يكون 6 أحرف على الأقل';
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            // ── الزر الأسود (التالي ←)
                            _AnimatedSubmitButton(
                              isLoading: isLoading,
                              label: 'التالي ←',
                              onPressed: isLoading ? null : onNextStep,
                            ),
                            const SizedBox(height: 18),

                            // ── خط "أو عبر"
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.border.withValues(alpha: 0.1),
                                          AppColors.border,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Text(
                                    'أو عبر',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.border,
                                          AppColors.border.withValues(alpha: 0.1),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── Google Sign-In ──
            Opacity(
              opacity: 0.75,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.2),
                ),
                child: InkWell(
                  onTap: onGoogleSignIn,
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'G',
                            style: TextStyle(
                              color: AppColors.googleBlue,
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'تسجيل الدخول بواسطة Google',
                            style: TextStyle(
                              color: AppColors.charcoal,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.charcoal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'قريباً',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
}

// ─── Animated Submit Button ──────────────────────────────────────────────────
class _AnimatedSubmitButton extends StatefulWidget {
  final bool isLoading;
  final String label;
  final VoidCallback? onPressed;

  const _AnimatedSubmitButton({
    required this.isLoading,
    required this.label,
    this.onPressed,
  });

  @override
  State<_AnimatedSubmitButton> createState() => _AnimatedSubmitButtonState();
}

class _AnimatedSubmitButtonState extends State<_AnimatedSubmitButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed == null ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onPressed == null ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.onPressed == null ? null : () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _isPressed ? 0.97 : 1.0,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: widget.onPressed == null
                ? AppColors.charcoal.withValues(alpha: 0.6)
                : AppColors.charcoal,
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.onPressed == null
                ? []
                : [
                    BoxShadow(
                      color: AppColors.charcoal.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.white,
                    ),
                  )
                : Text(
                    widget.label,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared styled text field ─────────────────────────────────────────────────
class _StyledField extends StatefulWidget {
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
  State<_StyledField> createState() => _StyledFieldState();
}

class _StyledFieldState extends State<_StyledField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.charcoal;
    final inactiveColor = AppColors.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(top: 10), // مساحة علوية تتسع للعنوان المرتفع بدون أي اقتصاص
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppColors.charcoal.withValues(alpha: 0.08),
                  blurRadius: 14,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        obscureText: widget.obscureText,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: AppColors.charcoal,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: inactiveColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: TextStyle(
            color: activeColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          hintText: widget.hint,
          hintTextDirection: TextDirection.rtl,
          fillColor: AppColors.surface,
          filled: true,
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          // suffixIcon بدل prefixIcon لأن النص RTL والأيقونة ستكون على اليمين
          suffixIcon: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: _isFocused ? 1.12 : 1.0,
            child: Icon(
              widget.icon,
              size: 21,
              color: _isFocused ? activeColor : inactiveColor,
            ),
          ),
          // إذا كان فيه suffixIcon أصلي (مثل زر إظهار كلمة المرور) نضعه كـ prefixIcon
          prefixIcon: widget.suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: activeColor, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.error, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.error, width: 2.0),
          ),
        ),
        validator: widget.validator,
      ),
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
                        return CustomDatePickerModal(
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
