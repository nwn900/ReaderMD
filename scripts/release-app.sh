#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$project_dir/dist/PreviewMD.app"
info_plist="$project_dir/scripts/Info.plist"
signing_identity="${PREVIEWMD_SIGNING_IDENTITY:-Developer ID Application: Astrography Sp. z o.o. (4NZF9USX28)}"
notary_profile="${PREVIEWMD_NOTARY_PROFILE:-PreviewMD-Notary}"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist")"
notary_archive="$project_dir/dist/PreviewMD-$version-$build_number-notarization.zip"
release_archive="$project_dir/dist/PreviewMD-$version-$build_number-macOS.zip"

cd "$project_dir"

if ! security find-identity -v -p codesigning | grep -Fq "\"$signing_identity\""; then
  echo "Missing signing identity: $signing_identity" >&2
  exit 1
fi

PREVIEWMD_SIGNING_IDENTITY="$signing_identity" "$project_dir/scripts/build-app.sh"

codesign --verify --deep --strict --verbose=2 "$app_dir"
codesign --display --verbose=2 "$app_dir"

rm -f "$notary_archive" "$release_archive"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$notary_archive"

xcrun notarytool submit \
  "$notary_archive" \
  --keychain-profile "$notary_profile" \
  --wait

xcrun stapler staple "$app_dir"
xcrun stapler validate "$app_dir"
spctl --assess --type execute --verbose=4 "$app_dir"

ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$release_archive"

echo "Release ready: $release_archive"
