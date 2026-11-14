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
  const ViceDexApp({super.key, this.useGoogleFonts = true, this.state});
  final bool useGoogleFonts;

  /// Lets a test supply state backed by a fixed content pack. Null in the real
  /// app, which builds its own from the bundled pack.
  final AppState? state;

  @override
  State<ViceDexApp> createState() => _ViceDexAppState();
}

class _ViceDexAppState extends State<ViceDexApp> {
  late final AppState _state = widget.state ?? AppState();
  late final bool _ownsState = widget.state == null;

  @override
  void initState() {
    super.initState();
    // Loads the bundled pack and, when VICEDEX_PACK_URL is set, refreshes it.
    // Screens render from AppState.status while this runs.
    _state.load();
  }

  @override
  void dispose() {
    // A state passed in by a test belongs to the test.
    if (_ownsState) _state.dispose();
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
