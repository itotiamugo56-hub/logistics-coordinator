import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/haptic_service.dart';
import '../widgets/crystal_button.dart';
import '../widgets/physics_sheet.dart';
import '../main.dart';

// Material Design 3 Color Scheme - Consistent with app
class M3Colors {
  static const Color primary = Color(0xFF6750A4);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFEADDFF);
  static const Color secondary = Color(0xFF625B71);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color tertiary = Color(0xFF7D5260);
  static const Color surface = Color(0xFFFEF7FF);
  static const Color surfaceVariant = Color(0xFFE7E0EC);
  static const Color background = Color(0xFFFFFBFE);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color outline = Color(0xFF79747E);
  static const Color outlineVariant = Color(0xFFCAC4D0);
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFB300);
}

/// Help Category Model
class HelpCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final List<HelpArticle> articles;

  HelpCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.articles,
  });
}

/// Help Article Model
class HelpArticle {
  final String id;
  final String title;
  final String content;
  final List<String> steps;
  final String? emergencyPhone;
  final bool isEmergency;

  HelpArticle({
    required this.id,
    required this.title,
    required this.content,
    required this.steps,
    this.emergencyPhone,
    this.isEmergency = false,
  });
}

/// Emergency Contact Card - High visibility for critical info
class EmergencyContactCard extends StatelessWidget {
  final String phone;
  final VoidCallback onCall;

  const EmergencyContactCard({
    super.key,
    required this.phone,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            M3Colors.errorContainer,
            M3Colors.errorContainer.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: M3Colors.error.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: M3Colors.error.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: M3Colors.error.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.emergency,
                size: 24,
                color: M3Colors.error,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EMERGENCY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: M3Colors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '24/7 Helpline',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: M3Colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: M3Colors.error,
                    ),
                  ),
                ],
              ),
            ),
            CrystalButton(
              onPressed: onCall,
              label: 'CALL NOW',
              variant: CrystalButtonVariant.filled,
              icon: Icons.phone,
            ),
          ],
        ),
      ),
    );
  }
}

/// Expandable Article Card - Progressive disclosure
class ArticleCard extends StatefulWidget {
  final HelpArticle article;
  final VoidCallback? onEmergencyCall;

  const ArticleCard({
    super.key,
    required this.article,
    this.onEmergencyCall,
  });

