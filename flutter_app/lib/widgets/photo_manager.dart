import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../mixins/optimistic_operation.dart';
import '../services/haptic_service.dart';
import '../widgets/inline_feedback.dart';
import '../widgets/crystal_button.dart';
import '../widgets/physics_sheet.dart';

class PhotoManager extends StatefulWidget {
  final String branchId;
  final VoidCallback onRefresh;
  
  const PhotoManager({super.key, required this.branchId, required this.onRefresh});

  @override
  State<PhotoManager> createState() => _PhotoManagerState();
}

class _PhotoManagerState extends State<PhotoManager> with OptimisticOperation<Map<String, dynamic>> {
  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = true;
  bool _isUploading = false;
  OverlayEntry? _feedbackOverlay;
  
  final Uuid _uuid = const Uuid();
  
  @override
  List<Map<String, dynamic>> get items => _photos;
  
  @override
  void notifyListeners() {
    if (mounted) {
      setState(() {});
    }
  }
  
  @override
  String _getId(Map<String, dynamic> item) {
    return item['id'].toString();
  }
  
  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }
  
  @override
  void dispose() {
    _removeFeedbackOverlay();
    super.dispose();
  }
  
  void _showFeedback(String message, FeedbackType type, {VoidCallback? onRetry}) {
    _removeFeedbackOverlay();
    
    final overlay = Overlay.of(context);
    _feedbackOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 0,
        right: 0,
        child: InlineFeedback(
          message: message,
          type: type,
          onRetry: onRetry,
          autoDismissDuration: const Duration(seconds: 3),
          onDismiss: () => _removeFeedbackOverlay(),
        ),
      ),
    );
    
    overlay.insert(_feedbackOverlay!);
  }
  
  void _removeFeedbackOverlay() {
    _feedbackOverlay?.remove();
    _feedbackOverlay = null;
  }
  
  Future<void> _loadPhotos() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8080/v1/clergy/photos/${widget.branchId}'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _photos = data.map((url) => {
            'id': _uuid.v4(),
            'url': url.toString(),
          }).toList();
          _isLoading = false;
        });
        await HapticService.trigger(HapticIntensity.light, context: context);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading photos: $e');
    }
  }
  
  Future<void> _uploadPhoto() async {
    // Medium haptic for starting upload
    await HapticService.trigger(HapticIntensity.medium, context: context);
    
    // Create a file input element
    final input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.click();
    
    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) return;
      
      final file = files[0];
      final reader = html.FileReader();
      
      setState(() => _isUploading = true);
      
      reader.onLoadEnd.listen((event) async {
        final dataUrl = reader.result as String;
        
        final tempId = _uuid.v4();
        final tempPhoto = {
          'id': tempId,
          'url': dataUrl,
          '_optimistic': true,
        };
        
        addOptimistic(
          tempId,
          tempPhoto,
          () => _performUpload(dataUrl),
          onSuccess: (item) {
            setState(() => _isUploading = false);
            widget.onRefresh();
            _loadPhotos();
            HapticService.trigger(HapticIntensity.light, context: context);
            _showFeedback('Photo added successfully', FeedbackType.success);
          },
          onError: (error) {
            setState(() => _isUploading = false);
            HapticService.trigger(HapticIntensity.error, context: context);
            _showFeedback('Failed to add photo. Tap RETRY to try again.', FeedbackType.error, onRetry: () => _uploadPhoto());
          },
        );
      });
      
      reader.readAsDataUrl(file);
    });
  }
  
  Future<void> _performUpload(String dataUrl) async {
    // Simulate upload delay for realistic feedback
    await Future.delayed(const Duration(milliseconds: 500));
    
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8080/v1/clergy/photos/${widget.branchId}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': dataUrl}),
    );
    
    if (response.statusCode != 201) {
      throw Exception('Failed to upload photo');
    }
  }
  
  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    // Heavy haptic for destructive action
    await HapticService.trigger(HapticIntensity.heavy, context: context);
    
    // Double haptic for delete confirmation
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticService.trigger(HapticIntensity.heavy, context: context);
    
    deleteOptimistic(
      photo['id'].toString(),
      photo,
      () => _performDelete(photo['url'].toString()),
      onSuccess: () {
        widget.onRefresh();
        _loadPhotos();
        HapticService.trigger(HapticIntensity.light, context: context);
        _showFeedback('Photo deleted', FeedbackType.info);
      },
      onError: (error) {
        HapticService.trigger(HapticIntensity.error, context: context);
        _showFeedback('Failed to delete photo', FeedbackType.error);
      },
    );
  }
  
  Future<void> _performDelete(String url) async {
    final encodedUrl = Uri.encodeComponent(url);
    final response = await http.delete(
      Uri.parse('http://127.0.0.1:8080/v1/clergy/photos/${widget.branchId}/$encodedUrl'),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete photo');
    }
  }
  
  bool _isOptimisticPhoto(Map<String, dynamic> photo) {
    return photo['_optimistic'] == true;
  }
  
  @override
  Widget build(BuildContext context) {
    // Build the grid content
    final gridContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _photos.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No photos yet', style: TextStyle(color: Colors.grey)),
                    Text('Tap + to add photos', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              )
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                padding: const EdgeInsets.all(16),
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  final url = photo['url'].toString();
                  final isOptimistic = _isOptimisticPhoto(photo);
                  
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isOptimistic
                          ? [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: url.startsWith('data:image')
                              ? Image.memory(
                                  base64Decode(url.split(',')[1]),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                    );
                                  },
                                )
                              : Image.network(
                                  url,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                    );
                                  },
                                ),
                        ),
                        if (isOptimistic)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.green.withOpacity(0.3),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.white),
                              onPressed: () => _deletePhoto(photo),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
    
    final content = Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Manage Branch Photos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CrystalButton(
            onPressed: _isUploading ? null : _uploadPhoto,
            label: _isUploading ? 'UPLOADING...' : 'ADD PHOTO',
            variant: CrystalButtonVariant.filled,
            isLoading: _isUploading,
            icon: Icons.add_photo_alternate,
            isExpanded: true,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: gridContent),
      ],
    );
    
    return PhysicsSheet(
      child: content,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      initialChildSize: 0.7,
      onExpanded: () {
        HapticService.trigger(HapticIntensity.light, context: context);
      },
      onCollapsed: () {
        HapticService.trigger(HapticIntensity.light, context: context);
      },
      isCritical: false,
    );
  }
}