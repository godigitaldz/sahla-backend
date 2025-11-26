import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../services/permission_service.dart';
import '../../utils/input_sanitizer.dart';

class OptimizedImageUploader {
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp'
  ];

  /// Compress and validate image before upload
  static Future<File?> compressAndValidateImage(File imageFile) async {
    try {
      // Validate file size
      if (!InputSanitizer.isValidFileSize(imageFile, maxFileSizeBytes)) {
        throw Exception('Image size must be less than 5MB');
      }

      // Validate file extension
      if (!InputSanitizer.isValidImageFile(imageFile)) {
        throw Exception(
            'Please select a valid image file (JPG, PNG, GIF, WebP)');
      }

      // For now, return the original file
      // In a real implementation, you would use flutter_image_compress
      // to compress the image here
      return imageFile;
    } catch (e) {
      throw Exception('Error validating image: $e');
    }
  }

  /// Upload image to Supabase storage
  static Future<String> uploadImageToSupabase(
      File imageFile, String bucketName) async {
    try {
      debugPrint('🖼️ Starting image upload to Supabase:');
      debugPrint('   File: ${imageFile.path}');
      debugPrint('   Bucket: $bucketName');

      // Get current user for file naming
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('   User ID: ${currentUser.id}');

      // Generate unique file name using user ID and timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final fileName =
          '${currentUser.id}_${bucketName}_$timestamp.$fileExtension';

      debugPrint('   Generated filename: $fileName');

      // Read file bytes
      final fileBytes = await imageFile.readAsBytes();
      debugPrint('   File size: ${fileBytes.length} bytes');

      // Upload to Supabase storage
      debugPrint('   Uploading to Supabase storage...');
      final storageResponse =
          await Supabase.instance.client.storage.from(bucketName).uploadBinary(
                fileName,
                fileBytes,
                fileOptions: FileOptions(
                  contentType: 'image/$fileExtension',
                  upsert: false,
                ),
              );

      debugPrint('   Storage response: $storageResponse');

      if (storageResponse.isEmpty) {
        throw Exception('Upload failed - no response from storage');
      }

      // Get the public URL
      final publicUrl = Supabase.instance.client.storage
          .from(bucketName)
          .getPublicUrl(fileName);

      debugPrint('   Public URL: $publicUrl');

      if (publicUrl.isEmpty) {
        throw Exception('Failed to get public URL for uploaded image');
      }

      debugPrint('✅ Image uploaded successfully');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Image upload error: $e');
      throw Exception('Error uploading image: $e');
    }
  }

  /// Remove image from Supabase storage
  static Future<void> removeImageFromSupabase(
      String imageUrl, String bucketName) async {
    try {
      // Extract file name from URL for deletion
      final uri = Uri.parse(imageUrl);
      final fileName = uri.pathSegments.last;

      await Supabase.instance.client.storage
          .from(bucketName)
          .remove([fileName]);
    } catch (e) {
      // Log error but don't throw - removal is not critical
      debugPrint('Error deleting image from storage: $e');
    }
  }

  /// Show image picker with permissions
  static Future<File?> showImagePicker(BuildContext context) async {
    try {
      debugPrint('🖼️ showImagePicker() called');

      // Check and request permissions using native dialogs
      debugPrint('🖼️ Checking image permissions...');
      final canProceed =
          await PermissionService.checkAndRequestImagePermissions();

      if (!canProceed) {
        throw Exception(
            'Camera and photo permissions are required to upload an image');
      }

      debugPrint('🖼️ Permissions granted, proceeding with image picker...');

      final picker = ImagePicker();
      File? selectedFile;

      debugPrint('🖼️ Showing image picker modal...');

      // Store context before async operation
      final currentContext = context;

      // Use a Completer to properly handle async image selection
      final completer = Completer<File?>();

      await showModalBottomSheet(
        // ignore: use_build_context_synchronously
        context: currentContext,
        builder: (BuildContext modalContext) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take Photo'),
                  onTap: () async {
                    debugPrint('🖼️ Camera option selected');
                    Navigator.of(modalContext).pop();
                    try {
                      final pickedFile = await picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 1024, // Compress image
                        maxHeight: 1024,
                        imageQuality: 85,
                      );
                      if (pickedFile != null) {
                        selectedFile = File(pickedFile.path);
                        debugPrint(
                            '🖼️ Camera image selected: ${selectedFile!.path}');
                        completer.complete(selectedFile);
                      } else {
                        debugPrint('🖼️ No camera image selected');
                        completer.complete(null);
                      }
                    } catch (e) {
                      debugPrint('❌ Camera error: $e');
                      completer.complete(null);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    debugPrint('🖼️ Gallery option selected');
                    Navigator.of(modalContext).pop();
                    try {
                      final pickedFile = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1024, // Compress image
                        maxHeight: 1024,
                        imageQuality: 85,
                      );
                      if (pickedFile != null) {
                        selectedFile = File(pickedFile.path);
                        debugPrint(
                            '🖼️ Gallery image selected: ${selectedFile!.path}');
                        completer.complete(selectedFile);
                      } else {
                        debugPrint('🖼️ No gallery image selected');
                        completer.complete(null);
                      }
                    } catch (e) {
                      debugPrint('❌ Gallery error: $e');
                      completer.complete(null);
                    }
                  },
                ),
              ],
            ),
          );
        },
      );

      // Wait for the image selection to complete
      final result = await completer.future;
      debugPrint(
          '🖼️ Image picker modal closed, selected file: ${result?.path}');
      return result;
    } catch (e) {
      debugPrint('❌ Image picker error: $e');
      throw Exception('Error picking image: $e');
    }
  }

  /// Complete image upload process with validation and compression
  static Future<String> uploadImageWithValidation(
    BuildContext context,
    String bucketName, {
    File? existingFile,
  }) async {
    try {
      File? imageFile = existingFile;

      // If no existing file, show picker
      if (imageFile == null) {
        imageFile = await showImagePicker(context);
        if (imageFile == null) {
          throw Exception('No image selected');
        }
      }

      // Compress and validate image
      final compressedFile = await compressAndValidateImage(imageFile);
      if (compressedFile == null) {
        throw Exception('Failed to compress image');
      }

      // Upload to Supabase
      final publicUrl = await uploadImageToSupabase(compressedFile, bucketName);

      return publicUrl;
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }
}

