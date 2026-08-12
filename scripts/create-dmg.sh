#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="${1:-$project_dir/dist/ReaderMD.app}"
info_plist="$app_dir/Contents/Info.plist"

if [[ ! -d "$app_dir" || ! -f "$info_plist" ]]; then
  echo "Missing application bundle: $app_dir" >&2
  exit 1
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist")"
output_dmg="${2:-$project_dir/dist/ReaderMD-$version-$build_number-macOS.dmg}"
output_dir="$(dirname "$output_dmg")"
app_filename="$(basename "$app_dir")"
volume_name="ReaderMD $version ($build_number)"

mkdir -p "$project_dir/.build" "$output_dir"
work_dir="$(mktemp -d "$project_dir/.build/dmg.XXXXXX")"
staging_dir="$work_dir/staging"
rw_dmg="$work_dir/ReaderMD-rw.dmg"
mount_dir=""

cleanup() {
  if [[ -n "$mount_dir" && -d "$mount_dir" ]]; then
    hdiutil detach "$mount_dir" -quiet >/dev/null 2>&1 || true
  fi
  if [[ "$work_dir" == "$project_dir/.build/dmg."* ]]; then
    rm -rf "$work_dir"
  fi
}
trap cleanup EXIT INT TERM

mkdir -p "$staging_dir/.background"
ditto "$app_dir" "$staging_dir/$app_filename"
ln -s /Applications "$staging_dir/Applications"

export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/ModuleCache"
swift "$project_dir/scripts/render-dmg-background.swift" \
  "$staging_dir/.background/background.png" \
  "$staging_dir/.background/background@2x.png"

payload_kb="$(du -sk "$staging_dir" | awk '{print $1}')"
image_size_mb=$(( (payload_kb + 1023) / 1024 + 32 ))
if (( image_size_mb < 64 )); then
  image_size_mb=64
fi

hdiutil create \
  -ov \
  -volname "$volume_name" \
  -fs HFS+ \
  -size "${image_size_mb}m" \
  "$rw_dmg"

if [[ -e "/Volumes/$volume_name" ]]; then
  echo "A volume named '$volume_name' is already mounted. Eject it and retry." >&2
  exit 1
fi

attach_output="$(hdiutil attach -readwrite -noverify -noautoopen "$rw_dmg")"
mount_dir="$(print -r -- "$attach_output" | sed -n 's|^.*\t\(/Volumes/.*\)$|\1|p' | tail -1)"
if [[ -z "$mount_dir" || ! -d "$mount_dir" ]]; then
  echo "Could not determine the mounted DMG path." >&2
  exit 1
fi

ditto "$staging_dir" "$mount_dir"
touch "$mount_dir/.metadata_never_index"
mkdir -p "$mount_dir/.fseventsd"
touch "$mount_dir/.fseventsd/no_log"
osascript "$project_dir/scripts/layout-dmg.applescript" "$volume_name" "$app_filename"

if [[ ! -f "$mount_dir/.DS_Store" ]]; then
  echo "Finder did not create the DMG layout metadata." >&2
  exit 1
fi

sync
hdiutil detach "$mount_dir" -quiet
mount_dir=""

hdiutil convert \
  "$rw_dmg" \
  -quiet \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$output_dmg"
hdiutil verify -quiet "$output_dmg"

echo "DMG ready: $output_dmg"
