import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:faithful_journal/theme.dart';
import 'package:faithful_journal/nav.dart';
import 'package:faithful_journal/auth/supabase_auth_manager.dart';
import 'package:faithful_journal/services/entry_service.dart';
import 'package:faithful_journal/services/unsaved_changes_service.dart';
import 'package:faithful_journal/supabase/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Supabase initialize failed (continuing in local mode): $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => SupabaseAuthManager()),
        ChangeNotifierProvider(create: (_) => EntryService()),
        ChangeNotifierProvider(create: (_) => UnsavedChangesService()),
      ],
      child: MaterialApp.router(
        title: 'Faithful Journal',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
