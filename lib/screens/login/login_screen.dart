import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';

/// Mock login. No real auth. Replace with Supabase when ready.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(currentUserProvider.notifier);
    final isLoading = ref.watch(loginLoadingProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Leaky',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Plug the small leaks.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 48),
              _LoginButton(
                label: 'Sign in with Apple',
                onPressed: isLoading
                    ? null
                    : () async {
                        ref.read(loginLoadingProvider.notifier).state = true;
                        await auth.signIn();
                        ref.read(loginLoadingProvider.notifier).state = false;
                        if (context.mounted) {
                          Navigator.of(context).pushReplacementNamed('/home');
                        }
                      },
              ),
              const SizedBox(height: 12),
              _LoginButton(
                label: 'Continue with Email',
                onPressed: isLoading
                    ? null
                    : () async {
                        ref.read(loginLoadingProvider.notifier).state = true;
                        await auth.signIn();
                        ref.read(loginLoadingProvider.notifier).state = false;
                        if (context.mounted) {
                          Navigator.of(context).pushReplacementNamed('/home');
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: BorderSide(color: Colors.grey.shade400),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

/// Simple loading state for login buttons.
final loginLoadingProvider = StateProvider<bool>((ref) => false);
