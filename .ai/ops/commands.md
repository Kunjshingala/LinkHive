# Commands — LinkHive

> **All commands must be prefixed with `fvm`.** This project uses FVM to pin a specific Flutter version.

---

## Development

```bash
# Run the app (debug mode, select a device)
fvm flutter run

# Run on a specific device
fvm flutter run -d <device_id>

# List available devices
fvm flutter devices
```

---

## Code Quality

```bash
# Analyze for lint errors and warnings (must be zero before committing)
fvm flutter analyze

# Auto-format all Dart files (style: analysis_options.yaml formatter block)
fvm dart format lib test

# Check formatting without applying (must report 0 changed before done)
fvm dart format --output=none --set-exit-if-changed lib test

# One-time setup per clone: format check on commit, blame skips format commits
git config core.hooksPath .githooks
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

---

## Testing

```bash
# Run all tests
fvm flutter test

# Run a specific test file
fvm flutter test test/features/authentication/auth_bloc_test.dart

# Run tests with coverage
fvm flutter test --coverage
```

---

## Build

```bash
# Build Android APK (debug)
fvm flutter build apk --debug

# Build Android APK (release)
fvm flutter build apk --release

# Build iOS (release, macOS only)
fvm flutter build ipa
```

---

## Dependencies

```bash
# Get packages
fvm flutter pub get

# Upgrade packages
fvm flutter pub upgrade

# Check for outdated packages
fvm flutter pub outdated
```

---

## Firebase

```bash
# Regenerate firebase_options.dart (requires FlutterFire CLI)
flutterfire configure
```
