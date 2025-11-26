import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Enum for skeleton content layout types
enum SkeletonContentType {
  row,
  wrap,
  listViewHorizontal,
  single,
  column,
  custom,
}

/// Configuration for skeleton items
class SkeletonItemConfig {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final EdgeInsets? margin;

  const SkeletonItemConfig({
    required this.width,
    required this.height,
    required this.borderRadius,
    this.margin,
  });

  /// Fixed width/height item
  factory SkeletonItemConfig.fixed({
    required double size,
    BorderRadius? borderRadius,
    EdgeInsets? margin,
  }) {
    return SkeletonItemConfig(
      width: size,
      height: size,
      borderRadius: borderRadius ?? BorderRadius.circular(4),
      margin: margin,
    );
  }

  /// Variable width item (for wrap layouts)
  factory SkeletonItemConfig.variable({
    required double baseWidth,
    required double height,
    double? widthIncrement,
    int? index,
    BorderRadius? borderRadius,
    EdgeInsets? margin,
  }) {
    final width = widthIncrement != null && index != null
        ? baseWidth + (index * widthIncrement)
        : baseWidth;
    return SkeletonItemConfig(
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(4),
      margin: margin,
    );
  }
}

/// Configuration for skeleton content
class SkeletonContentConfig {
  final SkeletonContentType type;
  final int itemCount;
  final List<SkeletonItemConfig>? itemConfigs;
  final double? listViewHeight;
  final double? spacing;
  final double? runSpacing;
  final Widget? customContent;

  const SkeletonContentConfig({
    required this.type,
    this.itemCount = 1,
    this.itemConfigs,
    this.listViewHeight,
    this.spacing,
    this.runSpacing,
    this.customContent,
  });

  /// Row layout configuration
  factory SkeletonContentConfig.row({
    required int itemCount,
    required SkeletonItemConfig itemConfig,
    double spacing = 12,
  }) {
    return SkeletonContentConfig(
      type: SkeletonContentType.row,
      itemCount: itemCount,
      itemConfigs: List.generate(itemCount, (_) => itemConfig),
      spacing: spacing,
    );
  }

  /// Wrap layout configuration
  factory SkeletonContentConfig.wrap({
    required int itemCount,
    required SkeletonItemConfig baseConfig,
    double spacing = 8,
    double runSpacing = 8,
  }) {
    return SkeletonContentConfig(
      type: SkeletonContentType.wrap,
      itemCount: itemCount,
      itemConfigs: List.generate(
        itemCount,
        (index) => baseConfig.width == baseConfig.width
            ? baseConfig
            : SkeletonItemConfig.variable(
                baseWidth: baseConfig.width,
                height: baseConfig.height,
                borderRadius: baseConfig.borderRadius,
                margin: baseConfig.margin,
              ),
      ),
      spacing: spacing,
      runSpacing: runSpacing,
    );
  }

  /// Horizontal ListView configuration
  factory SkeletonContentConfig.listViewHorizontal({
    required int itemCount,
    required SkeletonItemConfig itemConfig,
    required double height,
    double spacing = 8,
  }) {
    return SkeletonContentConfig(
      type: SkeletonContentType.listViewHorizontal,
      itemCount: itemCount,
      itemConfigs: List.generate(itemCount, (_) => itemConfig),
      listViewHeight: height,
      spacing: spacing,
    );
  }

  /// Single item configuration
  factory SkeletonContentConfig.single({
    required SkeletonItemConfig itemConfig,
  }) {
    return SkeletonContentConfig(
      type: SkeletonContentType.single,
      itemCount: 1,
      itemConfigs: [itemConfig],
    );
  }

  /// Column with multiple rows
  factory SkeletonContentConfig.column({
    required List<Widget> children,
  }) {
    return SkeletonContentConfig(
      type: SkeletonContentType.column,
      customContent: Column(children: children),
    );
  }

  /// Custom content
  factory SkeletonContentConfig.custom({
    required Widget content,
  }) {
    return SkeletonContentConfig(
      type: SkeletonContentType.custom,
      customContent: content,
    );
  }
}

