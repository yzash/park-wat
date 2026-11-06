import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/api.dart';
import 'data/local_store.dart';
import 'state/masters.dart';
import 'state/session.dart';
import 'state/sync.dart';
import 'ui/home_shell.dart';
import 'ui/login_page.dart';
import 'util/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  if (!AppConfig.isConfigured) {
    runApp(const _NotConfiguredApp());
    return;
  }
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey);
  final store = await LocalStore.open();
  final api = Api();
  final session = SessionState(api, store);
  final masters = MastersState(api, store);
  final sync = SyncState(api, store);

  runApp(MultiProvider(
    providers: [
      Provider.value(value: api),
      Provider.value(value: store),
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: masters),
      ChangeNotifierProvider.value(value: sync),
    ],
    child: const ParkerApp(),
  ));
  session.init();
}

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0B5394), brightness: b);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 52), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ),
  );
}

class ParkerApp extends StatelessWidget {
  const ParkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (c) => c.t.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionState>();
    return switch (s.status) {
      SessionStatus.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
      SessionStatus.signedOut => const LoginPage(),
      SessionStatus.signedIn => HomeShell(key: ValueKey(s.user!.id)),
    };
  }
}

class _NotConfiguredApp extends StatelessWidget {
  const _NotConfiguredApp();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'App is not configured.\nBuild with --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
