import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PillDropdown<T> extends StatefulWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final EdgeInsetsGeometry? margin;
  final TextStyle? hintStyle;
  final BorderRadius? menuBorderRadius;
  final double? menuMaxHeight;

  const PillDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
    this.label,
    this.hint,
    this.validator,
    this.margin,
    this.hintStyle,
    this.menuBorderRadius,
    this.menuMaxHeight,
  });
  @override
  State<PillDropdown<T>> createState() => _PillDropdownState<T>();
}

class _PillDropdownState<T> extends State<PillDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  T? _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant PillDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  void _toggleOverlay() {
    if (_overlayEntry == null) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    // Ensure the widget is laid out before accessing RenderBox
    final context = _fieldKey.currentContext;
    if (context == null) return;

    final renderObject = context.findRenderObject();
    if (renderObject == null || renderObject is! RenderBox) return;

    final RenderBox box = renderObject;
    final Size size = box.size;
    _overlayEntry = OverlayEntry(
      builder: (context) {
        final BorderRadius radius = widget.menuBorderRadius ??
            const BorderRadius.vertical(bottom: Radius.circular(20));
        final double maxHeight = widget.menuMaxHeight ?? 280;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(onTap: _removeOverlay),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 6),
              child: Material(
                elevation: 8,
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxHeight,
                    minWidth: size.width,
                    maxWidth: size.width,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: radius,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    // PERFORMANCE FIX: Use ListView.builder instead of ListView(children)
                    // This improves performance for dropdowns with many items
                    // shrinkWrap is acceptable here since it's in an overlay with maxHeight constraint
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: widget.items.length,
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        final bool selected = item.value == _currentValue;
                        return InkWell(
                          onTap: () {
                            setState(() => _currentValue = item.value);
                            widget.onChanged?.call(item.value);
                            _removeOverlay();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: DefaultTextStyle(
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.orange[700]
                                    : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              child: IconTheme(
                                data: IconThemeData(
                                    color: selected
                                        ? Colors.orange[700]
                                        : Colors.black87,
                                    size: 16),
                                child: item.child,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: GestureDetector(
          key: _fieldKey,
          onTap: _toggleOverlay,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 34),
            child: InputDecorator(
              isEmpty: _currentValue == null,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                hintStyle: widget.hintStyle ??
                    GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                    ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      BorderSide(color: Colors.orange[600]!, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                suffixIcon: const Icon(Icons.expand_more,
                    color: Colors.black87, size: 18),
              ),
              child: _buildSelectedChild(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedChild() {
    final selectedItem = widget.items.firstWhere(
      (it) => it.value == _currentValue,
      orElse: () => widget.items.isNotEmpty
          ? widget.items.first
          : DropdownMenuItem<T>(value: null, child: const SizedBox.shrink()),
    );
    if (_currentValue == null) {
      return Text(
        widget.hint ?? '',
        style: widget.hintStyle ??
            GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return DefaultTextStyle(
      style: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: IconTheme(
        data: const IconThemeData(color: Colors.black87, size: 16),
        child: selectedItem.child,
      ),
    );
  }
}