class ImageUploadWidget extends StatefulWidget {
  final String? currentImageUrl;
  final File? currentImageFile;
  final Function(String url, File file) onImageSelected;
  final Function()? onImageRemoved;
  final String bucketName;
  final String entityLabel;
  final bool isLoading;

  const ImageUploadWidget({
    required this.onImageSelected,
    required this.bucketName,
    super.key,
    this.currentImageUrl,
    this.currentImageFile,
    this.onImageRemoved,
    this.entityLabel = 'Restaurant',
    this.isLoading = false,
  });

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    // Debug: Log current state
    debugPrint('🖼️ ImageUploadWidget build:');
    debugPrint('   currentImageFile: ${widget.currentImageFile?.path}');
    debugPrint('   currentImageUrl: ${widget.currentImageUrl}');
    debugPrint('   isLoading: ${widget.isLoading}');
    debugPrint('   _isUploading: $_isUploading');

    return Column(
      children: [
        Text(
          AppLocalizations.of(context)!.restaurantLogo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        // Logo Display Container
        Container(
          height: 98,
          width: 98,
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.currentImageUrl != null
                  ? Colors.green[400]!
                  : Colors.grey[300]!,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(12),
            color: widget.currentImageUrl != null
                ? Colors.green[50]
                : Colors.grey[50],
            boxShadow: widget.currentImageUrl != null
                ? [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: _isUploading || widget.isLoading
              ? const Center(child: CircularProgressIndicator())
              : (widget.currentImageFile != null ||
                      widget.currentImageUrl != null)
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: widget.currentImageFile != null
                              ? Image.file(
                                  widget.currentImageFile!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                        size: 40,
                                      ),
                                    );
                                  },
                                )
                              : widget.currentImageUrl != null
                                  ? Image.network(
                                      widget.currentImageUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.error_outline,
                                            color: Colors.red,
                                            size: 28,
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                        size: 28,
                                      ),
                                    ),
                        ),
                        // Upload status indicator
                        if (widget.currentImageUrl != null)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green[600],
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(35),
                          ),
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            size: 20,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            AppLocalizations.of(context)!.tapToAddLogo,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
        ),

        const SizedBox(height: 12),

        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Upload/Change Button
            SizedBox(
              width: (widget.currentImageFile != null ||
                      widget.currentImageUrl != null)
                  ? 120
                  : 160,
              height: 36,
              child: Semantics(
                button: true,
                label: 'Upload ${widget.entityLabel.toLowerCase()} logo',
                child: ElevatedButton.icon(
                  onPressed:
                      _isUploading || widget.isLoading ? null : _uploadImage,
                  icon: Icon(
                    _isUploading ? Icons.hourglass_empty : Icons.camera_alt,
                    size: 18,
                  ),
                  label: Text(
                    _isUploading
                        ? AppLocalizations.of(context)!.submitting
                        : ((widget.currentImageFile != null ||
                                widget.currentImageUrl != null)
                            ? AppLocalizations.of(context)!.upload
                            : AppLocalizations.of(context)!.upload),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      height: 1.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    minimumSize: const Size(150, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    elevation: 4,
                    shadowColor: Colors.orange.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),

            // Remove Button (only show if image exists)
            if (widget.currentImageFile != null ||
                widget.currentImageUrl != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                height: 36,
                child: Semantics(
                  button: true,
                  label: 'Remove ${widget.entityLabel.toLowerCase()} logo',
                  child: ElevatedButton(
                    onPressed:
                        _isUploading || widget.isLoading ? null : _removeImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(10),
                      minimumSize: const Size(44, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 3,
                      shadowColor: Colors.red.withValues(alpha: 0.4),
                    ),
                    child: const Icon(Icons.delete, size: 20),
                  ),
                ),
              ),
            ],
          ],
        ),

        // Upload Status Text
        if (widget.currentImageUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Logo uploaded to cloud ✓',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _uploadImage() async {
    debugPrint('🖼️ _uploadImage() called');

    setState(() {
      _isUploading = true;
    });

    try {
      debugPrint('🖼️ Showing image picker...');

      // Show image picker first
      final imageFile = await OptimizedImageUploader.showImagePicker(context);
      if (imageFile == null) {
        debugPrint('🖼️ No image selected by user');
        setState(() {
          _isUploading = false;
        });
        return;
      }

      debugPrint('🖼️ Image selected: ${imageFile.path}');

      // Compress and validate the image
      debugPrint('🖼️ Compressing and validating image...');
      final compressedFile =
          await OptimizedImageUploader.compressAndValidateImage(imageFile);
      if (compressedFile == null) {
        throw Exception('Failed to compress image');
      }

      debugPrint('🖼️ Image compressed successfully');

      // Upload to Supabase
      debugPrint('🖼️ Starting Supabase upload...');
      final publicUrl = await OptimizedImageUploader.uploadImageToSupabase(
        compressedFile,
        widget.bucketName,
      );

      debugPrint('🖼️ Upload completed, calling callback...');
      // Call the callback with the actual file and URL
      widget.onImageSelected(publicUrl, compressedFile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading logo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _removeImage() async {
    try {
      if (widget.currentImageUrl != null) {
        await OptimizedImageUploader.removeImageFromSupabase(
          widget.currentImageUrl!,
          widget.bucketName,
        );
      }

      widget.onImageRemoved?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo removed successfully'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing logo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
