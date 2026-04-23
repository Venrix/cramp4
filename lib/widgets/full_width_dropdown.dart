import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _hovered ? AppTheme.surfaceVariant : Colors.transparent,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: widget.value,
            isExpanded: true,
            dropdownColor: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
            mouseCursor: SystemMouseCursors.click,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
            items: widget.items
                .map((v) => DropdownMenuItem<T>(
                      value: v,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            widget.originalValue == v
                                ? '${widget.labelOf(v)} (Original)'
                                : widget.labelOf(v),
                          ),
                        ),
                      ),
                    ))
                .toList(),
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}
