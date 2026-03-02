import 'package:flutter/material.dart';

import 'onboarding_page.dart';

/// Onboarding flow: 4 screens then navigate to login.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    OnboardingPage(
      headline: "Your money doesn't disappear.\nIt drips.",
      body: 'Small spends add up. Leaky helps you see where.',
    ),
    OnboardingPage(
      headline: 'Just type what you spent',
      body: 'e.g. "Coffee 250" or "Wolt 1450"\nWe understand and categorize it.',
    ),
    OnboardingPage(
      headline: 'See your month at a glance',
      body: 'Total spending, by category, and a simple yearly projection.',
    ),
    OnboardingPage(
      headline: 'Ready to plug the leaks?',
      body: 'Continue to sign in and start tracking.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  void _nextOrComplete() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) => _pages[index],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      _pages.length,
                      (i) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == i
                              ? Colors.black87
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _nextOrComplete,
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'Continue' : 'Next',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
