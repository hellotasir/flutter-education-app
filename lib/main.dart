import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_education_app/features/app/screens/splash_screen.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';
import 'package:flutter_education_app/firebase_options.dart';
import 'package:flutter_education_app/others/providers/app_theme_provider.dart';
import 'package:flutter_education_app/features/app/widgets/material_widget.dart';
import 'package:flutter_education_app/others/services/background_notification_service.dart';
import 'package:flutter_education_app/others/services/local_notification_service.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.development');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  sqfliteFfiInit();

  // Init local notifications first — creates the Android channel
  await LocalNotificationService.instance.init();

  // Background service uses the same channel id; channel already exists
  await initBackgroundService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<ChatRepository>(
          create: (_) => ChatRepository(),
          dispose: (_, repo) => repo.disposeTypingChannel(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialWidget(child: SplashScreen());
  }
}
