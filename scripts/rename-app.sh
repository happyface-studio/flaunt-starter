#!/usr/bin/env bash
# Bootstrap a new app from this template.
#
# Replaces {{APP_NAME}}, {{BUNDLE_ID}}, {{PROJECT_ID}}, {{SUPABASE_PROJECT_REF_DEV}},
# {{SUPABASE_PROJECT_REF_PROD}} in docs/configs, and rewrites the three identity
# constants in ios/Project.swift (appName, appDisplayName, bundleID).
#
# Usage:
#   ./scripts/rename-app.sh "MyApp" "com.example.myapp" "<dev-ref>" "<prod-ref>"
#
# After: cd ios && cp Secrets.xcconfig.template Secrets.xcconfig && mise install && tuist generate
set -euo pipefail

if [ "$#" -ne 4 ]; then
  cat >&2 <<'USAGE'
usage: rename-app.sh APP_NAME BUNDLE_ID SUPABASE_PROJECT_REF_DEV SUPABASE_PROJECT_REF_PROD

  APP_NAME                     Display name, no spaces (e.g. "MyApp")
  BUNDLE_ID                    Reverse-DNS bundle ID (e.g. "com.example.myapp")
  SUPABASE_PROJECT_REF_DEV     Supabase project ref for dev/staging
  SUPABASE_PROJECT_REF_PROD    Supabase project ref for production
USAGE
  exit 64
fi

APP_NAME="$1"
BUNDLE_ID="$2"
DEV_REF="$3"
PROD_REF="$4"

PROJECT_ID="$(printf '%s' "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//;s/-$//')"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "Renaming template to:"
echo "  APP_NAME   = $APP_NAME"
echo "  BUNDLE_ID  = $BUNDLE_ID"
echo "  PROJECT_ID = $PROJECT_ID"
echo "  DEV_REF    = $DEV_REF"
echo "  PROD_REF   = $PROD_REF"
echo

# 1. Token replacement in tracked text files (excludes binaries and node_modules / Derived / .git).
FILES=$(git ls-files | grep -E '\.(md|toml|json|yml|yaml|sh|swift|xcconfig|template)$|^README|^CLAUDE\.md$' | grep -v '^scripts/rename-app\.sh$' || true)
if [ -z "$FILES" ]; then
  echo "warn: no tracked files found — are you running this in a git repo?" >&2
fi

# Use a portable sed -i invocation (BSD/macOS requires the empty '' arg).
SED_INPLACE=(sed -i '')
if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(sed -i)  # GNU
fi

echo "$FILES" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  if grep -q '{{APP_NAME}}\|{{BUNDLE_ID}}\|{{PROJECT_ID}}\|{{SUPABASE_PROJECT_REF_DEV}}\|{{SUPABASE_PROJECT_REF_PROD}}' "$f"; then
    "${SED_INPLACE[@]}" \
      -e "s/{{APP_NAME}}/$APP_NAME/g" \
      -e "s/{{BUNDLE_ID}}/$BUNDLE_ID/g" \
      -e "s/{{PROJECT_ID}}/$PROJECT_ID/g" \
      -e "s/{{SUPABASE_PROJECT_REF_DEV}}/$DEV_REF/g" \
      -e "s/{{SUPABASE_PROJECT_REF_PROD}}/$PROD_REF/g" \
      "$f"
    echo "  tokenized: $f"
  fi
done

# 2. Rewrite the three identity constants in ios/Project.swift.
PROJECT_SWIFT="ios/Project.swift"
if [ -f "$PROJECT_SWIFT" ]; then
  "${SED_INPLACE[@]}" \
    -e "s/let appName = \"Flaunt\"/let appName = \"$APP_NAME\"/" \
    -e "s/let appDisplayName = \"Flaunt\"/let appDisplayName = \"$APP_NAME\"/" \
    -e "s/let bundleID = \"studio\\.happyface\\.flaunt\"/let bundleID = \"$BUNDLE_ID\"/" \
    "$PROJECT_SWIFT"
  echo "  rewrote:   $PROJECT_SWIFT"
fi

echo
echo "Done. Verify no tokens remain:"
echo "    grep -rn '{{' --include='*.md' --include='*.toml' --include='*.json' --include='*.swift' --include='*.xcconfig' ."
echo
echo "Next:"
echo "    cd ios && cp Secrets.xcconfig.template Secrets.xcconfig && mise install && tuist generate"
