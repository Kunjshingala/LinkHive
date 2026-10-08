# TODOS

## Docs

### Refresh stale roadmap and context docs

**What:** Update `docs/feature-roadmap.md`, `docs/existing-feature-polish.md`, and `.ai/context/project.md` to match the code that's actually built.

**Why:** AI agents and future-you read these first. Right now they say built features are missing, which leads to wrong starting context and re-proposing things that already exist.

**Context:** Found during the 2026-10-06 office-hours / eng review of `docs/designs/smart-duplicate-merge.md`.
- `feature-roadmap.md` (last_updated 2026-07-28) lists these as `Planned`, though all are built: Open in browser / Copy URL / Share URL (`url_launcher` and `share_plus` are in `pubspec.yaml`), Daily Digest (built as the 9am resurface notification), and Home Screen Widget (Android Glance widget).
- `existing-feature-polish.md` lists C1–C4 as open. URL validation now lives in `lib/core/utils/validator/validator.dart` (`normalizeUrl`), and opening and sharing links work.
- `.ai/context/project.md` says "link storage and display features are not yet implemented".
- `docs/product-direction-return-engine.md` is the accurate record of what shipped through 2026-09-27.

**Effort:** S
**Priority:** P2
**Depends on:** None

## Links

### Icon-quality follow-up: fewer letter avatars on link cards

**What:** Find out why some link cards still show a letter avatar, and prefer `<link rel="apple-touch-icon">` (largest `sizes`) in `_extractIcon`.

**Why:** Cards with a letter avatar instead of the site's logo are harder to scan on Home, Inbox and Today.

**Context:** This was split out of the smart-duplicate-merge build by eng review D4 (`docs/designs/smart-duplicate-merge.md`). A favicon fallback already exists: `lib/core/services/metadata/link_metadata_service.dart` tries `og:image`, then `twitter:image`, then `_extractIcon` (rel `icon`/`shortcut` only), then `_defaultFaviconUrl` (`/favicon.ico`). That last step always returns a URL when a fetch succeeds, so an empty `image` means the page fetch itself failed. Start by listing links that render the letter avatar and sorting them by cause:
- metadata fetch failed or hit a login wall (Instagram/LinkedIn)
- `favicon.ico` returned 404 or couldn't be decoded (`LinkCard`'s `errorWidget` fallback)
- the only icon is an SVG, which `LinkCard` filters out
- a legacy link that was never enriched

Fix only the causes the diagnosis actually finds.

**Effort:** S
**Priority:** P3
**Depends on:** None

## Design

### Adopt the Anek + Readex Pro typeface in the app

**What:** Bundle font subsets for Anek Latin, Anek Devanagari, Anek Gujarati and Readex Pro (Arabic), then wire them into `AppTypography` / `AppTheme` for all four locales (en, hi, gu, ar).

**Why:** The app renders in the platform default font today, so Hindi and Gujarati look like fallback text. `DESIGN.md` records Anek + Readex Pro as the target.

**Context:** Both families are on Google Fonts under the OFL license (verified 2026-10-07). Anek has a width axis: condensed for titles and numbers, normal for reading. Bundle subsets to limit APK size, and re-test every screen at 1.3x text scale in hi, gu and ar.

**Effort:** M
**Priority:** P3
**Depends on:** None

## Completed
