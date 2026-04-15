import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/motion_tokens.dart';
import '../services/haptic_service.dart';
import '../widgets/crystal_button.dart';
import '../widgets/inline_feedback.dart';
import '../widgets/draggable_snap_sheet.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';
import '../widgets/pull_to_refresh.dart';
import '../widgets/swipe_to_dismiss.dart';
import '../widgets/toast_message.dart';
import '../widgets/enhanced_search_bar.dart';

class UiUxTestScreen extends StatefulWidget {
  const UiUxTestScreen({super.key});

  @override
  State<UiUxTestScreen> createState() => _UiUxTestScreenState();
}

class _UiUxTestScreenState extends State<UiUxTestScreen> {
  String? _feedbackMessage;
  FeedbackType? _feedbackType;
  bool _showSheet = false;
  int _counter = 0;
  List<String> _optimisticItems = [];
  final TextEditingController _textController = TextEditingController();
  
  // Priority 1 Components State
  bool _isLoadingBranches = true;
  List<String> _branches = [];
  List<String> _filteredBranches = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    HapticService.init();
    _simulateBranchLoad();
  }

  void _simulateBranchLoad() async {
    setState(() => _isLoadingBranches = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _branches = [
        'Ministry of Repentance - Nairobi CBD',
        'Ministry of Repentance - Westlands',
        'Ministry of Repentance - Kilimani',
        'Ministry of Repentance - Karen',
        'Ministry of Repentance - Eastlands',
        'Ministry of Repentance - Rongai',
        'Ministry of Repentance - Kiambu',
        'Ministry of Repentance - Thika',
      ];
      _filteredBranches = List.from(_branches);
      _isLoadingBranches = false;
    });
    ToastMessage.show(
      context: context,
      message: 'Branches loaded! Try searching or swiping',
      type: ToastType.success,
    );
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _branches.shuffle();
      _filteredBranches = List.from(_branches);
    });
    ToastMessage.show(
      context: context,
      message: 'Branches refreshed!',
      type: ToastType.success,
    );
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredBranches = List.from(_branches);
      } else {
        _filteredBranches = _branches
            .where((branch) => branch.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
    if (query.isNotEmpty && _filteredBranches.isEmpty) {
      ToastMessage.show(
        context: context,
        message: 'No branches found for "$query"',
        type: ToastType.warning,
      );
    }
  }

  void _onDeleteBranch(int index) {
    final deleted = _filteredBranches[index];
    setState(() {
      _filteredBranches.removeAt(index);
      _branches.remove(deleted);
    });
    ToastMessage.show(
      context: context,
      message: 'Branch deleted: $deleted',
      type: ToastType.success,
    );
  }

  void _showFeedback(String message, FeedbackType type, {bool autoDismiss = false}) {
    setState(() {
      _feedbackMessage = message;
      _feedbackType = type;
    });

    if (autoDismiss) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _feedbackMessage == message) {
          setState(() {
            _feedbackMessage = null;
            _feedbackType = null;
          });
        }
      });
    }
  }

  void _addOptimisticItem() {
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final newItem = "Item ${_optimisticItems.length + 1} (optimistic)";
    
    setState(() {
      _optimisticItems.insert(0, newItem);
    });
    
    _showFeedback("Adding item...", FeedbackType.info, autoDismiss: true);
    HapticService.trigger(HapticIntensity.medium, context: context);
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          final index = _optimisticItems.indexOf(newItem);
          if (index != -1) {
            _optimisticItems[index] = newItem.replaceAll("(optimistic)", "(confirmed)");
          }
        });
        _showFeedback("Item added successfully!", FeedbackType.success, autoDismiss: true);
        HapticService.trigger(HapticIntensity.light, context: context);
      }
    });
  }

  void _deleteOptimisticItem(int index) {
    final item = _optimisticItems[index];
    
    setState(() {
      _optimisticItems.removeAt(index);
    });
    
    _showFeedback("Deleting...", FeedbackType.info, autoDismiss: true);
    HapticService.trigger(HapticIntensity.heavy, context: context);
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        final bool failed = DateTime.now().millisecondsSinceEpoch % 5 == 0;
        
        if (failed) {
          setState(() {
            _optimisticItems.insert(index, item);
          });
          _showFeedback("Delete failed! Rolling back...", FeedbackType.error, autoDismiss: true);
          HapticService.trigger(HapticIntensity.error, context: context);
        } else {
          _showFeedback("Deleted successfully", FeedbackType.success, autoDismiss: true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    
    return Scaffold(
      backgroundColor: MotionTokens.background,
      appBar: AppBar(
        title: const Text('UI/UX Test Lab • Stripified'),
        backgroundColor: MotionTokens.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.motion_photos_on),
            onPressed: () {
              setState(() {});
              _showFeedback(
                reduceMotion ? "Motion reduced: ON" : "Motion reduced: OFF",
                FeedbackType.info,
                autoDismiss: true,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomPullToRefresh(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(MotionTokens.spacingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ============================================================
                  // STRIP 1: ENHANCED SEARCH BAR (Priority 1)
                  // ============================================================
                  Container(
                    padding: const EdgeInsets.all(MotionTokens.spacingMD),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [MotionTokens.primary.withOpacity(0.1), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(MotionTokens.spacingMD),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.search, color: MotionTokens.primary, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'STRIP 1 • ENHANCED SEARCH',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MotionTokens.spacingSM),
                        const Text(
                          'Real-time search with suggestions & debounce',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: MotionTokens.spacingMD),
                        EnhancedSearchBar(
                          onSearch: _onSearch,
                          suggestions: _branches,
                          hintText: 'Search branches...',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: MotionTokens.spacingXL),

                  // ============================================================
                  // STRIP 2: SKELETON LOADER (Priority 1)
                  // ============================================================
                  Container(
                    padding: const EdgeInsets.all(MotionTokens.spacingMD),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.withOpacity(0.1), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(MotionTokens.spacingMD),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.category, color: Colors.amber.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'STRIP 2 • SKELETON LOADER',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MotionTokens.spacingSM),
                        const Text(
                          'Loading states with shimmer effect',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: MotionTokens.spacingMD),
                        if (_isLoadingBranches)
                          Column(
                            children: const [
                              BranchCardSkeleton(),
                              BranchCardSkeleton(),
                              BranchCardSkeleton(),
                            ],
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(MotionTokens.spacingMD),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Loaded ${_branches.length} branches',
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _simulateBranchLoad,
                                  child: const Text('Reload'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: MotionTokens.spacingXL),

                  // ============================================================
                  // STRIP 3: EMPTY STATE (Priority 1)
                  // ============================================================
                  Container(
                    padding: const EdgeInsets.all(MotionTokens.spacingMD),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.withOpacity(0.1), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(MotionTokens.spacingMD),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inbox, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'STRIP 3 • EMPTY STATE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MotionTokens.spacingSM),
                        const Text(
                          'Elegant empty states with call-to-action',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: MotionTokens.spacingMD),
                        SizedBox(
                          height: 280,
                          child: _filteredBranches.isNotEmpty && !_isLoadingBranches
                              ? const Center(
                                  child: Text(
                                    '✨ Branches available! Clear search to see empty state demo',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : EmptyState(
                                  title: _searchQuery.isEmpty ? 'No Branches' : 'No Results Found',
                                  message: _searchQuery.isEmpty
                                      ? 'Pull down to refresh or add branches'
                                      : 'No branches match "$_searchQuery"',
                                  icon: _searchQuery.isEmpty ? Icons.store : Icons.search_off,
                                  buttonText: _searchQuery.isEmpty ? 'Refresh' : 'Clear Search',
                                  onButtonPressed: _searchQuery.isEmpty
                                      ? _onRefresh
                                      : () {
                                          _onSearch('');
                                          setState(() {});
                                        },
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: MotionTokens.spacingXL),

                  // ============================================================
                  // STRIP 4: SWIPE TO DISMISS (Priority 1)
                  // ============================================================
                  Container(
                    padding: const EdgeInsets.all(MotionTokens.spacingMD),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.withOpacity(0.1), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(MotionTokens.spacingMD),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.swipe, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'STRIP 4 • SWIPE TO DISMISS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MotionTokens.spacingSM),
                        const Text(
                          'Swipe left on any branch to delete (with confirmation)',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: MotionTokens.spacingMD),
                        if (_isLoadingBranches)
                          const Center(child: CircularProgressIndicator())
                        else if (_filteredBranches.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text('No branches to display. Add some!'),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredBranches.length,
                            itemBuilder: (context, index) {
                              final branch = _filteredBranches[index];
                              return SwipeToDismissWrapper(
                                onDismissed: () => _onDeleteBranch(index),
                                confirmTitle: 'Delete $branch?',
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: MotionTokens.spacingSM),
                                  padding: const EdgeInsets.all(MotionTokens.spacingMD),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
                                    boxShadow: MotionTokens.shadowSm,
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: MotionTokens.primary.withOpacity(0.1),
                                        radius: 20,
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(color: MotionTokens.primary),
                                        ),
                                      ),
                                      const SizedBox(width: MotionTokens.spacingMD),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              branch,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Swipe left to delete',
                                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.swipe, color: Colors.grey[400], size: 20),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: MotionTokens.spacingXL),

                  // ============================================================
                  // STRIP 5: TOAST MESSAGES (Priority 1)
                  // ============================================================
                  Container(
                    padding: const EdgeInsets.all(MotionTokens.spacingMD),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.withOpacity(0.1), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(MotionTokens.spacingMD),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.notifications, color: Colors.purple.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'STRIP 5 • TOAST MESSAGES',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MotionTokens.spacingSM),
                        const Text(
                          'Non-intrusive notifications with haptics',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: MotionTokens.spacingMD),
                        Wrap(
                          spacing: MotionTokens.spacingSM,
                          runSpacing: MotionTokens.spacingSM,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => ToastMessage.show(
                                context: context,
                                message: 'Operation completed successfully!',
                                type: ToastType.success,
                              ),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Success'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => ToastMessage.show(
                                context: context,
                                message: 'Something went wrong. Please try again.',
                                type: ToastType.error,
                              ),
                              icon: const Icon(Icons.error, size: 16),
                              label: const Text('Error'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => ToastMessage.show(
                                context: context,
                                message: 'Please check your internet connection.',
                                type: ToastType.warning,
                              ),
                              icon: const Icon(Icons.warning, size: 16),
                              label: const Text('Warning'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => ToastMessage.show(
                                context: context,
                                message: 'New update available!',
                                type: ToastType.info,
                              ),
                              icon: const Icon(Icons.info, size: 16),
                              label: const Text('Info'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: MotionTokens.spacingXL),

                  // ============================================================
                  // STRIP 6: PULL TO REFRESH (Priority 1 - Demonstrated above)
                  // ============================================================
                  Container(
                    padding: const EdgeInsets.all(MotionTokens.spacingMD),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.withOpacity(0.1), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(MotionTokens.spacingMD),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.refresh, color: Colors.teal.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'STRIP 6 • PULL TO REFRESH',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MotionTokens.spacingSM),
                        const Text(
                          'Pull down anywhere on the list to refresh',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: MotionTokens.spacingMD),
                        Container(
                          padding: const EdgeInsets.all(MotionTokens.spacingMD),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.swipe_down, color: Colors.teal),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Try pulling down from the top of this screen',
                                      style: TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Works anywhere in the scrollable area',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: MotionTokens.spacingXL),

                  // ============================================================
                  // STRIP 7: ORIGINAL UI/UX COMPONENTS
                  // ============================================================
                  _buildSectionTitle("Crystal Button Variants", Icons.smart_button),
                  const SizedBox(height: MotionTokens.spacingMD),
                  Wrap(
                    spacing: MotionTokens.spacingMD,
                    runSpacing: MotionTokens.spacingMD,
                    children: [
                      CrystalButton(
                        label: "Filled",
                        onPressed: () {
                          HapticService.trigger(HapticIntensity.medium, context: context);
                          _showFeedback("Filled button tapped", FeedbackType.success, autoDismiss: true);
                        },
                        variant: CrystalButtonVariant.filled,
                      ),
                      CrystalButton(
                        label: "Outlined",
                        onPressed: () {
                          HapticService.trigger(HapticIntensity.light, context: context);
                          _showFeedback("Outlined button tapped", FeedbackType.info, autoDismiss: true);
                        },
                        variant: CrystalButtonVariant.outlined,
                      ),
                      CrystalButton(
                        label: "Text/Destructive",
                        onPressed: () {
                          HapticService.trigger(HapticIntensity.heavy, context: context);
                          _showFeedback("Destructive action", FeedbackType.warning, autoDismiss: true);
                        },
                        variant: CrystalButtonVariant.text,
                      ),
                      CrystalButton(
                        label: "Loading",
                        onPressed: null,
                        isLoading: true,
                        variant: CrystalButtonVariant.filled,
                      ),
                    ],
                  ),

                  const SizedBox(height: MotionTokens.spacingXL),

                  _buildSectionTitle("Haptic Feedback Test", Icons.vibration),
                  const SizedBox(height: MotionTokens.spacingMD),
                  Wrap(
                    spacing: MotionTokens.spacingMD,
                    runSpacing: MotionTokens.spacingMD,
                    children: [
                      ElevatedButton(
                        onPressed: () => HapticService.trigger(HapticIntensity.light, context: context),
                        child: const Text("Light Haptic"),
                      ),
                      ElevatedButton(
                        onPressed: () => HapticService.trigger(HapticIntensity.medium, context: context),
                        child: const Text("Medium Haptic"),
                      ),
                      ElevatedButton(
                        onPressed: () => HapticService.trigger(HapticIntensity.heavy, context: context),
                        child: const Text("Heavy Haptic"),
                      ),
                      ElevatedButton(
                        onPressed: () => HapticService.trigger(HapticIntensity.error, context: context),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text("Error Haptic", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),

                  const SizedBox(height: MotionTokens.spacingXL),

                  _buildSectionTitle("Optimistic UI Demo", Icons.speed),
                  const SizedBox(height: MotionTokens.spacingMD),
                  CrystalButton(
                    label: "Add Optimistic Item",
                    onPressed: _addOptimisticItem,
                    icon: Icons.add,
                    isExpanded: true,
                  ),
                  const SizedBox(height: MotionTokens.spacingMD),
                  if (_optimisticItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(MotionTokens.spacingXL),
                      decoration: BoxDecoration(
                        color: MotionTokens.surface,
                        borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
                      ),
                      child: const Center(
                        child: Text("No items yet. Tap 'Add Optimistic Item'"),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _optimisticItems.length,
                      itemBuilder: (context, index) {
                        final item = _optimisticItems[index];
                        final isOptimistic = item.contains("optimistic");
                        return Container(
                          margin: const EdgeInsets.only(bottom: MotionTokens.spacingSM),
                          decoration: BoxDecoration(
                            color: isOptimistic ? Colors.yellow.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
                            border: Border.all(
                              color: isOptimistic ? Colors.yellow : Colors.green,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              isOptimistic ? Icons.hourglass_empty : Icons.check_circle,
                              color: isOptimistic ? Colors.orange : Colors.green,
                            ),
                            title: Text(item),
                            subtitle: Text(isOptimistic ? "Awaiting confirmation..." : "Saved to server"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: MotionTokens.error),
                              onPressed: () => _deleteOptimisticItem(index),
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: MotionTokens.spacingXL),

                  _buildSectionTitle("Spring Animation Demo", Icons.animation),
                  const SizedBox(height: MotionTokens.spacingMD),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _counter++);
                        HapticService.trigger(HapticIntensity.light, context: context);
                      },
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: reduceMotion ? 0 : MotionTokens.durationMedium),
                        curve: MotionTokens.easingStandard,
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: MotionTokens.primary,
                          shape: BoxShape.circle,
                          boxShadow: MotionTokens.shadowMd,
                        ),
                        child: Center(
                          child: Text(
                            '$_counter',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: MotionTokens.spacingSM),
                  Center(
                    child: Text(
                      "Tap the circle",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),

                  const SizedBox(height: MotionTokens.spacingXL),

                  _buildSectionTitle("Accessibility", Icons.accessibility_new),
                  const SizedBox(height: MotionTokens.spacingMD),
                  Container(
                    padding: const EdgeInsets.all(MotionTokens.spacingLG),
                    decoration: BoxDecoration(
                      color: reduceMotion ? Colors.orange.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
                      border: Border.all(
                        color: reduceMotion ? Colors.orange : Colors.green,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          reduceMotion ? Icons.motion_photos_off : Icons.motion_photos_on,
                          color: reduceMotion ? Colors.orange : Colors.green,
                          size: 32,
                        ),
                        const SizedBox(width: MotionTokens.spacingLG),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reduceMotion ? "Motion Reduction: ENABLED" : "Motion Reduction: DISABLED",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: reduceMotion ? Colors.orange : Colors.green,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reduceMotion 
                                  ? "All animations are disabled (0ms duration)"
                                  : "All animations use spring physics",
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Inline Feedback overlay
          if (_feedbackMessage != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: InlineFeedback(
                message: _feedbackMessage!,
                type: _feedbackType!,
                onDismiss: () => setState(() {
                  _feedbackMessage = null;
                  _feedbackType = null;
                }),
                autoDismissDuration: const Duration(seconds: 2),
              ),
            ),
          
          // Draggable Sheet button
          Positioned(
            bottom: MotionTokens.spacingLG,
            right: MotionTokens.spacingLG,
            child: FloatingActionButton(
              onPressed: () => setState(() => _showSheet = true),
              backgroundColor: MotionTokens.primary,
              child: const Icon(Icons.drag_handle),
            ),
          ),
          
          // Draggable Sheet
          if (_showSheet)
            DraggableSnapSheet(
              initialSnapPoint: MotionTokens.sheetSnapMid,
              onMinimize: () => setState(() => _showSheet = false),
              child: Padding(
                padding: const EdgeInsets.all(MotionTokens.spacingLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Draggable Sheet Demo",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: MotionTokens.spacingLG),
                    const Text(
                      "This sheet can be dragged and snapped to different heights:",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: MotionTokens.spacingMD),
                    Container(
                      padding: const EdgeInsets.all(MotionTokens.spacingMD),
                      decoration: BoxDecoration(
                        color: MotionTokens.surface,
                        borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
                      ),
                      child: Column(
                        children: [
                          _buildSnapInfo("Min: 30%", MotionTokens.sheetSnapMin),
                          _buildSnapInfo("Mid: 60%", MotionTokens.sheetSnapMid),
                          _buildSnapInfo("Max: 95%", MotionTokens.sheetSnapMax),
                        ],
                      ),
                    ),
                    const SizedBox(height: MotionTokens.spacingLG),
                    TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        labelText: "Type something...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: MotionTokens.spacingLG),
                    CrystalButton(
                      label: "Close Sheet",
                      onPressed: () => setState(() => _showSheet = false),
                      variant: CrystalButtonVariant.outlined,
                      isExpanded: true,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: MotionTokens.primary, size: 20),
        const SizedBox(width: MotionTokens.spacingSM),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSnapInfo(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.crop_rotate, size: 14, color: MotionTokens.primary),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            "${(value * 100).toInt()}%",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}