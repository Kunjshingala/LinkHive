git reset HEAD

git add android/ ios/ macos/ windows/ assets/ firebase.json pubspec.yaml pubspec.lock l10n.yaml test/
git commit -m "chore: setup native configs, assets, tests, and update dependencies"

git add lib/l10n/ untranslated_messages.txt
git commit -m "feat(l10n): add localization support with multiple languages"

git add lib/core/ lib/utils/ lib/receiveIntent/
git commit -m "feat(core): setup core infrastructure, services, themes, and utilities"

git add lib/sharedWidgets/
git commit -m "feat(ui): add shared UI components and widgets"

git add lib/features/authentication/ lib/features/login/
git commit -m "feat(auth): implement authentication and login feature"

git add lib/features/splash/
git commit -m "feat(splash): implement splash functionality"

git add lib/features/account/ lib/screen/account/
git commit -m "feat(account): implement and migrate account feature"

git add lib/features/home/ lib/screen/home/
git commit -m "feat(home): implement and migrate home feature"

git add lib/features/links/
git commit -m "feat(links): implement links management feature"

git add lib/main.dart lib/my_app.dart
git commit -m "feat(app): configure app entry point"

git add -A
git commit -m "chore: miscellaneous cleanup and remaining updates"

git push
