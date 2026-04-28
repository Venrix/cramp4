import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';

class AppTabBar extends StatefulWidget {
  const AppTabBar({super.key});

  @override
  State<AppTabBar> createState() => _AppTabBarState();
}

class _AppTabBarState extends State<AppTabBar> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = context.watch<AppStateProvider>().tabIndex;

    return Container(
      height: 48,
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            'cramp4',
            style: TextStyle(
              color: AppTheme.accent,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 16),
          _TabButton(
            label: 'Encode',
            icon: Icons.settings_input_component_outlined,
            index: 0,
            current: tabIndex,
          ),
          const SizedBox(width: 4),
          _TabButton(
            label: 'Trim',
            icon: Icons.movie_edit,
            index: 1,
            current: tabIndex,
          ),
          const SizedBox(width: 4),
          _TabButton(
            label: 'Settings',
            icon: Icons.settings_outlined,
            index: 2,
            current: tabIndex,
          ),
          const Spacer(),
          if (_version.isNotEmpty)
            Text(
              _version,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final int index;
  final int current;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.index,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: TextButton(
      onPressed: () => context.read<AppStateProvider>().setTab(index),
      style: TextButton.styleFrom(
        foregroundColor: isActive ? AppTheme.accent : AppTheme.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        backgroundColor: isActive ? AppTheme.accent.withAlpha(30) : Colors.transparent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    ),
    );
  }
}
