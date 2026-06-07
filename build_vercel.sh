#!/bin/bash
set -e

echo "=== Installing Flutter SDK ==="
git clone https://github.com/flutter/flutter.git --depth 1 -b stable /opt/flutter
export PATH="$PATH:/opt/flutter/bin"

echo "=== Flutter Doctor ==="
flutter doctor --android-licenses || true
flutter doctor

echo "=== Installing Dependencies ==="
flutter pub get

echo "=== Building Flutter Web ==="
flutter build web --release --base-href /

echo "=== Build Complete ==="
ls -la build/web/
