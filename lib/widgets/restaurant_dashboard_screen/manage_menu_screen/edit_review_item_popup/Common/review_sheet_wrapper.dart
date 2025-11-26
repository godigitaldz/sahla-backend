import 'package:flutter/material.dart';

/// Review Sheet Wrapper Widget
/// Provides the common DraggableScrollableSheet structure for review widgets
class ReviewSheetWrapper extends StatelessWidget {
  final ScrollController? scrollController;
  final Widget Function(ScrollController controller) builder;

  const ReviewSheetWrapper({
    required this.builder,
    this.scrollController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(
                child: builder(scrollController ?? controller),
              ),
            ],
          ),
        );
      },
    );
  }
}
