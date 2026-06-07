#!/bin/bash
set -e

echo "=== Installing Flutter SDK ==="
if [ ! -d "/opt/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable /opt/flutter
fi

export PATH="$PATH:/opt/flutter/bin"

echo "=== Flutter Version ==="
flutter --version

echo "=== Accepting Licenses ==="
yes | flutter doctor --android-licenses || true

echo "=== Installing Dependencies ==="
flutter pub get

echo "=== Building Flutter Web ==="
flutter build web --release --base-href /

echo "=== Build Complete ==="
ls -la build/web/
