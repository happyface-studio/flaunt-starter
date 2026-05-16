#!/bin/bash
set -euo pipefail

echo "=== Xcode Cloud Post-Clone Script ==="

# --- Install Tuist via mise (official method) ---
echo "Installing mise..."
curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"

echo "Installing Tuist via mise..."
export MISE_HTTP_TIMEOUT=300
mise install --yes || mise install --yes

echo "Tuist version: $(mise exec -- tuist version)"

# --- Set build number from Xcode Cloud ---
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  echo "Setting build number to ${CI_BUILD_NUMBER}..."
  sed -i '' "s/let appBuildNumber = \"[0-9]*\"/let appBuildNumber = \"${CI_BUILD_NUMBER}\"/" \
    "$CI_PRIMARY_REPOSITORY_PATH/ios/Project.swift"
fi

# --- Inject secret plists (from Xcode Cloud environment variables) ---
# Ensure Config directories exist (git doesn't track empty dirs)
mkdir -p "$CI_PRIMARY_REPOSITORY_PATH/ios/Targets/SupabaseKit/Config"
mkdir -p "$CI_PRIMARY_REPOSITORY_PATH/ios/Targets/AnalyticsKit/Config"
mkdir -p "$CI_PRIMARY_REPOSITORY_PATH/ios/Targets/InAppPurchaseKit/Config"
mkdir -p "$CI_PRIMARY_REPOSITORY_PATH/ios/Targets/NotifKit/Config"

if [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_KEY:-}" ]; then
  echo "Injecting Supabase-Info.plist..."
  cat > "$CI_PRIMARY_REPOSITORY_PATH/ios/Targets/SupabaseKit/Config/Supabase-Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SUPABASE_URL</key>
    <string>${SUPABASE_URL}</string>
    <key>SUPABASE_KEY</key>
    <string>${SUPABASE_KEY}</string>
</dict>
</plist>
EOF
fi

if [ -n "${POSTHOG_API_KEY:-}" ] && [ -n "${POSTHOG_HOST:-}" ]; then
  echo "Injecting PostHog-Info.plist..."
  cat > "$CI_PRIMARY_REPOSITORY_PATH/ios/Targets/AnalyticsKit/Config/PostHog-Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>POSTHOG_API_KEY</key>
    <string>${POSTHOG_API_KEY}</string>
    <key>POSTHOG_HOST</key>
    <string>${POSTHOG_HOST}</string>
</dict>
</plist>
EOF
fi

if [ -n "${REVENUECAT_API_KEY:-}" ]; then
  echo "Injecting RevenueCat-Info.plist..."
  cat > "$CI_PRIMARY_REPOSITORY_PATH/ios/Targets/InAppPurchaseKit/Config/RevenueCat-Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>REVENUECAT_API_KEY</key>
    <string>${REVENUECAT_API_KEY}</string>
</dict>
</plist>
EOF
fi

if [ -n "${ONESIGNAL_APP_ID:-}" ]; then
  echo "Injecting OneSignal-Info.plist..."
  cat > "$CI_PRIMARY_REPOSITORY_PATH/ios/Targets/NotifKit/Config/OneSignal-Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>ONESIGNAL_APP_ID</key>
    <string>${ONESIGNAL_APP_ID}</string>
</dict>
</plist>
EOF
fi

# --- Generate Xcode project with Tuist ---
echo "Running tuist generate..."
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
mise exec -- tuist generate --no-open

echo "=== Post-clone complete ==="
