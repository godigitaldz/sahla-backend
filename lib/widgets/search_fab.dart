import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class SearchFab extends StatefulWidget {
  const SearchFab({
    required this.onChanged,
    super.key,
    this.onCleared,
    this.initialQuery = '',
    this.visible = true,
    this.expandProgress = 1.0,
    this.showFloatingStyle = true,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback? onCleared;
  final String initialQuery;
  final bool visible;
  final double expandProgress; // 0.0 = collapsed icon, 1.0 = full width
  final bool showFloatingStyle; // Whether to show shadow/floating style

  @override
  State<SearchFab> createState() => _SearchFabState();
}

class _SearchFabState extends State<SearchFab>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _open = false;
  Timer? _debounce;

  static const _pillHeight = 44.0;
  static const _radius = 24.0;
  static const _accent = Color(0xFFF57C00); // Orange 600

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    // Auto-open if expandProgress is high (scrolled)
    _open = widget.expandProgress > 0.5;
  }

  @override
  void didUpdateWidget(SearchFab oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update controller if initialQuery changed
    if (widget.initialQuery != oldWidget.initialQuery &&
        widget.initialQuery != _controller.text) {
      _controller.text = widget.initialQuery;
    }

    // Auto-expand when scroll progress changes
    // Only auto-open when scrolled significantly (70% progress)
    if (widget.expandProgress > 0.7 && !_open) {
      setState(() => _open = true);
      // Don't auto-focus to avoid keyboard popping up unexpectedly
      // User can tap to focus if they want to search
    } else if (widget.expandProgress <= 0.2 &&
        _open &&
        _controller.text.isEmpty) {
      setState(() => _open = false);
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setOpen(bool v) {
    if (_open == v) return;
    setState(() => _open = v);
    if (v) {
      // wait one frame then request focus
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _focus.requestFocus());
    } else {
      _focus.unfocus();
    }
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      widget.onChanged(q.trim());
    });
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // Calculate width based on both user interaction and scroll progress
    final baseExpandedWidth = (w * 0.85).clamp(280.0, double.infinity);
    const collapsedWidth = _pillHeight;

    // Use the higher of user-opened state or scroll progress
    final effectiveProgress =
        _open ? 1.0 : widget.expandProgress.clamp(0.0, 1.0);
    final currentWidth = collapsedWidth +
        (baseExpandedWidth - collapsedWidth) * effectiveProgress;

    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: widget.visible ? 1 : 0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          width: currentWidth,
          height: _pillHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: widget.showFloatingStyle
                ? const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.hardEdge,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Only show expanded content when width is large enough
              return constraints.maxWidth > 100
                  ? _buildExpanded()
                  : _buildCollapsed();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsed() {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _setOpen(true),
        child: const Center(
          child: Icon(Icons.search, size: 22, color: _accent),
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    return Material(
      color: Colors.transparent,
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.search, size: 20, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onChanged,
              onTap: () {
                // Ensure the field is open and focused when tapped
                if (!_open) {
                  _setOpen(true);
                }
                // Request focus when tapped to ensure keyboard appears
                if (!_focus.hasFocus) {
                  _focus.requestFocus();
                }
              },
              onSubmitted: (value) {
                // Handle search submission if needed
                _focus.unfocus();
              },
              textInputAction: TextInputAction.search,
              enabled: true,
              readOnly: false,
              autofocus: false,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)?.searchMenuItems ??
                    'Search menu items…',
                hintStyle:
                    const TextStyle(fontSize: 14, color: Colors.black38),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                _clear();
              } else {
                _setOpen(false);
              }
            },
            icon: const Icon(Icons.close, size: 20, color: Colors.black54),
            splashRadius: 20,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
