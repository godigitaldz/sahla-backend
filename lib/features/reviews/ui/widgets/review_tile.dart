import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../config/image_cache_manager.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/review.dart';

/// Optimized review tile with image downscaling and repaint boundaries.
class ReviewTile extends StatelessWidget {
  const ReviewTile({
    required this.review,
    super.key,
  });

  final Review review;

  @override
  Widget build(BuildContext context) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserHeader(context, isRTL),
            const SizedBox(height: 8),
            if (review.comment?.isNotEmpty ?? false) _buildComment(),
            if (review.photos?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              _buildImages(isRTL),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, bool isRTL) {
    final l10n = AppLocalizations.of(context);

    return Row(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      children: [
        // User avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFfc9d2d).withOpacity(0.2),
          backgroundImage: review.userAvatar?.isNotEmpty ?? false
              ? CachedNetworkImageProvider(
                  review.userAvatar!,
                  cacheManager: ReviewImageCacheManager.instance,
                )
              : null,
          child: review.userAvatar?.isEmpty ?? true
              ? Text(
                  review.userName?.isNotEmpty ?? false
                      ? review.userName![0].toUpperCase()
                      : 'A',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFfc9d2d),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        // User info
        Expanded(
          child: Column(
            crossAxisAlignment:
                isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Flexible(
                    child: Directionality(
                      textDirection:
                          isRTL ? TextDirection.rtl : TextDirection.ltr,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              review.userName ??
                                  (l10n?.anonymousUser ?? 'Anonymous User'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (review.menuItemName != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${review.menuItemName})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (review.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      size: 16,
                      color: Colors.green,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  ...List.generate(5, (index) {
                    return Icon(
                      index < review.rating ? Icons.star : Icons.star_border,
                      size: 12,
                      color: index < review.rating
                          ? Colors.amber
                          : Colors.grey[400],
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    _getTimeAgo(context, review.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComment() {
    return Text(
      review.comment!,
      textAlign: TextAlign.start,
      style: const TextStyle(
        fontSize: 13,
        color: Colors.grey,
        height: 1.4,
      ),
    );
  }

  Widget _buildImages(bool isRTL) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate optimal image width for exactly 3.2 images visible
        final imageWidth = (constraints.maxWidth / 3.2) - 8;

        return SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            reverse: isRTL,
            itemCount: review.photos!.length,
            itemBuilder: (context, index) {
              return _buildImageTile(
                review.photos![index],
                imageWidth,
                isRTL,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildImageTile(String imageUrl, double width, bool isRTL) {
    return Container(
      width: width,
      margin: EdgeInsets.only(
        right: isRTL ? 0 : 8,
        left: isRTL ? 8 : 0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          cacheManager: ReviewImageCacheManager.instance,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error, size: 20),
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(BuildContext context, DateTime dateTime) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      final plural = isArabic
          ? (months == 1 ? 'شهر' : 'أشهر')
          : (months == 1 ? 'month' : 'months');
      return l10n?.monthsAgo(months, plural) ?? '$months $plural ago';
    } else if (difference.inDays > 0) {
      final days = difference.inDays;
      final plural = isArabic
          ? (days == 1 ? 'يوم' : 'أيام')
          : (days == 1 ? 'day' : 'days');
      return l10n?.daysAgo(days, plural) ?? '$days $plural ago';
    } else if (difference.inHours > 0) {
      final hours = difference.inHours;
      final plural = isArabic
          ? (hours == 1 ? 'ساعة' : 'ساعات')
          : (hours == 1 ? 'hour' : 'hours');
      return l10n?.hoursAgo(hours, plural) ?? '$hours $plural ago';
    } else {
      return l10n?.justNow ?? 'Just now';
    }
  }
}
