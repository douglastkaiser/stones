# stones
Stones: An Okay Game

## Local tooling

To enable `dart format` and `flutter format` in a fresh Debian/Ubuntu-like environment, add the following steps to your setup script (requires sudo):

```bash
set -euo pipefail

# Base packages
sudo apt-get update
sudo apt-get install -y curl git unzip xz-utils apt-transport-https

# Dart (adds Google APT repository and installs dart command)
sudo install -d /usr/share/keyrings
curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub \
  | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
echo "deb [signed-by=/usr/share/keyrings/dart.gpg] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main" \
  | sudo tee /etc/apt/sources.list.d/dart_stable.list
sudo apt-get update
sudo apt-get install -y dart

# Flutter SDK
sudo git clone --depth 1 https://github.com/flutter/flutter.git /opt/flutter
export PATH="/opt/flutter/bin:$PATH"
flutter precache
flutter --version
```

> If you want the Flutter SDK permanently on your PATH, append `export PATH="/opt/flutter/bin:$PATH"` to your shell profile.
