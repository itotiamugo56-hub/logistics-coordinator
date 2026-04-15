import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/motion_tokens.dart';
import '../services/haptic_service.dart';

class EnhancedSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final List<String> suggestions;
  final String hintText;
  final bool debounce;
  final Duration debounceDuration;

  const EnhancedSearchBar({
    super.key,
    required this.onSearch,
    this.suggestions = const [],
    this.hintText = 'Search...',
    this.debounce = true,
    this.debounceDuration = const Duration(milliseconds: 500),
  });

  @override
  State<EnhancedSearchBar> createState() => _EnhancedSearchBarState();
}

class _EnhancedSearchBarState extends State<EnhancedSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isLoading = false;
  bool _showSuggestions = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (widget.debounce) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(widget.debounceDuration, () {
        _performSearch(query);
      });
    } else {
      _performSearch(query);
    }
  }

  void _performSearch(String query) async {
    setState(() => _isLoading = true);
    await widget.onSearch(query);
    setState(() => _isLoading = false);
  }

  void _clearSearch() {
    _controller.clear();
    _performSearch('');
    _focusNode.unfocus();
    HapticService.trigger(HapticIntensity.light);
  }

  void _selectSuggestion(String suggestion) {
    _controller.text = suggestion;
    _performSearch(suggestion);
    setState(() => _showSuggestions = false);
    _focusNode.unfocus();
    HapticService.trigger(HapticIntensity.medium);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
            boxShadow: MotionTokens.shadowSm,
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onSearchChanged,
            onTap: () => setState(() => _showSuggestions = true),
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ),
        if (_showSuggestions && widget.suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: MotionTokens.spacingSM),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
              boxShadow: MotionTokens.shadowMd,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = widget.suggestions[index];
                return ListTile(
                  leading: const Icon(Icons.search, size: 16, color: Colors.grey),
                  title: Text(suggestion),
                  trailing: const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                  dense: true,
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}