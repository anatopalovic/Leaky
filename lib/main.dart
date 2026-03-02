import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'providers/app_providers.dart';
import 'screens/home/chat_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load .env for OPENAI_API_KEY. In production, replace with secure key management.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Safe fallback if .env is missing.
  }

  runApp(
    const ProviderScope(
      child: LeakyApp(),
    ),
  );
}

/// Onboarding completed flag. In-memory for MVP. Replace with persisted pref when needed.
final onboardingCompleteProvider = StateProvider<bool>((ref) => false);

class LeakyApp extends ConsumerWidget {
  const LeakyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingComplete = ref.watch(onboardingCompleteProvider);
    final user = ref.watch(currentUserProvider);

    return MaterialApp(
      title: 'Leaky',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey, brightness: Brightness.light),
        useMaterial3: true,
      ),
      home: _buildHome(ref, onboardingComplete, user != null),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const ChatScreen(),
      },
    );
  }

  Widget _buildHome(WidgetRef ref, bool onboardingComplete, bool isLoggedIn) {
    if (!onboardingComplete) {
      return OnboardingScreen(
        onComplete: () {
          ref.read(onboardingCompleteProvider.notifier).state = true;
          // Navigate to login by rebuilding; next build will show LoginScreen.
        },
      );
    }
    if (!isLoggedIn) {
      return const LoginScreen();
    }
    return const ChatScreen();
  }
}
