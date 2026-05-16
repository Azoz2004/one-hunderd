import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers/savings_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  // Initialize notifications
  await NotificationService().init();

  // Pre-load persisted data before painting the first frame
  final provider = SavingsProvider();
  await provider.initializeAuthAndData();


  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const SavingsChallengeApp(),
    ),
  );
}

class SavingsChallengeApp extends StatelessWidget {
  const SavingsChallengeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '100-Day Savings Challenge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Consumer<SavingsProvider>(
        builder: (context, provider, _) {
          return provider.isLoggedIn
              ? const HomeScreen()
              : const AuthScreen();
        },
      ),
    );
  }
}