/// Reusable skeleton loading widget that can handle all skeleton patterns
class SpecialPackSkeletonWidget extends StatelessWidget {
  /// Title configuration (optional)
  final double? titleWidth;
  final double titleHeight;
  final bool showTitle;

  /// Content configuration
  final SkeletonContentConfig contentConfig;

  /// Optional wrapper configuration
  final EdgeInsets? wrapperPadding;
  final Color? wrapperColor;
  final BorderRadius? wrapperBorderRadius;
  final bool hasWrapper;

  /// Main axis alignment for Row layouts
  final MainAxisAlignment? rowMainAxisAlignment;

  const SpecialPackSkeletonWidget({
    required this.contentConfig,
    super.key,
    this.titleWidth,
    this.titleHeight = 18,
    this.showTitle = true,
    this.wrapperPadding,
    this.wrapperColor,
    this.wrapperBorderRadius,
    this.hasWrapper = false,
    this.rowMainAxisAlignment,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle && titleWidth != null) ...[
          _buildShimmerContainer(
            width: titleWidth!,
            height: titleHeight,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
        ],
        _buildContent(),
      ],
    );

    // Wrap in container if specified
    if (hasWrapper) {
      content = Container(
        padding: wrapperPadding,
        decoration: BoxDecoration(
          color: wrapperColor ?? Colors.grey[100],
          borderRadius: wrapperBorderRadius ?? BorderRadius.circular(16),
        ),
        child: content,
      );
    }

    return content;
  }

  Widget _buildContent() {
    switch (contentConfig.type) {
      case SkeletonContentType.row:
        return Row(
          children: _buildRowItems(),
        );
      case SkeletonContentType.wrap:
        return Wrap(
          spacing: contentConfig.spacing ?? 8,
          runSpacing: contentConfig.runSpacing ?? 8,
          children: _buildWrapItems(),
        );
      case SkeletonContentType.listViewHorizontal:
        return SizedBox(
          height: contentConfig.listViewHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: contentConfig.itemCount,
            itemBuilder: (context, index) {
              final config = contentConfig.itemConfigs?[index];
              if (config == null) return const SizedBox.shrink();
              return Container(
                margin: EdgeInsets.only(
                  right: index < contentConfig.itemCount - 1
                      ? (contentConfig.spacing ?? 8)
                      : 0,
                ),
                child: _buildShimmerContainer(
                  width: config.width,
                  height: config.height,
                  borderRadius: config.borderRadius,
                ),
              );
            },
          ),
        );
      case SkeletonContentType.single:
        final config = contentConfig.itemConfigs?.first;
        if (config == null) return const SizedBox.shrink();
        return _buildShimmerContainer(
          width: config.width,
          height: config.height,
          borderRadius: config.borderRadius,
        );
      case SkeletonContentType.column:
        return contentConfig.customContent ?? const SizedBox.shrink();
      case SkeletonContentType.custom:
        return contentConfig.customContent ?? const SizedBox.shrink();
    }
  }

  List<Widget> _buildRowItems() {
    if (contentConfig.itemConfigs == null) return [];
    return contentConfig.itemConfigs!.asMap().entries.map((entry) {
      final index = entry.key;
      final config = entry.value;
      return Container(
        margin: EdgeInsets.only(
          right: index < contentConfig.itemCount - 1
              ? (contentConfig.spacing ?? 12)
              : 0,
        ),
        child: _buildShimmerContainer(
          width: config.width,
          height: config.height,
          borderRadius: config.borderRadius,
        ),
      );
    }).toList();
  }

  List<Widget> _buildWrapItems() {
    if (contentConfig.itemConfigs == null) return [];
    return contentConfig.itemConfigs!.map((config) {
      return _buildShimmerContainer(
        width: config.width,
        height: config.height,
        borderRadius: config.borderRadius,
      );
    }).toList();
  }

  Widget _buildShimmerContainer({
    required double width,
    required double height,
    required BorderRadius borderRadius,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1200),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
