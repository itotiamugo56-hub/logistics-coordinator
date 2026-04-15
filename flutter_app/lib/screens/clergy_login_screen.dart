import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/clergy_auth_provider.dart';

// ============================================================
// M3 COMPLIANT WITH EXISTING GREEN THEME
// ============================================================

class GreenM3Colors {
  static const Color primary = Color(0xFF00C853);      // Vibrant green
  static const Color primaryDark = Color(0xFF009624);   // Darker green
  static const Color primaryLight = Color(0xFF5EFB82);  // Light green
  static const Color onPrimary = Color(0xFFFFFFFF);     // White text on green
  static const Color surface = Color(0xFFF5F5F5);       // Light surface
  static const Color error = Color(0xFFD32F2F);         // Red error
  static const Color onSurface = Color(0xFF1C1B1F);     // Dark text
  static const Color onSurfaceVariant = Color(0xFF49454F); // Grey text
}

// ============================================================
// AUTHENTICATION FORM - PURE UI COMPONENT
// ============================================================

class AuthForm extends StatelessWidget {
  final String email;
  final String otp;
  final String? error;
  final bool isLoading;
  final VoidCallback onSubmit;
  final ValueChanged<String> onEmailChange;
  final ValueChanged<String> onOtpChange;

  const AuthForm({
    super.key,
    required this.email,
    required this.otp,
    this.error,
    required this.isLoading,
    required this.onSubmit,
    required this.onEmailChange,
    required this.onOtpChange,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo / Icon Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GreenM3Colors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.church,
              size: 60,
              color: GreenM3Colors.primary,
            ),
          ),
          const SizedBox(height: 32),

          // Title Section
          const Text(
            'Ministry of Repentance',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Clergy Portal',
            style: TextStyle(
              fontSize: 14,
              color: GreenM3Colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Email Input Field
          TextField(
            controller: TextEditingController(text: email)
              ..addListener(() => onEmailChange(TextEditingController(text: email).text)),
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'pastor@repentance.org',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: GreenM3Colors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            onChanged: onEmailChange,
          ),
          const SizedBox(height: 16),

          // OTP Input Field
          TextField(
            controller: TextEditingController(text: otp)
              ..addListener(() => onOtpChange(TextEditingController(text: otp).text)),
            decoration: InputDecoration(
              labelText: 'OTP Code',
              hintText: '123456',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: const Icon(Icons.security, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: GreenM3Colors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            onChanged: onOtpChange,
          ),
          const SizedBox(height: 24),

          // Submit Button
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(GreenM3Colors.primary),
              ),
            )
          else
            ElevatedButton(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: GreenM3Colors.primary,
                foregroundColor: GreenM3Colors.onPrimary,
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              child: const Text('LOGIN'),
            ),
          const SizedBox(height: 16),

          // Error Message
          if (error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GreenM3Colors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: GreenM3Colors.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: GreenM3Colors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Demo Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GreenM3Colors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: GreenM3Colors.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Demo Credentials',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: GreenM3Colors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'pastor@repentance.org',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'OTP: 123456',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: GreenM3Colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CONTAINER SCREEN - MANAGES STATE & NAVIGATION
// ============================================================

class ClergyLoginScreen extends StatefulWidget {
  const ClergyLoginScreen({super.key});

  @override
  State<ClergyLoginScreen> createState() => _ClergyLoginScreenState();
}

class _ClergyLoginScreenState extends State<ClergyLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(ClergyAuthProvider auth) async {
    if (_isSubmitting) return;

    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (email.isEmpty || otp.isEmpty) {
      _showFeedback('Please enter both email and OTP', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await auth.login(email, otp);

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.pop(context);
      _showFeedback('Login successful! Welcome back.', GreenM3Colors.primary);
    } else if (auth.error != null) {
      _showFeedback(auth.error!, GreenM3Colors.error);
    }
  }

  void _showFeedback(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == GreenM3Colors.primary ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Clergy Login',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: GreenM3Colors.primary,
        elevation: 0,
        centerTitle: false,
      ),
      body: Consumer<ClergyAuthProvider>(
        builder: (context, auth, _) {
          return AuthForm(
            email: _emailController.text,
            otp: _otpController.text,
            error: auth.error,
            isLoading: auth.isLoading || _isSubmitting,
            onSubmit: () => _handleLogin(auth),
            onEmailChange: (value) => _emailController.text = value,
            onOtpChange: (value) => _otpController.text = value,
          );
        },
      ),
    );
  }
}