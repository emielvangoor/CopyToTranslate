#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

./scripts/build-app.sh
app_bundle="$project_dir/build/CopyToTranslate.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_bundle/Contents/Info.plist")"
architecture="$(lipo -archs "$app_bundle/Contents/MacOS/CopyToTranslate")"
if [[ "$architecture" != "arm64" ]]; then
    printf 'Releases currently support arm64 only; built architecture: %s\n' "$architecture" >&2
    exit 1
fi
plutil -lint "$app_bundle/Contents/Info.plist"
codesign --verify --strict "$app_bundle"

release_dir="$project_dir/build/release"
archive_name="CopyToTranslate-v${version}-macos-${architecture}.zip"
mkdir -p "$release_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_bundle" "$release_dir/$archive_name"

# Check that the downloadable archive preserves the runnable, signed bundle.
verification_dir="$(mktemp -d "${TMPDIR:-/tmp}/copytotranslate-release.XXXXXX")"
trap 'rm -rf "$verification_dir"' EXIT
ditto -x -k "$release_dir/$archive_name" "$verification_dir"
test -x "$verification_dir/CopyToTranslate.app/Contents/MacOS/CopyToTranslate"
codesign --verify --strict "$verification_dir/CopyToTranslate.app"
cmp "$app_bundle/Contents/MacOS/CopyToTranslate" "$verification_dir/CopyToTranslate.app/Contents/MacOS/CopyToTranslate"

cd "$release_dir"
shasum -a 256 "$archive_name" > "$archive_name.sha256"
shasum -a 256 -c "$archive_name.sha256"
printf '\nRelease archive: %s/%s\n' "$release_dir" "$archive_name"
