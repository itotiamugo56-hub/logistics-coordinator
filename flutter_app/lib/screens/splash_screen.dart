import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import '../main.dart'; // For MotionPreferences

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoDrawAnimation;
  late AnimationController _taglineController;
  late Animation<double> _taglineFadeAnimation;
  late Animation<Color?> _gradientAnimation;
  
  String _statusMessage = 'Initializing secure connection...';
  bool _isServerAlive = true;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkServerAndAuth();
  }
  
  void _setupAnimations() {
    // Logo draw-in animation (stroke effect simulation)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _logoDrawAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutCubic,
    );
    
    // Tagline fade-up animation
    _taglineController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _taglineFadeAnimation = CurvedAnimation(
      parent: _taglineController,
      curve: Curves.easeOutCubic,
    );
    
    // Background gradient animation
    _gradientAnimation = ColorTween(
      begin: const Color(0xFF6750A4),
      end: const Color(0xFF7D5260),
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Start logo animation
    _logoController.forward();
  }
  
  Future<void> _checkServerAndAuth() async {
    final apiClient = ApiClient();
    final isServerAlive = await apiClient.checkHealth();
    
    setState(() {
      _isServerAlive = isServerAlive;
      _statusMessage = isServerAlive 
          ? 'Connection established. Authenticating...' 
          : 'Cannot connect to server. Check if backend is running.';
    });
    
    if (!isServerAlive) {
      await Future.delayed(const Duration(seconds: 2));
    }
    
    // Start tagline animation after logo
    await _taglineController.forward();
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    final token = await apiClient.getToken();
    
    if (mounted) {
      if (token != null && isServerAlive) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }
  
  @override
  void dispose() {
    _logoController.dispose();
    _taglineController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Get motion reduction preference
    final motionPrefs = Provider.of<MotionPreferences>(context);
    final reduceMotion = motionPrefs.disableAnimations;
    
    // If motion reduction is enabled, skip animations
    if (reduceMotion) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF6750A4), const Color(0xFF7D5260)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.church,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Ministry of Repentance',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                if (!_isServerAlive)
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Full animation version
    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradientAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _gradientAnimation.value ?? const Color(0xFF6750A4),
                  const Color(0xFF7D5260),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo
                  AnimatedBuilder(
                    animation: _logoDrawAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.8 + (0.2 * _logoDrawAnimation.value),
                        child: Opacity(
                          opacity: _logoDrawAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.church,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Animated Title
                  FadeTransition(
                    opacity: _logoDrawAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _logoController,
                        curve: Curves.easeOutCubic,
                      )),
                      child: const Text(
                        'Ministry of Repentance',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Animated Tagline
                  FadeTransition(
                    opacity: _taglineFadeAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(_taglineFadeAnimation),
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Loading indicator (only show if needed)
                  if (!_isServerAlive)
                    FadeTransition(
                      opacity: _taglineFadeAnimation,
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}