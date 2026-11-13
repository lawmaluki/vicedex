import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const ViceDexApp());
}

class ViceDexApp extends StatefulWidget {
  const ViceDexApp({super.key, this.useGoogleFonts = true});
  final bool useGoogleFonts;

  @override
  State<ViceDexApp> createState() => _ViceDexAppState();
}

class _ViceDexAppState extends State<ViceDexApp> {
  final _state = AppState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'ViceDex',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(useGoogleFonts: widget.useGoogleFonts),
        home: const AppShell(),
      ),
    );
  }
}
