#!/bin/sh
set -eu

PROJECT_FILE="FeedBacks!.xcodeproj/project.pbxproj"

if [ ! -f "$PROJECT_FILE" ]; then
  echo "Missing project file: $PROJECT_FILE"
  exit 1
fi

echo "Patching embedded Python signing in Xcode project..."

/usr/bin/sed -i '' \
  's|codesign --force --sign \"$EXPANDED_CODE_SIGN_IDENTITY\" --timestamp=none|codesign --force --sign \"$EXPANDED_CODE_SIGN_IDENTITY\" --entitlements \"$SRCROOT/FeedBacksApp/FeedBacks.entitlements\" --options runtime --timestamp=none|g' \
  "$PROJECT_FILE"

if ! /usr/bin/grep -q -- '--entitlements' "$PROJECT_FILE"; then
  echo "Failed to patch embedded Python codesign command"
  exit 1
fi

echo "Embedded Python signing patch applied for Xcode Cloud"
