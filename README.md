# Leaky

Chat-first money tracking app that detects small spending leaks. **MVP with mocked data only** — no real auth, AI, or backend.

## Run the app

1. Ensure Flutter is installed. If the project has no `android/` or `ios/` folders, run:
   ```bash
   flutter create . --project-name leaky
   ```
2. Then:
   ```bash
   flutter pub get
   flutter run
   ```
   Choose the iOS simulator or a connected device.

## Architecture

- **models/** — `UserModel`, `TransactionModel`, `ChatMessageModel`
- **services/** — all mock, replaceable later:
  - `MockAuthService` → Supabase auth
  - `MockTransactionService` → Supabase DB
  - `MockParserService` → AI parser
  - `InsightService` → AI insights
- **screens/** — onboarding (4), login, chat (home), monthly overview
- **widgets/** — chat bubble, monthly insight button
- **providers/** — Riverpod providers for auth, transactions, chat messages

## Flow

1. Onboarding (4 screens) → Continue
2. Login (Sign in with Apple / Continue with Email) → mocked sign-in → Home
3. Home = chat: type e.g. "Coffee 250", "Wolt 1450", "Netflix 9.99" → parsed and saved locally, coach-style reply
4. Top-right icon → Monthly overview (total, by category, yearly projection, bar chart)
5. "Generate Monthly Insight" button → dialog with monthly summary

No API keys required. Everything runs offline.
