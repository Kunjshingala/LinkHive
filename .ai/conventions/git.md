# Git Conventions — LinkHive

## Branch Strategy

- `main` — production-ready code
- `develop` — integration branch (merge features here first)
- `feature/<short-description>` — new features (`feature/link-storage`, `feature/home-ui`)
- `fix/<issue>` — bug fixes (`fix/auth-google-crash`)
- `chore/<task>` — non-user-facing changes (`chore/update-deps`, `chore/add-ai-context`)

---

## Commit Message Format

Use **Conventional Commits**:

```
<type>(<scope>): <short summary>

[optional body]
[optional footer]
```

**Types:**
- `feat` — new feature
- `fix` — bug fix
- `chore` — maintenance, tooling, config
- `refactor` — code restructure without behavior change
- `style` — formatting only
- `test` — adding/updating tests
- `docs` — documentation only

**Examples:**
```
feat(auth): add Google Sign-In support
fix(splash): delay navigation until Firebase ready
chore(deps): bump firebase_auth to latest
refactor(home): extract HomeBloc from HomeScreen
docs(ai): add .ai context directory
```

---

## PR Rules

- PRs must target `develop` (never directly to `main`)
- PR title must follow commit format
- Include a summary of what changed and why
- Run `fvm flutter analyze` and ensure zero issues before opening PR
