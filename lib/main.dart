import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'providers/app_state_provider.dart';
import 'providers/encoding_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/encode_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/trim_screen.dart';
import 'services/app_logger.dart';
import 'theme/app_theme.dart';
import 'widgets/app_tab_bar.dart';
import 'widgets/bottom_action_bar.dart';
import 'widgets/drop_zone.dart';
import 'widgets/info_bar.dart';

void main(List<String> args) {
  AppLogger.init();
  AppLogger.runGuarded(() => _start(args));
}

Future<void> _start(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  final appState = AppStateProvider();
  await appState.init();
  AppLogger.info('main', 'Startup complete (args: ${args.length})');
  if (args.isNotEmpty) {
    // Launched from context menu — load the file immediately
    AppLogger.info('main', 'Opening file from launch arg: ${args.first}');
    unawaited(appState.loadFile(args.first, settingsProvider.effectiveFfprobePath, settingsProvider));
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<AppStateProvider>.value(value: appState),
        ChangeNotifierProvider<EncodingProvider>(create: (_) => EncodingProvider()),
      ],
      child: const CrampApp(),
    ),
  );
}

class CrampApp extends StatelessWidget {
  const CrampApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cramp4',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final tabIndex = context.watch<AppStateProvider>().tabIndex;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      body: DropZone(
      child: Column(
        children: [
          const AppTabBar(),
          const Divider(height: 1, color: AppTheme.surfaceVariant),
          const InfoBar(),
          const Divider(height: 1, color: AppTheme.surfaceVariant),
          Expanded(
            child: IndexedStack(
              index: tabIndex,
              children: const [
                EncodeScreen(),
                TrimScreen(),
                SettingsScreen(),
              ],
            ),
          ),
          const BottomActionBar(),
        ],
      ),
      ),
      ),
    );
  }
}
