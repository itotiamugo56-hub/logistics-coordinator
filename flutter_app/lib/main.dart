import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/map_screen.dart';
import 'screens/ui_ux_test_screen.dart';
import 'screens/dashboard_screen.dart';
import 'providers/clergy_auth_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/flare_provider.dart';
import 'services/haptic_service.dart';
import 'services/api_client.dart';
import 'constants/motion_tokens.dart';

// Motion Preferences Provider to track system accessibility settings
class MotionPreferences extends ChangeNotifier {
  bool _disableAnimations = false;
  
  bool get disableAnimations => _disableAnimations;
  
  void updateFromMediaQuery(MediaQueryData mediaQuery) {
    final newValue = mediaQuery.disableAnimations;
    if (_disableAnimations != newValue) {
      _disableAnimations = newValue;
      notifyListeners();
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize haptic service before app starts
  await HapticService.init();

  runApp(const MinistryOfRepentanceApp());
}

class MinistryOfRepentanceApp extends StatefulWidget {
  const MinistryOfRepentanceApp({super.key});

  @override
  State<MinistryOfRepentanceApp> createState() => _MinistryOfRepentanceAppState();
}

class _MinistryOfRepentanceAppState extends State<MinistryOfRepentanceApp> {
  late MotionPreferences _motionPreferences;
  
  @override
  void initState() {
    super.initState();
    _motionPreferences = MotionPreferences();
  }
  
  @override
  void dispose() {
    _motionPreferences.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClergyAuthProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FlareProvider()),
        ChangeNotifierProvider.value(value: _motionPreferences),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Listen to MediaQuery changes for accessibility settings
          return MediaQuery(
            data: MediaQuery.of(context),
            child: Builder(
              builder: (context) {
                // Update motion preferences when MediaQuery changes
                final mediaQuery = MediaQuery.of(context);
                _motionPreferences.updateFromMediaQuery(mediaQuery);
                
                return MaterialApp(
                  title: 'Ministry of Repentance',
                  debugShowCheckedModeBanner: false,
                  theme: _buildTheme(context),
                  initialRoute: '/',
                  routes: {
                    '/': (context) => const DashboardScreen(),
                    '/map': (context) => const MapScreen(),
                    '/ui-test': (context) => const UiUxTestScreen(),
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Builds the global application theme with motion reduction awareness
  ThemeData _buildTheme(BuildContext context) {
    const primaryColor = MotionTokens.primary;
    const successColor = MotionTokens.success;
    const errorColor = MotionTokens.error;
    const backgroundColor = MotionTokens.background;
    
    final disableAnimations = _motionPreferences.disableAnimations;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: successColor,
      error: errorColor,
      background: backgroundColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackgroundColor: backgroundColor,
      
      // Disable or reduce animations based on user preference
      splashFactory: disableAnimations ? NoSplash.splashFactory : InkRipple.splashFactory,
      
      // Page transitions with motion reduction
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: disableAnimations 
              ? const NoAnimationPageTransitionsBuilder()
              : const FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: disableAnimations
              ? const NoAnimationPageTransitionsBuilder()
              : const CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: disableAnimations
              ? const NoAnimationPageTransitionsBuilder()
              : const FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: disableAnimations
              ? const NoAnimationPageTransitionsBuilder()
              : const FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: disableAnimations
              ? const NoAnimationPageTransitionsBuilder()
              : const FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: primaryColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      ),

      // Card Theme (Material 3)
      cardTheme: CardThemeData(
        elevation: disableAnimations ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
        ),
        margin: const EdgeInsets.all(MotionTokens.spacingSM),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(
            color: primaryColor,
            width: 2,
          ),
        ),
      ),

      // Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: MotionTokens.spacingSM,
            horizontal: MotionTokens.spacingMD,
          ),
          // Disable animation on button press if motion reduction is enabled
          animationDuration: disableAnimations ? Duration.zero : const Duration(milliseconds: 100),
        ),
      ),

      // Typography (Optional but Recommended)
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: const TextStyle(fontWeight: FontWeight.bold),
        displayMedium: const TextStyle(fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(fontWeight: FontWeight.w400),
        bodyMedium: const TextStyle(fontWeight: FontWeight.w400),
        labelLarge: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Custom page transition builder that disables animations
class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();
  
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // No animation - just show the child immediately
    return child;
  }
}