#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$project_dir/dist/PreviewMD.app"
contents_dir="$app_dir/Contents"
build_dir="$project_dir/.build/apple/Products/Release"
iconset_dir="$project_dir/.build/AppIcon.iconset"
master_icon="$project_dir/.build/AppIcon-1024.png"
signing_identity="${PREVIEWMD_SIGNING_IDENTITY:-}"

cd "$project_dir"

export SDKROOT="${PREVIEWMD_SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/ModuleCache"

swift build \
  -c release \
  --arch arm64 \
  --arch x86_64 \
  --disable-sandbox

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"

cp "$build_dir/PreviewMD" "$contents_dir/MacOS/PreviewMD"
cp -R "$build_dir/PreviewMD_PreviewMD.bundle" "$contents_dir/Resources/PreviewMD_PreviewMD.bundle"

cp "scripts/Info.plist" "$contents_dir/Info.plist"

rm -rf "$iconset_dir"
mkdir -p "$iconset_dir"
swift "scripts/render-icon.swift" "$master_icon"
for size in 16 32 128 256 512; do
  double_size=$((size * 2))
  sips -z "$size" "$size" "$master_icon" --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
  sips -z "$double_size" "$double_size" "$master_icon" --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done
swift "scripts/build-icns.swift" "$iconset_dir" "$contents_dir/Resources/AppIcon.icns"

chmod +x "$contents_dir/MacOS/PreviewMD"

if [[ -n "$signing_identity" ]]; then
  codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$signing_identity" \
    "$app_dir"
  echo "Built and signed $app_dir"
else
  codesign --force --sign - "$app_dir"
  echo "Built $app_dir with an ad-hoc signature"
fi
