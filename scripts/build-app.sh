#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

# Do not inherit unrelated compiler search paths from the user's shell.
env -u LIBRARY_PATH swift build -c release --product CopyToTranslate
./scripts/build-icon.sh
app_bundle="$project_dir/build/CopyToTranslate.app"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp .build/release/CopyToTranslate "$app_bundle/Contents/MacOS/CopyToTranslate"
cp Resources/Info.plist "$app_bundle/Contents/Info.plist"
cp build/AppIcon.icns "$app_bundle/Contents/Resources/AppIcon.icns"
cp LICENSE "$app_bundle/Contents/Resources/LICENSE"
codesign --force --sign - "$app_bundle"
printf '\nBuilt %s\n' "$app_bundle"
