#!/usr/bin/env bash
#
# One-shot release for iTraffic:
#   generate → archive (Developer ID) → export → zip → notarise → staple
#   → re-zip → Gatekeeper check → GitHub release → print the Homebrew bump line.
#
# Usage:
#   scripts/release.sh              # full run, publishes the GitHub release
#   scripts/release.sh --dry-run    # everything except publishing
#
# The version is read from project.yml (MARKETING_VERSION) — bump it there and
# in CURRENT_PROJECT_VERSION first, then run this.
#
# Requirements:
#   - xcodegen, gh (authenticated)
#   - a "Developer ID Application" certificate in the login keychain
#   - notarisation credentials: ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_PATH
#
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="ITraffic"
SCHEME="ITrafficMonitorForMac"
PROJECT="ITrafficMonitorForMac.xcodeproj"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Foam Zou (8K28G7K6W8)}"
TEAM_ID="${TEAM_ID:-8K28G7K6W8}"

VERSION="$(awk '/MARKETING_VERSION:/ {print $2; exit}' project.yml)"
[[ -n "$VERSION" ]] || { echo "!! could not read MARKETING_VERSION from project.yml"; exit 1; }

OUT="/tmp/${APP_NAME}-release-${VERSION}"
DIST="$OUT/dist"
ZIP="$OUT/${APP_NAME}-v${VERSION}.zip"
APP="$DIST/${APP_NAME}.app"

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- preflight --
say "Preflight (v$VERSION)"

for tool in xcodegen gh xcrun ditto; do
  command -v "$tool" >/dev/null || { echo "!! missing: $tool"; exit 1; }
done

security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY" \
  || { echo "!! signing identity not found: $SIGN_IDENTITY"; exit 1; }

for var in ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY_PATH; do
  [[ -n "${!var:-}" ]] || { echo "!! notarisation credential not set: \$$var"; exit 1; }
done
[[ -f "$ASC_PRIVATE_KEY_PATH" ]] || { echo "!! ASC_PRIVATE_KEY_PATH does not exist"; exit 1; }

if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "!! tag v$VERSION already exists — bump MARKETING_VERSION first"
  exit 1
fi

echo "ok — signing as: $SIGN_IDENTITY"

# ------------------------------------------------------------------- build ---
say "Generating project + archiving"
mkdir -p "$OUT"          # never rm -rf: safe-rm blocks it
xcodegen generate

xcodebuild archive \
  -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -archivePath "$OUT/Release.xcarchive" -quiet \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  OTHER_CODE_SIGN_FLAGS="--timestamp"

say "Exporting"
cat > "$OUT/exportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>teamID</key><string>${TEAM_ID}</string>
    <key>signingStyle</key><string>manual</string>
    <key>signingCertificate</key><string>Developer ID Application</string>
    <key>destination</key><string>export</string>
</dict>
</plist>
PLIST

mkdir -p "$DIST"
xcodebuild -exportArchive \
  -archivePath "$OUT/Release.xcarchive" \
  -exportPath "$DIST" \
  -exportOptionsPlist "$OUT/exportOptions.plist" >/dev/null

# Sanity: the exported bundle must carry the version we think we shipped.
BUILT_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
[[ "$BUILT_VERSION" == "$VERSION" ]] \
  || { echo "!! built $BUILT_VERSION but expected $VERSION"; exit 1; }
echo "architectures: $(lipo -info "$APP/Contents/MacOS/$APP_NAME" | sed 's/.*: //')"

# ---------------------------------------------------------------- notarise ---
# Order matters: notarise the zipped app, staple the .app, then zip AGAIN so the
# ticket travels with the download. `ditto` is Apple's required packer — Finder
# compress or `zip -r` corrupts the signature.
say "Notarising (this waits on Apple, usually 1-3 min)"
cd "$DIST"
ditto -c -k --keepParent --sequesterRsrc "$APP_NAME.app" "$ZIP"

xcrun notarytool submit "$ZIP" \
  --key "$ASC_PRIVATE_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" \
  --wait

xcrun stapler staple "$APP_NAME.app"
xcrun stapler validate "$APP_NAME.app"
ditto -c -k --keepParent --sequesterRsrc "$APP_NAME.app" "$ZIP"
cd "$REPO_ROOT"

# ------------------------------------------------------------------ verify ---
# Simulate a first-time download: quarantine it, then ask Gatekeeper.
# `codesign --verify` passing does NOT mean the app opens — it skips notarisation.
say "Gatekeeper check on a quarantined copy"
VERIFY_DIR="$OUT/gk-verify"
mkdir -p "$VERIFY_DIR"
ditto -x -k "$ZIP" "$VERIFY_DIR"
xattr -w com.apple.quarantine "0083;00000000;Safari;" "$VERIFY_DIR/$APP_NAME.app"
SPCTL_OUT="$(spctl -a -vvv -t exec "$VERIFY_DIR/$APP_NAME.app" 2>&1)"
echo "$SPCTL_OUT"
grep -q "source=Notarized Developer ID" <<<"$SPCTL_OUT" \
  || { echo "!! not notarised — refusing to publish"; exit 1; }

SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

# ----------------------------------------------------------------- publish ---
NOTES_FILE="changelog/${VERSION}.md"
if $DRY_RUN; then
  say "Dry run — stopping before publish"
else
  say "Publishing GitHub release v$VERSION"
  git tag -a "v$VERSION" -m "v$VERSION"
  git push origin "v$VERSION"
  if [[ -f "$NOTES_FILE" ]]; then
    gh release create "v$VERSION" "$ZIP" --title "v$VERSION" --notes-file "$NOTES_FILE"
  else
    gh release create "v$VERSION" "$ZIP" --title "v$VERSION" --generate-notes
  fi
fi

say "Done"
cat <<EOF
  zip     : $ZIP
  sha256  : $SHA

  Homebrew cask (foamzou/ITraffic-monitor-for-mac is in homebrew-cask):
    brew bump-cask-pr --version $VERSION itraffic
  That command recomputes the sha256 itself and opens the PR.
EOF
