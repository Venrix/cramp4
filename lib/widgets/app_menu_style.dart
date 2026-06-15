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
      overlayColor: const WidgetStatePropertyAll(AppTheme.surfaceVariant),
    );
