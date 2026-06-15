import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared flyout styling so every popup (dropdowns + filename combobox) looks
/// identical: background fill, radius 8, surfaceVariant border.
final MenuStyle kAppMenuStyle = MenuStyle(
  backgroundColor: const WidgetStatePropertyAll(AppTheme.background),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppTheme.surfaceVariant),
    ),
  ),
);

/// Matching style for items inside [kAppMenuStyle] menus.
ButtonStyle appMenuItemStyle() => MenuItemButton.styleFrom(
      foregroundColor: AppTheme.textPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ).copyWith(
      mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
      // No focus border — hover/focus/press all use the same grey overlay so the
      // accent focus ring never flashes when the pointer leaves an item.
      side: const WidgetStatePropertyAll(BorderSide.none),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused) ||
            states.contains(WidgetState.pressed)) {
          return AppTheme.surfaceVariant;
        }
        return Colors.transparent;
      }),
    );
