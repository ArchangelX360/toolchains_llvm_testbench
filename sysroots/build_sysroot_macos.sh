#!/bin/zsh
set -exuo pipefail

# Credits to https://github.com/salesforce-misc/bazel-cpp-toolchain

OUTPUT_DIRECTORY="$(dirname "$0")"
TMP_DIRECTORY="$OUTPUT_DIRECTORY/tmp"
rm -rf "$TMP_DIRECTORY"
mkdir -p "$TMP_DIRECTORY"

MACOS_SDK_VERSION="15.5"
MACOS_SDK_ARCHIVE="$TMP_DIRECTORY/macos_sdk.tar.xz"
curl -L "https://github.com/alexey-lysiuk/macos-sdk/releases/download/$MACOS_SDK_VERSION/MacOSX$MACOS_SDK_VERSION.tar.xz" --output "$MACOS_SDK_ARCHIVE"

echo "Extracting MacOS SDK..."
EXTRACTED_SDK_PATH="$TMP_DIRECTORY/extracted"
mkdir -p "$EXTRACTED_SDK_PATH"

# Reason for filtering:
# - '*:*' -> excluding files containing `:`, unsupported at runtime by Bazel, and unsupported at extraction on Windows
# - 'usr/share/man' -> size optimization, removing manual pages
# - 'System/Library/Frameworks/Ruby.framework/Versions/2.6/Headers/ruby/ruby' -> cyclic symlink confuses Bazel
tar xf "$MACOS_SDK_ARCHIVE" -C "$EXTRACTED_SDK_PATH" \
  --exclude='*:*' \
  --exclude='usr/share/man' \
  --exclude='System/Library/Frameworks/Ruby.framework/Versions/2.6/Headers/ruby/ruby'

# echo "Locating xcode..."
# XCODE_LOCATION=$(xcode-select -p || exit 1)
# echo "Picking XCode libraries and headers..."
# cp -r "$XCODE_LOCATION/Toolchains/XcodeDefault.xctoolchain/usr" "$OUTPUT_DIRECTORY"

echo "Packing sysroot archive..."
mkdir -p "$OUTPUT_DIRECTORY"
SCRIPT_VERSION=$(md5sum "$0" | cut -d" " -f1)
ARCHIVE="$OUTPUT_DIRECTORY/sysroot-macos-SDK_$MACOS_SDK_VERSION-$SCRIPT_VERSION.tar.gz"
rm -rf "$ARCHIVE"
# Using -h to make the archive Windows-compatible by dereferencing symlinks
tar czvhf "$ARCHIVE" -C "$EXTRACTED_SDK_PATH/MacOSX$MACOS_SDK_VERSION.sdk" .
ARTEFACT="$(realpath "$ARCHIVE")"

echo "Cleaning up..."
rm -rf "$TMP_DIRECTORY"
