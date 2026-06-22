// Fill in your RevenueCat API keys from the RevenueCat dashboard.
// iOS key:  App → API Keys → Public app-specific key (starts with "appl_")
// Android:  App → API Keys → Public app-specific key (starts with "goog_")
// This file should be gitignored if you commit keys directly here;
// alternatively use dart-defines and String.fromEnvironment.

// Single key used for both platforms (legacy shared key format).
// Move to dart-defines before going to production.
const kRevenueCatIosKey = 'appl_cHSXBAlGposupBWyTsMCVtHiusw';
const kRevenueCatAndroidKey = 'goog_EmEhGKBBnLmeyjFHamTABZjmkOa';

// Must match the Entitlement identifier exactly (case-sensitive) in RevenueCat.
const kEntitlementId = 'Threshold Pro';

// Number of free agreement sends before the paywall kicks in.
const kFreeAgreementLimit = 2;

// Set to false via --dart-define=PAYWALL_ENABLED=false to bypass the paywall
// for beta/internal builds without touching source code.
const kPaywallEnabled = bool.fromEnvironment(
  'PAYWALL_ENABLED',
  defaultValue: true,
);
