import 'package:flutter/material.dart';
import 'dart:async';

/// Success confirmation animation with checkmark scale + bounce
/// Apple/Stripe grade completion feedback
class SuccessAnimation extends StatefulWidget {
  final VoidCallback? onComplete;
  final String? message;
  final Duration duration;

  const SuccessAnimation({
    super.key,
    this.onComplete,
    this.message,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();

  /// Show success animation overlay
  static Future<void> show(
    BuildContext context, {
    String? message,
    VoidCallback? onComplete,
  }) async {
    OverlayEntry? overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => SuccessAnimation(
        message: message,
        onComplete: () {
          overlayEntry?.remove();
          onComplete?.call();
        },
      ),
    );
    
    final overlay = Overlay.of(context);
    overlay.insert(overlayEntry);
  }
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAutoDismiss();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Checkmark scale animation (elastic bounce)
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    // Fade in/out animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // Message slide up animation
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  void _startAutoDismiss() {
    _autoDismissTimer = Timer(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onComplete?.call();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: reduceMotion ? 1.0 : _fadeAnimation.value,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated checkmark circle
                    Transform.scale(
                      scale: reduceMotion ? 1.0 : _scaleAnimation.value,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF00C853),
                              Color(0xFF00BFA5),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00C853).withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Animated message
                    if (widget.message != null)
                      Transform.translate(
                        offset: reduceMotion ? Offset.zero : _slideAnimation.value,
                        child: Text(
                          widget.message!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1B1F),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Confetti-like particle burst animation for extra delight
class ParticleBurst extends StatefulWidget {
  final VoidCallback? onComplete;

  const ParticleBurst({
    super.key,
    this.onComplete,
  });

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();

  /// Show particle burst overlay
  static Future<void> show(BuildContext context, {VoidCallback? onComplete}) async {
    OverlayEntry? overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => ParticleBurst(
        onComplete: () {
          overlayEntry?.remove();
          onComplete?.call();
        },
      ),
    );
    
    final overlay = Overlay.of(context);
    overlay.insert(overlayEntry);
  }
}

class _ParticleBurstState extends State<ParticleBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _generateParticles();
    _controller.forward();
    _autoDismissTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        widget.onComplete?.call();
      }
    });
  }

  void _generateParticles() {
    _particles = List.generate(20, (index) {
      return Particle(
        dx: (index % 5 - 2) * 20.0 + (index * 3) % 40 - 20,
        dy: -50 - (index * 5) % 80,
        size: 6 + (index % 8),
        color: [
          const Color(0xFF6750A4),
          const Color(0xFF00C853),
          const Color(0xFFFFB300),
          const Color(0xFF7D5260),
        ][index % 4],
        delay: index * 0.03,
      );
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: ParticlePainter(
              particles: _particles,
              animationValue: _controller.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class Particle {
  final double dx;
  final double dy;
  final double size;
  final Color color;
  final double delay;

  Particle({
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
    required this.delay,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;

  ParticlePainter({
    required this.particles,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      final progress = (animationValue - particle.delay).clamp(0.0, 1.0);
      if (progress <= 0) continue;

      final easeOut = 1 - (1 - progress) * (1 - progress);
      final currentX = particle.dx * easeOut;
      final currentY = particle.dy * easeOut;
      final currentSize = particle.size * (1 - easeOut * 0.7);
      final opacity = (1 - easeOut).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(center.dx + currentX, center.dy + currentY),
        currentSize,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}