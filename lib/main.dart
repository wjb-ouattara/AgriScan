import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/database_service.dart';
import 'services/supabase_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  await SupabaseService.initialize();
  await DatabaseService().db;

  // 🛑 Initialisation de la couche native FlutterGemma
  try {
    print("🔌 Initialisation de la couche native FlutterGemma...");
    await FlutterGemma.initialize();
    print("✅ Couche native FlutterGemma prête !");
  } catch (e) {
    print("⚠️ Échec de l'initialisation native de Gemma : $e");
  }

  // Vérifier si déjà connecté
  final isLoggedIn = await DatabaseService().isLoggedIn();

  runApp(AgriScanApp(isLoggedIn: isLoggedIn));
}

class AgriScanApp extends StatelessWidget {
  final bool isLoggedIn;
  const AgriScanApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriScan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: isLoggedIn ? const AppShell() : const SplashScreen(),
    );
  }
}