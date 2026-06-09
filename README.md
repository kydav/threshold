# Threshold

Mobile-first buyer representation agreement tool for real estate agents.

## Setup

### 1. Firebase
Run `flutterfire configure` after setting up your Firebase project (see issue #1).
The generated `lib/firebase_options.dart` is gitignored — never commit it.

### 2. Run the app

**Development (no email sending):**
```bash
flutter run
```

**With email delivery (SendGrid):**
```bash
flutter run \
  --dart-define=SENDGRID_API_KEY=SG.your_key_here \
  --dart-define=FROM_EMAIL=agreements@yourdomain.com
```

If `SENDGRID_API_KEY` is not set, the app runs normally but email delivery is
skipped and agreements are marked delivered immediately (useful for UI testing).

### 3. Environment variables
Never hardcode keys. Pass them at build time via `--dart-define`:

| Variable | Description |
|---|---|
| `SENDGRID_API_KEY` | SendGrid API key for email delivery |
| `FROM_EMAIL` | Verified sender email address |

For production builds, set these in your CI/CD environment.

## Architecture

```
lib/
  core/
    services/
      delivery_service.dart     # SendGrid API call + retry logic
      connectivity_watcher.dart # Auto-retry on network restore
  features/
    auth/          # Firebase Auth login/signup
    agreement/     # Form fill, signature capture, PDF generation
    history/       # Past agreements list
```

## Offline behaviour
PDFs are generated and stored on-device first. Email delivery is attempted
immediately and retried automatically when connectivity is restored. The local
PDF is preserved until delivery is confirmed.
