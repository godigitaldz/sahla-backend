import "dart:async";
import "dart:ui";

import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl_phone_field/intl_phone_field.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "../l10n/app_localizations.dart";
import "../services/auth_service.dart";
import "permissions_screen.dart";

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _verificationCodeController =
      TextEditingController();
  final GlobalKey<FormState> _phoneFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _codeFormKey = GlobalKey<FormState>();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  bool _codeSent = false;
  bool _isVerifying = false;
  String _selectedCountryCode = "+213";
  int _resendCountdown = 0;
  Timer? _countdownTimer;
  Timer? _expiryTimer; // Timer to update expiry countdown
  DateTime? _codeSentTime; // Track when the code was sent for 10-minute expiry

  late AuthService _authService;

  // Keyboard handling
  bool _isKeyboardVisible = false;
  double _keyboardHeight = 0;
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _codeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();

    // Set up focus listeners for input fields
    _phoneFocusNode.addListener(_onPhoneFocusChange);
    _codeFocusNode.addListener(_onCodeFocusChange);

    // Listen for keyboard visibility changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupKeyboardListener();
    });
  }

  void _setupKeyboardListener() {
    // Listen to view insets changes (keyboard visibility)
    final mediaQuery = MediaQuery.of(context);
    setState(() {
      _keyboardHeight = mediaQuery.viewInsets.bottom;
      _isKeyboardVisible = _keyboardHeight > 0;
    });

    // Set up a listener for continuous keyboard height updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Listen to MediaQuery changes for real-time keyboard updates
        final currentContext = context;
        void updateKeyboardInfo() {
          if (mounted && currentContext.mounted) {
            final mq = MediaQuery.of(currentContext);
            final newKeyboardHeight = mq.viewInsets.bottom;
            final keyboardVisible = newKeyboardHeight > 0;

            if (newKeyboardHeight != _keyboardHeight ||
                keyboardVisible != _isKeyboardVisible) {
              setState(() {
                _keyboardHeight = newKeyboardHeight;
                _isKeyboardVisible = keyboardVisible;
              });
            }
          }
        }

        // Check for updates periodically while keyboard might be visible
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (mounted) {
            updateKeyboardInfo();
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  void _onPhoneFocusChange() {
    if (_phoneFocusNode.hasFocus) {
      // Phone field gained focus - ensure keyboard is handled properly
      setState(() {
        // Trigger keyboard detection update
      });
    }
  }

  void _onCodeFocusChange() {
    if (_codeFocusNode.hasFocus) {
      // Code field gained focus - ensure keyboard is handled properly
      setState(() {
        // Trigger keyboard detection update
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _phoneController.dispose();
    _verificationCodeController.dispose();
    _countdownTimer?.cancel();
    _expiryTimer?.cancel();
    _phoneFocusNode.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _resendCountdown = 30;
    _codeSentTime = DateTime.now(); // Record when code was sent

    // Start resend countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });

    // Start expiry countdown timer (updates every second)
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        return;
      }
      if (_isCodeExpired()) {
        timer.cancel();
        setState(() {}); // Trigger UI update to show expired state
      } else {
        setState(() {}); // Update expiry countdown display
      }
    });
  }

  Future<void> _sendVerificationCode() async {
    if (!_codeSent) {
      if (_phoneFormKey.currentState == null ||
          !_phoneFormKey.currentState!.validate()) {
        return;
      }
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final phoneNumber = _phoneController.text.trim();
      if (phoneNumber.isEmpty) {
        throw Exception("Please enter a valid phone number");
      }
      final String countryCode = _selectedCountryCode.startsWith("+")
          ? _selectedCountryCode.substring(1)
          : _selectedCountryCode;
      final result = await _authService.sendPhoneOtp(phoneNumber, countryCode,
          captchaToken: null);
      if (result["success"] == true) {
        if (!mounted) {
          return;
        }
        setState(() {
          _codeSent = true;
          _isLoading = false;
        });
        _startCountdown();
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n.verificationCodeSentTo(countryCode, phoneNumber)),
              backgroundColor: Colors.green.shade600),
        );
      } else {
        throw Exception(result["error"] ?? "Failed to send verification code");
      }
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red.shade600),
      );
    }
  }

  Future<void> _verifyCode() async {
    if (_codeFormKey.currentState == null ||
        !_codeFormKey.currentState!.validate()) {
      return;
    }

    // Check if code has expired
    if (_isCodeExpired()) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.verificationCodeExpiredMessage),
          backgroundColor: Colors.red.shade600,
        ),
      );
      _resetVerificationState();
      return;
    }

    setState(() {
      _isVerifying = true;
    });
    try {
      final code = _verificationCodeController.text.trim();
      final phoneNumber = _phoneController.text.trim();
      final String countryCode = _selectedCountryCode.startsWith("+")
          ? _selectedCountryCode.substring(1)
          : _selectedCountryCode;
      final result =
          await _authService.verifyPhoneCode(phoneNumber, countryCode, code);
      if (result["success"] == true) {
        if (!mounted) {
          return;
        }
        await Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const PermissionsScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      } else {
        throw Exception(result["error"] ?? "Failed to verify code");
      }
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isVerifying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red.shade600),
      );
    }
  }

  void _resendCode() {
    if (_resendCountdown > 0) {
      return;
    }

    // If code is expired, reset the verification state first
    if (_isCodeExpired()) {
      _resetVerificationState();
    }

    _sendVerificationCode();
  }

  void _resetVerificationState() {
    setState(() {
      _codeSent = false;
      _verificationCodeController.clear();
      _countdownTimer?.cancel();
      _expiryTimer?.cancel();
      _resendCountdown = 0;
      _codeSentTime = null; // Reset code sent time
    });
  }

  /// Check if the verification code has expired (10 minutes from when it was sent)
  bool _isCodeExpired() {
    if (_codeSentTime == null) {
      return false;
    }
    final now = DateTime.now();
    final expiryTime = _codeSentTime!.add(const Duration(minutes: 10));
    return now.isAfter(expiryTime);
  }

  /// Get remaining time until code expires
  Duration? _getRemainingTime() {
    if (_codeSentTime == null) {
      return null;
    }
    final now = DateTime.now();
    final expiryTime = _codeSentTime!.add(const Duration(minutes: 10));
    if (now.isAfter(expiryTime)) {
      return Duration.zero;
    }
    return expiryTime.difference(now);
  }

  @override
  Widget build(BuildContext context) {
    _authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background image covering full screen
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Image.asset(
                "assets/auth.png",
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Auth form container - centered with crystal transparent glassmorphism style
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  constraints: const BoxConstraints(maxWidth: 520),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: _buildAuthCard(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.allYourNeedsInOneApp,
          style: GoogleFonts.saira(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _codeSent ? _buildVerificationCodeInput() : _buildPhoneInput(),
        ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _codeSent ? _buildVerifyButton() : _buildNextButton(),
        ),
        // Continue as Guest button (only show when not verifying code)
        if (!_codeSent) ...[
          const SizedBox(height: 16),
          _buildContinueAsGuestButton(),
        ],
        // Privacy Policy text
        if (!_codeSent) _buildPrivacyPolicyText(),
        // Resend/change options integrated into verification section to avoid duplication
      ],
    );
  }

  Widget _buildPhoneInput() {
    final l10n = AppLocalizations.of(context)!;

    return Form(
      key: _phoneFormKey,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8)),
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: IntlPhoneField(
          controller: _phoneController,
          focusNode: _phoneFocusNode,
          decoration: InputDecoration(
            hintText: l10n.enterPhoneNumber,
            hintStyle:
                GoogleFonts.roboto(fontSize: 15, color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: Colors.white, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            counterText: "",
          ),
          initialCountryCode: "DZ",
          onChanged: (phone) {
            setState(() {
              _selectedCountryCode = "+${phone.countryCode}";
            });
          },
          onCountryChanged: (country) {
            setState(() {
              _selectedCountryCode = "+${country.code}";
            });
          },
          validator: (phone) {
            if (phone == null || phone.number.isEmpty) {
              return l10n.pleaseEnterYourPhoneNumber;
            }
            if (phone.number.length < 7) {
              return l10n.pleaseEnterValidPhone;
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildVerificationCodeInput() {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.verificationCode,
                  style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black)),
              TextButton(
                onPressed: _resetVerificationState,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  alignment:
                      isArabic ? Alignment.centerLeft : Alignment.centerRight,
                ),
                child: Text(l10n.changePhoneNumber,
                    style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8)),
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: TextFormField(
              controller: _verificationCodeController,
              focusNode: _codeFocusNode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  letterSpacing: 2),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "000000",
                hintStyle: GoogleFonts.roboto(
                    fontSize: 16, color: Colors.grey[600], letterSpacing: 2),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                counterText: "",
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.pleaseEnterYourPhoneNumber;
                }
                if (value.trim().length != 6) {
                  return l10n.sixDigitCode;
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 6),
          _buildResendAndChangeOptions(),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return FractionallySizedBox(
      widthFactor: 0.75,
      child: SizedBox(
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8)),
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 4)),
            ],
            borderRadius: BorderRadius.circular(25),
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendVerificationCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF424242),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF424242))))
                : Text(AppLocalizations.of(context)!.continueButton,
                    style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF424242))),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return FractionallySizedBox(
      widthFactor: 0.75,
      child: SizedBox(
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8)),
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 4)),
            ],
            borderRadius: BorderRadius.circular(25),
          ),
          child: ElevatedButton(
            onPressed: _isVerifying ? null : _verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF424242),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: _isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF424242))))
                : Text(AppLocalizations.of(context)!.verifyAndContinue,
                    style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF424242))),
          ),
        ),
      ),
    );
  }

  Widget _buildResendAndChangeOptions() {
    final l10n = AppLocalizations.of(context)!;
    final remainingTime = _getRemainingTime();
    final isExpired = _isCodeExpired();

    return Column(
      children: [
        // Show code expiry information
        if (_codeSentTime != null && !isExpired)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.codeExpiresIn(
                remainingTime?.inMinutes ?? 0,
                (remainingTime?.inSeconds ?? 0) % 60,
              ),
              style: GoogleFonts.roboto(fontSize: 11, color: Colors.grey[600]),
            ),
          ),

        // Show expired message if code has expired
        if (isExpired)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.verificationCodeExpired,
              style: GoogleFonts.roboto(
                  fontSize: 11,
                  color: Colors.red[600],
                  fontWeight: FontWeight.w600),
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.didntReceiveCode,
                style: GoogleFonts.roboto(fontSize: 12, color: Colors.black)),
            TextButton(
              onPressed:
                  (_resendCountdown > 0 || isExpired) ? null : _resendCode,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                _resendCountdown > 0
                    ? l10n.resendIn(_resendCountdown)
                    : isExpired
                        ? l10n.requestNewCode
                        : l10n.resendCode,
                style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: (_resendCountdown > 0 || isExpired)
                        ? Colors.grey
                        : Colors.black),
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildPrivacyPolicyText() {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.roboto(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.9),
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: l10n.byClickingContinueYouAcknowledge,
            ),
            TextSpan(
              text: l10n.privacyPolicy,
              style: GoogleFonts.roboto(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
              recognizer: TapGestureRecognizer()..onTap = _openPrivacyPolicy,
            ),
            const TextSpan(
              text: ".",
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      final url = Uri.parse("https://www.sahla-delivery.com/privacy-policy");
      // Note: The "component name is null" log is just informational from Android
      // and doesn't prevent the URL from opening in the browser
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint("Error opening privacy policy: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Could not open privacy policy"),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _continueAsGuest() async {
    if (!mounted) return;

    try {
      // Navigate directly to PermissionsScreen without authentication
      await Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PermissionsScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (e) {
      debugPrint("Error continuing as guest: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Widget _buildContinueAsGuestButton() {
    final l10n = AppLocalizations.of(context)!;

    return TextButton(
      onPressed: _isLoading ? null : _continueAsGuest,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        l10n.continueAsGuest,
        style: GoogleFonts.roboto(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}