  @override
  State<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<ArticleCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    HapticService.trigger(HapticIntensity.light, context: context);
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = Provider.of<MotionPreferences>(context).disableAnimations;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.article.isEmergency
            ? M3Colors.errorContainer
            : M3Colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: widget.article.isEmergency
            ? Border.all(color: M3Colors.error.withOpacity(0.3))
            : Border.all(color: M3Colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.article.isEmergency
                          ? M3Colors.error.withOpacity(0.15)
                          : M3Colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.article.isEmergency
                          ? Icons.warning_amber
                          : Icons.help_outline,
                      size: 20,
                      color: widget.article.isEmergency
                          ? M3Colors.error
                          : M3Colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.article.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: widget.article.isEmergency
                                ? M3Colors.error
                                : M3Colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.article.content,
                          style: TextStyle(
                            fontSize: 13,
                            color: M3Colors.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!reduceMotion)
                    AnimatedBuilder(
                      animation: _rotationAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationAnimation.value * 3.14159,
                          child: const Icon(
                            Icons.chevron_right,
                            color: M3Colors.outline,
                          ),
                        );
                      },
                    )
                  else
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: M3Colors.outline,
                    ),
                ],
              ),
            ),
          ),
          
          // Expanded content (conditionally visible)
          if (_isExpanded)
            AnimatedContainer(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Column(
                children: [
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Steps
                        if (widget.article.steps.isNotEmpty) ...[
                          const Text(
                            'Steps to follow:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: M3Colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...widget.article.steps.asMap().entries.map((entry) {
                            final index = entry.key + 1;
                            final step = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: M3Colors.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$index',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: M3Colors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      step,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: M3Colors.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                        
                        // Emergency call button if applicable
                        if (widget.article.emergencyPhone != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: CrystalButton(
                              onPressed: widget.onEmergencyCall,
                              label: 'CALL ${widget.article.emergencyPhone}',
                              variant: CrystalButtonVariant.filled,
                              icon: Icons.phone,
                              isExpanded: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Offline Status Banner
class OfflineStatusBanner extends StatelessWidget {
  final bool isOffline;
  final DateTime? lastSynced;

  const OfflineStatusBanner({
    super.key,
    required this.isOffline,
    this.lastSynced,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: M3Colors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: M3Colors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off,
            size: 16,
            color: M3Colors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Offline Mode',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: M3Colors.warning,
                  ),
                ),
                Text(
                  lastSynced != null
                      ? 'Last synced: ${_formatTime(lastSynced!)}'
                      : 'Content may be outdated',
                  style: const TextStyle(
                    fontSize: 11,
                    color: M3Colors.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Main Help & Resources Screen - Stripe/Apple Grade
class HelpResourcesScreen extends StatefulWidget {
  const HelpResourcesScreen({super.key});

  @override
  State<HelpResourcesScreen> createState() => _HelpResourcesScreenState();
}

class _HelpResourcesScreenState extends State<HelpResourcesScreen> {
  List<HelpCategory> _categories = [];
  bool _isLoading = true;
  bool _isOffline = false;
  DateTime? _lastSynced;
  
  // Emergency contact
  static const String _emergencyPhone = '+254 700 000 000';

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    
    // Try to load from cache first
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('help_resources_cache');
    
    if (cached != null) {
      _parseContent(jsonDecode(cached));
      setState(() => _isLoading = false);
    }
    
    // Try to fetch fresh content
    try {
      // In production, fetch from API
      // For now, use built-in content
      _loadBuiltInContent();
      _lastSynced = DateTime.now();
      
      // Cache for offline use
      await prefs.setString('help_resources_cache', jsonEncode(_serializeContent()));
      
      setState(() {
        _isOffline = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isOffline = true;
        _isLoading = false;
      });
    }
  }
  
  void _loadBuiltInContent() {
    _categories = [
      HelpCategory(
        id: 'emergency',
        title: 'Emergency Procedures',
        description: 'What to do in critical situations',
        icon: Icons.emergency,
        iconColor: M3Colors.error,
        articles: [
          HelpArticle(
            id: 'flare_howto',
            title: 'How to Send a Signal Flare',
            content: 'Send an emergency alert to nearby clergy',
            steps: [
              'Open the app and ensure GPS is enabled',
              'Tap the red SIGNAL FLARE button at the bottom of the screen',
              'Confirm your location is correct',
              'Wait for confirmation - clergy will be notified immediately',
              'Keep your phone nearby for updates',
            ],
            isEmergency: true,
          ),
          HelpArticle(
            id: 'no_signal',
            title: 'No Cell Service?',
            content: 'What to do when you have no signal',
            steps: [
              'Move to higher ground if possible',
              'Try to find Wi-Fi (nearby cafes, buildings)',
              'If completely offline, proceed to the nearest branch',
              'Ask someone nearby to call on your behalf',
              'Use the offline map (pre-downloaded) to find your way',
            ],
            emergencyPhone: _emergencyPhone,
            isEmergency: true,
          ),
        ],
      ),
      HelpCategory(
        id: 'safety',
        title: 'Safety Guidelines',
        description: 'Stay safe during your journey',
        icon: Icons.shield,
        iconColor: M3Colors.primary,
        articles: [
          HelpArticle(
            id: 'travel_safety',
            title: 'Safe Travel Tips',
            content: 'How to stay safe while traveling',
            steps: [
              'Always share your location with a trusted contact',
              'Use designated pickup points when possible',
              'Travel during daylight hours when feasible',
              'Keep emergency contacts saved on your phone',
              'Trust your instincts - if something feels wrong, seek help',
            ],
          ),
          HelpArticle(
            id: 'after_dark',
            title: 'Traveling After Dark',
            content: 'Extra precautions for nighttime travel',
            steps: [
              'Use well-lit routes and main roads',
              'Travel with a companion when possible',
              'Keep your phone charged and accessible',
              'Notify someone of your expected arrival time',
              'Have emergency cash for alternative transport',
            ],
          ),
        ],
      ),
      HelpCategory(
        id: 'transport',
        title: 'Transportation Guide',
        description: 'How to use pickup points and transport',
        icon: Icons.directions_bus,
        iconColor: M3Colors.secondary,
        articles: [
          HelpArticle(
            id: 'pickup_points',
            title: 'Using Pickup Points',
            content: 'How to find and use designated pickup locations',
            steps: [
              'Open the Transportation Hub from the bottom navigation',
              'Select your preferred pickup point based on distance',
              'Check the pickup time - arrive 5-10 minutes early',
              'Look for the transport manager or designated vehicle',
              'Have your confirmation ready if required',
            ],
          ),
          HelpArticle(
            id: 'transport_contacts',
            title: 'Contacting Transport Manager',
            content: 'How to reach your transport coordinator',
            steps: [
              'Find the CALL button on any pickup point card',
              'Tap to directly call the transport manager',
              'Identify yourself and your pickup location',
              'Confirm the pickup time and any changes',
              'Save the number for future trips if needed',
            ],
          ),
        ],
      ),
      HelpCategory(
        id: 'app',
        title: 'App Features',
        description: 'Learn about app functionality',
        icon: Icons.smartphone,
        iconColor: M3Colors.tertiary,
        articles: [
          HelpArticle(
            id: 'map_features',
            title: 'Using the Map',
            content: 'Navigate branches, find directions, and more',
            steps: [
              'Pinch to zoom in/out on the map',
              'Tap any branch marker to see details',
              'Use the search bar to find specific branches',
              'Tap DIRECTIONS to open Google Maps',
              'The nearest branch card shows your closest option',
            ],
          ),
          HelpArticle(
            id: 'flare_tracking',
            title: 'Tracking Your Flare',
            content: 'Monitor your emergency request status',
            steps: [
              'Go to the Safety tab to see your active flares',
              'The status shows: Waiting, Assigned, or Resolved',
              'When assigned, you\'ll see clergy ETA',
              'Refresh manually or wait for auto-update',
              'Cancel a flare if help is no longer needed',
            ],
          ),
        ],
      ),
      HelpCategory(
        id: 'faq',
        title: 'Frequently Asked Questions',
        description: 'Common questions and answers',
        icon: Icons.help_outline,
        iconColor: M3Colors.success,
        articles: [
          HelpArticle(
            id: 'faq_account',
            title: 'Account & Login',
            content: 'Questions about your account',
            steps: [
              'Q: How do I get an account?\nA: Contact your branch coordinator for registration.',
              'Q: I forgot my password?\nA: Use the "Forgot Password" link on the login screen.',
              'Q: Can I use the app without an account?\nA: No, you need a verified member account for security.',
            ],
          ),
          HelpArticle(
            id: 'faq_technical',
            title: 'Technical Issues',
            content: 'Troubleshooting common problems',
            steps: [
              'Q: App is slow or crashing?\nA: Try restarting the app or your phone.',
              'Q: Map not loading?\nA: Check your internet connection and try again.',
              'Q: Location not working?\nA: Ensure GPS is enabled in your phone settings.',
            ],
          ),
        ],
      ),
    ];
  }
  
  Map<String, dynamic> _serializeContent() {
    return {
      'categories': _categories.map((cat) => {
        'id': cat.id,
        'title': cat.title,
        'description': cat.description,
        'articles': cat.articles.map((art) => {
          'id': art.id,
          'title': art.title,
          'content': art.content,
          'steps': art.steps,
        }).toList(),
      }).toList(),
    };
  }
  
  void _parseContent(Map<String, dynamic> json) {
    // Parse cached content
    // Simplified for now
  }
  
  void _callEmergency() async {
    await HapticService.trigger(HapticIntensity.heavy, context: context);
    final Uri uri = Uri(scheme: 'tel', path: _emergencyPhone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
  
  Future<void> _refresh() async {
    await HapticService.trigger(HapticIntensity.light, context: context);
    await _loadContent();
  }

  @override
  Widget build(BuildContext context) {
    final motionPrefs = Provider.of<MotionPreferences>(context);
    final reduceMotion = motionPrefs.disableAnimations;
    
    return Scaffold(
      backgroundColor: M3Colors.background,
      appBar: AppBar(
        title: const Text('Help & Resources'),
        backgroundColor: M3Colors.surface,
        foregroundColor: M3Colors.onSurface,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: AnimatedRotation(
              duration: const Duration(milliseconds: 500),
              turns: _isLoading ? 1.0 : 0.0,
              child: const Icon(Icons.refresh),
            ),
            onPressed: _isLoading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading resources...',
                      style: TextStyle(color: M3Colors.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                slivers: [
                  // Offline banner
                  SliverToBoxAdapter(
                    child: OfflineStatusBanner(
                      isOffline: _isOffline,
                      lastSynced: _lastSynced,
                    ),
                  ),
                  
                  // Emergency contact card
                  SliverToBoxAdapter(
                    child: EmergencyContactCard(
                      phone: _emergencyPhone,
                      onCall: _callEmergency,
                    ),
                  ),
                  
                  // Help categories
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final category = _categories[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category header
                              Padding(
                                padding: const EdgeInsets.only(top: 16, bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: category.iconColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        category.icon,
                                        size: 20,
                                        color: category.iconColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: M3Colors.onSurface,
                                          ),
                                        ),
                                        Text(
                                          category.description,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: M3Colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Articles in this category
                              ...category.articles.map((article) => ArticleCard(
                                article: article,
                                onEmergencyCall: article.emergencyPhone != null
                                    ? _callEmergency
                                    : null,
                              )),
                            ],
                          );
                        },
                        childCount: _categories.length,
                      ),
                    ),
                  ),
                  
                  // Version info
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Version 1.0.0 • Last updated ${_lastSynced != null ? '${_lastSynced!.month}/${_lastSynced!.day}' : 'N/A'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: M3Colors.outline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}