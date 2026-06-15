import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_menu_style.dart';

class FullWidthDropdown<T> extends StatefulWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;
  final T? originalValue;

  const FullWidthDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.originalValue,
  });

  @override
  State<FullWidthDropdown<T>> createState() => _FullWidthDropdownState<T>();
}

class _FullWidthDropdownState<T> extends State<FullWidthDropdown<T>> {
  final GlobalKey _anchorKey = GlobalKey();
  bool _hovered = false;
  bool _open = false;
  // Menu width tracks the anchor, like DropdownButton did. Measured rather than
  // via LayoutBuilder, which can't sit under the IntrinsicHeight in the cards.
  double? _menuWidth;

  String _label(T v) => widget.originalValue == v
      ? '${widget.labelOf(v)} (Original)'
      : widget.labelOf(v);

  void _measureAnchor() {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (_menuWidth == null || (box.size.width - _menuWidth!).abs() > 0.5) {
      setState(() => _menuWidth = box.size.width);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAnchor());

    return MenuAnchor(
      style: kAppMenuStyle,
      onOpen: () => setState(() => _open = true),
      onClose: () => setState(() => _open = false),
      builder: (context, controller, _) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: AnimatedContainer(
            key: _anchorKey,
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _open
                    ? AppTheme.accent
                    : _hovered
                        ? AppTheme.surfaceVariant
                        : Colors.transparent,
                width: _open ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _label(widget.value),
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
      menuChildren: [
        for (final v in widget.items)
          MenuItemButton(
            style: appMenuItemStyle(),
            onPressed: () => widget.onChanged(v),
            child: _menuLabel(v),
          ),
      ],
    );
  }

  Widget _menuLabel(T v) {
    final text = Text(
      _label(v),
      style: TextStyle(
        color: v == widget.value ? AppTheme.accent : AppTheme.textPrimary,
        fontSize: 13,
      ),
    );
    if (_menuWidth == null) return text;
    return SizedBox(width: _menuWidth! - 24, child: text);
  }
}
