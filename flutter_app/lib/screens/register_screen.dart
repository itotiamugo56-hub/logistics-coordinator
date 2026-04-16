import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/haptic_service.dart';
import '../widgets/crystal_button.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _error;
  String? _tempMemberId;  // Store member_id from registration response
  
  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    super.dispose();
  }
  
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      HapticService.trigger(HapticIntensity.error, context: context);
      return;
    }
    
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      HapticService.trigger(HapticIntensity.error, context: context);
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(email, name);
    
    setState(() {
      _isLoading = false;
      if (success) {
        _isOtpSent = true;
        _tempMemberId = authProvider.memberId;
        HapticService.trigger(HapticIntensity.light, context: context);
      } else {
        _error = authProvider.error;
        HapticService.trigger(HapticIntensity.error, context: context);
      }
    });
  }
  
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    
    if (otp.isEmpty) {
      setState(() => _error = 'Please enter the OTP');
      HapticService.trigger(HapticIntensity.error, context: context);
      return;
    }
    
    if (_tempMemberId == null) {
      setState(() => _error = 'Invalid session. Please try again.');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyRegistration(_tempMemberId!, otp);
    
    setState(() {
      _isLoading = false;
      if (success) {
        HapticService.trigger(HapticIntensity.light, context: context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        _error = authProvider.error;
        HapticService.trigger(HapticIntensity.error, context: context);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6750A4), Color(0xFF7D5260)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.church,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign up to send flares and track history',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF49454F),
                  ),
                ),
                const SizedBox(height: 48),
                
                // Name Field
                TextField(
                  controller: _nameController,
                  enabled: !_isOtpSent,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'John Doe',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Email Field
                TextField(
                  controller: _emailController,
                  enabled: !_isOtpSent,
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
                
                // OTP Field (visible after OTP sent)
                if (_isOtpSent)
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
                
                if (_isOtpSent) const SizedBox(height: 16),
                
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
                
                // Action Button
                CrystalButton(
                  onPressed: _isOtpSent ? _verifyOtp : _sendOtp,
                  label: _isOtpSent ? 'VERIFY & CREATE' : 'SEND OTP',
                  variant: CrystalButtonVariant.filled,
                  isLoading: _isLoading,
                  isExpanded: true,
                ),
                
                const SizedBox(height: 16),
                
                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    TextButton(
                      onPressed: () {
                        HapticService.trigger(HapticIntensity.light, context: context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text(
                        'Sign In',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}