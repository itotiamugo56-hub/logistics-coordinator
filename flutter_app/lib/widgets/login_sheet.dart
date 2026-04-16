import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/haptic_service.dart';
import '../widgets/crystal_button.dart';
import '../screens/register_screen.dart';

class LoginSheet extends StatefulWidget {
  final VoidCallback? onSuccess;
  
  const LoginSheet({super.key, this.onSuccess});

  /// Static method to show the login sheet
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const LoginSheet(),
    );
    return result ?? false;
  }

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  
  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }
  
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      HapticService.trigger(HapticIntensity.error, context: context);
      return;
    }
    
    if (otp.isEmpty) {
      setState(() => _error = 'Please enter the OTP');
      HapticService.trigger(HapticIntensity.error, context: context);
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(email, otp);
    
    setState(() {
      _isLoading = false;
      if (success) {
        HapticService.trigger(HapticIntensity.light, context: context);
        Navigator.pop(context, true);
        widget.onSuccess?.call();
      } else {
        _error = authProvider.error;
        HapticService.trigger(HapticIntensity.error, context: context);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          const Text(
            'Sign In Required',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in to send flares and access your history',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF49454F),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Email Field
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'you@example.com',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          
          // OTP Field
          TextField(
            controller: _otpController,
            decoration: InputDecoration(
              labelText: 'Verification Code',
              hintText: 'Enter 6-digit code',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          
          const SizedBox(height: 16),
          
          // Error message
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFBA1A1A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFBA1A1A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFBA1A1A), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Login Button
          CrystalButton(
            onPressed: _login,
            label: 'SIGN IN',
            variant: CrystalButtonVariant.filled,
            isLoading: _isLoading,
            isExpanded: true,
          ),
          
          const SizedBox(height: 16),
          
          // Register link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account? "),
              TextButton(
                onPressed: () {
                  HapticService.trigger(HapticIntensity.light, context: context);
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}