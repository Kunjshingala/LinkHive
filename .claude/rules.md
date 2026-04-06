# Claude Rules Index

> Hard boundaries. Read the relevant rule file(s) before every task.

| Rule File | When to Read | Scope |
|---|---|---|
| `rules/workflow.md` | Every task | FVM, read-before-write, git, analyze, scope, l10n, secrets |
| `rules/code-patterns.md` | Creating or modifying Dart code | BLoC pattern, screen structure, Neo-Brutalism, navigation, DI |
| `rules/naming.md` | Creating new files, classes, or routes | File names, class suffixes, method names, folder structure |

## Quick Reminders (Always Apply)

1. **`fvm flutter` / `fvm dart` only** — never bare `flutter` or `dart` commands
2. **Read files before editing them** — never assume contents
3. **Never use `setState` for business logic** — use BLoC events
4. **Never use `showDialog`/`AlertDialog`** — use `showConfirmationBottomSheet` or `showOptionsBottomSheet`
5. **Never hardcode colors/spacing** — always use `AppColors.*` and `AppSpacing.*`
6. **Never use `Navigator.push`** — use `context.goNamed(MyRouteName.xxx)`
7. **Run `fvm flutter analyze` before declaring done** — zero warnings required
8. **No hardcoded user-facing strings** — add to ARB files, access via `context.l10n.*`
