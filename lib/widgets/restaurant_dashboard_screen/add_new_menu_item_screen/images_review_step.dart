import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../config/menu_item_form_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/category.dart';
import '../../../models/cuisine_type.dart';
import 'form_field_helpers.dart';
import 'image_grid_item.dart';

/// Widget for the Images & Review step of the Add New Menu Item form
///
/// This step allows:
/// - Uploading food images (camera or gallery)
/// - Reviewing all entered information
/// - Final validation before submission
class ImagesReviewStep extends StatelessWidget {
  final Future<void> Function(ImageSource) onPickImage;
  final List<CuisineType> cuisineTypes;
  final List<Category> allCategories;
  final String? selectedCuisineTypeId;
  final String? selectedCategoryId;

  const ImagesReviewStep({
    required this.onPickImage,
    required this.cuisineTypes,
    required this.allCategories,
    required this.selectedCuisineTypeId,
    required this.selectedCategoryId,
    super.key,
  });

  static const _primaryColor = Color(0xFFd47b00);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(AppLocalizations.of(context)!.foodImages),
          const SizedBox(height: 16),
          _buildImageUploadSection(context),
          const SizedBox(height: 24),
          _buildSectionTitle(AppLocalizations.of(context)!.reviewYourMenuItem),
          const SizedBox(height: 16),
          _buildReviewCard(context),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    );
  }

  Widget _buildImageUploadSection(BuildContext context) {
    return Consumer<MenuItemFormController>(
      builder: (context, formController, child) {
        final hasAnyImages = formController.selectedImages.isNotEmpty ||
            formController.existingImageUrls.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppLocalizations.of(context)!.uploadFoodImages} *',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.addHighQualityPhotos,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            if (hasAnyImages) _buildImageGrid(formController),
            if (hasAnyImages) const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildUploadButton(
                    AppLocalizations.of(context)!.camera,
                    Icons.camera_alt,
                    () => onPickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildUploadButton(
                    AppLocalizations.of(context)!.gallery,
                    Icons.photo_library,
                    () => onPickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            if (formController.getImagesError() != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  formController.getImagesError()!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildImageGrid(MenuItemFormController formController) {
    final totalImages = formController.existingImageUrls.length +
        formController.selectedImages.length;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: totalImages,
      itemBuilder: (context, index) {
        // First show existing images (URLs), then new local images
        if (index < formController.existingImageUrls.length) {
          // Existing image from database (URL)
          final imageUrl = formController.existingImageUrls[index];
          return _buildExistingImageGridItem(imageUrl, formController);
        } else {
          // New local image (File)
          final localIndex = index - formController.existingImageUrls.length;
          final image = formController.selectedImages[localIndex];
          return ImageGridItem(
            image: image,
            onRemove: () => formController.removeImage(image),
          );
        }
      },
    );
  }

  Widget _buildExistingImageGridItem(
      String imageUrl, MenuItemFormController formController) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            // PERFORMANCE FIX: Add cacheWidth/cacheHeight for list items
            // Prevents decoding full-size images which causes scroll jank
            cacheWidth: 300, // 3-column grid, ~100dp per image * 3x for retina
            cacheHeight: 300,
            filterQuality: FilterQuality.low, // Faster decoding for thumbnails
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => formController.removeExistingImageUrl(imageUrl),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context) {
    return Consumer<MenuItemFormController>(
      builder: (context, formController, child) {
        final cuisine = FormFieldHelpers.getCuisineById(
          selectedCuisineTypeId,
          cuisineTypes,
        );
        final category = FormFieldHelpers.getCategoryById(
          selectedCategoryId,
          allCategories,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReviewItem(
              AppLocalizations.of(context)!.cuisineType,
              cuisine?.name ?? AppLocalizations.of(context)!.notSelected,
              Icons.restaurant,
            ),
            _buildDivider(),
            _buildReviewItem(
              AppLocalizations.of(context)!.category,
              category?.name ?? AppLocalizations.of(context)!.notSelected,
              Icons.category,
            ),
            _buildDivider(),
            _buildReviewItem(
              AppLocalizations.of(context)!.menuItemName,
              formController.dishName.isEmpty
                  ? AppLocalizations.of(context)!.notEntered
                  : formController.dishName,
              Icons.restaurant_menu,
            ),
            _buildDivider(),
            _buildReviewItem(
              AppLocalizations.of(context)!.variants,
              formController.variants.isEmpty
                  ? AppLocalizations.of(context)!.noneAdded
                  : '${formController.variants.length}',
              Icons.category_outlined,
            ),
            _buildDivider(),
            _buildReviewItem(
              AppLocalizations.of(context)!.pricingAndSizes,
              formController.pricingOptions.isEmpty
                  ? AppLocalizations.of(context)!.noneAdded
                  : '${formController.pricingOptions.length}',
              Icons.attach_money,
            ),
            _buildDivider(),
            _buildReviewItem(
              AppLocalizations.of(context)!.preparationTime,
              formController.preparationTime.isEmpty
                  ? AppLocalizations.of(context)!.notEntered
                  : '${formController.preparationTime} ${AppLocalizations.of(context)!.minutes}',
              Icons.timer,
            ),
            _buildDivider(),
            _buildReviewItem(
              AppLocalizations.of(context)!.ingredients,
              formController.ingredients.isEmpty
                  ? AppLocalizations.of(context)!.noneAdded
                  : '${formController.ingredients.length}',
              Icons.list,
            ),
            _buildDivider(),
            _buildReviewItem(
              AppLocalizations.of(context)!.supplements,
              formController.supplements.isEmpty
                  ? AppLocalizations.of(context)!.noneAdded
                  : '${formController.supplements.length}',
              Icons.add_circle_outline,
            ),
            _buildDivider(),
            _buildReviewItem(
              AppLocalizations.of(context)!.images,
              formController.selectedImages.isEmpty &&
                      formController.existingImageUrls.isEmpty
                  ? AppLocalizations.of(context)!.noneUploaded
                  : '${formController.selectedImages.length + formController.existingImageUrls.length}',
              Icons.photo_library,
            ),
          ],
        );
      },
    );
  }

  Widget _buildReviewItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
    );
  }
}
