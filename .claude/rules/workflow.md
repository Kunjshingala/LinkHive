# Workflow Rules

> Apply these rules to EVERY task without exception.

## 1. FVM Required

**Always prefix Flutter/Dart commands with `fvm`.**

```bash
# Correct
fvm flutter run
fvm flutter analyze
fvm flutter pub get
fvm dart format lib test
fvm dart run build_runner build --delete-conflicting-outputs

# NEVER use bare commands
flutter run        # ❌
dart format lib/   # ❌
```

## 2. Read Before Edit

- Read every file you plan to modify before touching it.
- Read the files that will be affected by your change (e.g., if adding a route, read `route.dart` first).
- Never assume file contents — always verify.

## 3. Verify After Changes

Run this before declaring any code task done:

```bash
fvm flutter analyze
fvm dart format --output=none --set-exit-if-changed lib test
```

Zero errors, zero warnings, and zero files the formatter would change. Fix every issue before finishing.

For localization changes:

```bash
fvm flutter gen-l10n
```

For Hive model changes (after editing `@HiveType` / `@HiveField`):

```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format lib
```

### Code format

One style for every IDE and the command line:

- Dart: `formatter: page_width: 120` in `analysis_options.yaml`; trailing commas are managed by the formatter. VS Code and Android Studio read this file; do not set `dart.lineLength`.
- Line endings: LF everywhere (`.gitattributes`). Indentation and final newlines: `.editorconfig`.
- Format with `fvm dart format lib test` (whole folders are fine: the repo is formatted). Generated l10n output is formatted by `gen-l10n` (`format: true`); run `fvm dart format lib` after `build_runner`.
- Enable the pre-commit hook once per clone: `git config core.hooksPath .githooks`. It refuses a commit with unformatted staged Dart files.
- `.git-blame-ignore-revs` lists format-only commits; enable it locally with `git config blame.ignoreRevsFile .git-blame-ignore-revs`. Add any future format-only commit to it.

## 4. Git Discipline

- **Never push** without explicit user approval.
- **Never force-push** under any circumstances.
- **Never commit** to `main` or `dev` directly. Work on its own branch, merged only after analyze and tests pass and the user approves.
- Stage specific files — avoid `git add .` which can include sensitive files.
- Check `git status` before staging.

### Branch model

Two long-lived branches, `main` and `dev`, kept in sync with each other.

- Every piece of work (feature, fix, docs, chore) gets its own branch, **cut from `dev`** and **merged back into `dev`**.
- Only `dev` merges into `main`. Never cut a work branch from `main` or merge one into it.
- A batch of bug fixes may share one branch (for example `fix/issues`), with one commit per fix.
- Check `git branch --show-current` before the first edit. If it is `main` or `dev`, create a work branch first.
- `release` (the landing page, in its own worktree) is separate from this model. Leave it alone unless asked.

## 5. Scope Control

- Only change what was asked for.
- Do not refactor surrounding code, rename variables, or clean up unrelated files.
- Do not add features, error handling, or comments beyond what is needed.
- If you spot an unrelated issue, mention it — don't fix it silently.

## 6. Localization — No Hardcoded Strings

Every user-facing string must be in an ARB file, not hardcoded.

```dart
// ❌ Never
Text('No links yet')

// ✅ Always
Text(context.l10n.homeEmptyStateTitle)
```

Add new keys to `lib/l10n/app_en.arb` (and the other ARB files), then run `fvm flutter gen-l10n`.

## 7. No Secrets in Source

- Never commit `google-services.json`, `GoogleService-Info.plist`, API keys, or Firebase config values.
- `firebase_options.dart` is auto-generated — never edit manually.
- Regenerate with: `flutterfire configure`

## 8. When Uncertain

Ask before touching:
- `lib/core/utils/locator.dart` — DI wiring affects the whole app
- `lib/core/utils/navigation/route.dart` — routing affects all navigation
- `android/app/build.gradle.kts` — build config changes
- Any file in `ios/` — always check before editing
- `firebase_options.dart` — never edit manually
