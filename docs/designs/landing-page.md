# LinkHive landing page and Product Hunt kit: plan

**Date:** 2026-10-09
**Status:** Plan, waiting for approval. Nothing is built or hosted yet.
**Preview:** `docs/designs/preview/landing-page-preview.html` (open it in a browser; hero options and dark mode can be switched at the top)

## Goal

One public page that does three jobs:

1. **Portfolio / resume link.** A recruiter opens it, understands the app in 10 seconds, sees real screens, and can jump to the code.
2. **Product page.** Someone who saves links from Instagram or YouTube understands why LinkHive is different (it brings links back) and can install it.
3. **Product Hunt landing URL.** The page the Product Hunt listing points to, with the same story and visuals as the gallery images.

Success check: a stranger can answer "what does it do, why is it different, how do I get it, where is the code" without scrolling past the third section.

## Positioning (one message everywhere)

> **You saved it. LinkHive brings it back.**

Every app has a save button, and none of them give the link back. LinkHive is the one place you share links to, and once a day it puts one back in front of you. This is the "return engine" idea from `docs/product-direction-return-engine.md`. Capture is not the selling point; return is.

Supporting points, in order of importance:

1. One-tap capture from any app's share sheet. No form.
2. Daily resurface: one link a day (9am notification, Today tab, home screen widget).
3. Saves the same link twice? It merges and shows "Saved 2×", a sign you really want it.
4. Find anything: search plus Source / Category / quick filters, built for hundreds of links.
5. Offline-first: works with no account and no network, syncs when signed in.
6. English, Hindi, Gujarati and Arabic (right-to-left).

## Visual direction

The page uses the app's own design system (DESIGN.md), so the site and the screenshots look like one product:

- Background `brand-background` #ECE2D5, white cards, 2px ink outlines, hard pastel shadows at (4, 4) with zero blur.
- Anek Latin, self-hosted from `assets/fonts/` (already bundled, OFL license). No Google Fonts request on the live site.
- Purple `return` (#F4EBFF) only for "came back" moments (Saved 2×, the Today pick), same rule as the app.
- Pill buttons 52px tall; primary = ink fill, secondary = white.
- Light by default, dark follows the system, with a toggle.
- No gradients, glows, blur, stock photos or emoji decoration.

## Page structure

| # | Section | Content | Visual |
|---|---|---|---|
| 0 | Top bar | Logo + "LinkHive", links: How it works, Features, Under the hood, GitHub button | Sticky white bar, 2px bottom rule |
| 1 | Hero | Headline, one-line subhead, 2 CTAs (Get the app, View code on GitHub), fact row (Free · Offline-first · Android + iOS · 4 languages) | Option A: split, phone on the right. Option B: centred, three phones below. See preview |
| 2 | The problem | "Every app has a save button. None of them give it back." Three "graveyard" cards: Instagram saves, LinkedIn saves, WhatsApp-to-self | Three white cards with crossed-out counters |
| 3 | How it works | 3 steps: Share → Saved instantly to Inbox → Comes back in Today | Numbered lemon badges, small phone crops |
| 4 | Features | 6 cards: one-tap capture, daily resurface, Saved 2× merge, find anything, offline-first sync, 4 languages + widget | 3×2 grid, one pastel shadow per card |
| 5 | Screens | Horizontal strip of real screenshots: Links, Today, Inbox, Add link, Widget, Dark mode | Phone frames, scroll-snap on mobile |
| 6 | Use cases | Recipes from Reels, trip planning, shopping wishlist, courses and talks, job posts, articles to read later | 6 small cards with an example link |
| 7 | Under the hood | For engineers and recruiters: architecture diagram (share intent → Hive → outbox → Firestore, conflict screen), tech chips, 4 engineering highlights, "Read the code" CTA | Simple boxed diagram in ink outlines |
| 8 | Built by | Photo or initials, two lines of bio, GitHub / LinkedIn / portfolio / email links | One card |
| 9 | Final CTA + footer | "Stop losing links." + the two CTAs; footer: license, privacy note, © | Ink band |

Mobile: single column, 16px side gutter, screens strip scrolls horizontally, hero phone drops below the copy.

## Copy draft

**Hero**
- Headline: *You saved it. LinkHive brings it back.*
- Subhead: *Share a link from Instagram, YouTube, LinkedIn or any app. LinkHive saves it in one tap, then brings one back each morning, so your saves stop piling up unread.*
- CTAs: **Download for Android** (APK on GitHub Releases) · **View code on GitHub**
- Facts: Free · Works offline · No account needed · English, हिन्दी, ગુજરાતી, العربية

**Problem:** *Every app has a save button. None of them give it back.* Instagram saves, LinkedIn saves, the chat you send to yourself: links go in and never come out.

**How it works**
1. **Share it.** Tap Share in any app and pick LinkHive. It's saved. No form.
2. **Forget it.** It waits in your Inbox. Add a category later, or never.
3. **Get it back.** Every morning LinkHive picks one link for you. Open it, snooze it, or archive it.

**Features**
- **One-tap capture.** Saving takes the same tap as any share. Title and preview fill in afterwards.
- **One link a day.** A 9am reminder, a Today screen and a home screen widget bring back one link at a time.
- **Saved twice? Noted.** Share the same link again and LinkHive merges it and marks it Saved 2×.
- **Find anything.** Search, quick filters and Source / Category / Sort, built for hundreds of links.
- **Offline first.** Works without an account or a connection. Sign in and it syncs, with a screen to settle conflicts.
- **Speaks your language.** English, Hindi, Gujarati and Arabic, right-to-left included. Light and dark.

**Use cases:** recipes from Reels · a trip you're planning · things to buy later · talks and courses · job posts · long reads.

**Under the hood highlights**
- Offline-first: every write goes to Hive first; an outbox queue replays to Firestore on reconnect or sign-in.
- Field-level conflict detection with keep-local / keep-cloud / merge.
- One `LinkManager` for every action, so Today, cards and the widget behave the same.
- Native Android widget in Jetpack Glance; share target on Android and iOS; 4 locales with RTL.
- Stack: Flutter · BLoC · Hive · Firebase Auth + Firestore · go_router · get_it.

## Screenshots

The preview uses HTML mockups. The live page needs real screenshots:

1. Fresh install as a guest, fill it with ~30 demo links from public pages (recipes, travel, talks, shops). **No personal links, no email on screen.**
2. Capture on a phone with `adb exec-out screencap -p > file.png`: Links, Today, Inbox, Add link with the suggestion box, the "Already saved" bar, the widget, and Links in dark mode. One shot in Hindi or Arabic.
3. Save to `website/assets/screens/` as WebP (about 100 to 150 KB each) with PNG kept for Product Hunt.
4. Optional: a 15 to 20 second screen recording of Share → Saved → Today for the hero and the Product Hunt gallery (`adb shell screenrecord`).

## Product Hunt kit

| Field | Draft | Limit |
|---|---|---|
| Name | LinkHive | |
| Tagline | The link saver that brings your links back | 60 chars (42 used) |
| Description | Save links from any app in one tap. LinkHive puts one back in front of you every day, so saves from Instagram, YouTube and LinkedIn don't die in a pile. Offline-first, in 4 languages, and the code is on GitHub. | 260 chars |
| Topics | Productivity, Android, Bookmarks (Open Source once licensed) | up to 4 |
| Links | Landing page URL, GitHub repo, Play Store or APK | |
| Thumbnail | Logo hexagon on lemon, ink outline (240×240; GIF allowed) | |
| Gallery | 6 slides at 1270×760 (see below) | |
| Maker comment | Draft in the preview | |

Gallery slides (built as HTML, exported to PNG):

1. **Hero:** "You saved it. LinkHive brings it back." + Today screen.
2. **Share in one tap:** share sheet → "Link saved" bar.
3. **One link a day:** notification + Today card + widget.
4. **Saved 2×:** the merge bar and the Saved 2× chip.
5. **Find anything:** Links tab with filters applied.
6. **Offline, 4 languages, code on GitHub:** three phones (Hindi, Arabic RTL, dark) + GitHub link.

Launch checklist (later, after the page is live):
- The install link works for anyone (Play Store listing or a signed APK on GitHub Releases).
- Repo is public, has a license and a README that matches the page.
- Launch at 12:01am Pacific time on a Tuesday to Thursday; post the maker comment straight away.
- Check current Product Hunt limits and image sizes on launch day; they change.

## Build and hosting plan (after approval)

- **Code:** plain static HTML + CSS + a few lines of JS in a new `website/` folder. No framework, no build step. Fonts and images are local.
- **Hosting:** Vercel, see "Deploy on Vercel" above.
- **SEO and sharing:** title, description, Open Graph and Twitter card image (1200×630, same art as gallery slide 1), favicon from the app icon.
- **Analytics:** none by default. If wanted, a cookie-free option (GoatCounter or Cloudflare Web Analytics).
- **Quality bar:** Lighthouse 95+ on performance and accessibility, works at 360px wide, keyboard focus visible, `alt` on every screenshot.

## Decisions (2026-10-09)

1. Hero: **Option A (split)**.
2. Install link: **APK on GitHub Releases** (`/releases/latest`). iOS is "builds from source".
3. Repo: **public**. The LICENSE is all rights reserved, so the page says "the code is on GitHub" rather than "open source".
4. Hosting: **Vercel (Hobby, free)**. Chosen over GitHub Pages for the cleaner URL and a preview link per branch, and over Firebase because Firebase's free plan caps transfer at 360 MB a day.
5. "Built by": bio, portfolio, GitHub, LinkedIn, X and email, taken from `github.com/Kunjshingala/about` (`lib/core/constants/info.dart`).

## What's in the repo

| Path | What |
|---|---|
| `website/index.html` | The page. Phone mockups are `<template>`s cloned by `assets/js/main.js` |
| `website/assets/` | CSS, JS, fonts (OFL licenses alongside), favicon, `og.png` (1200×630), `apple-touch-icon.png` |
| `website/vercel.json` | Security headers; fonts cached for a year, CSS / JS / images for a day |
| `docs/product-hunt/` | `gallery-1..6.png` (1270×760), `thumbnail.png` (240×240), `export.sh` |
| `docs/designs/preview/landing-page-preview.html` | Approved preview and the source of the Product Hunt images |

Re-export the Product Hunt images and `og.png` after changing the preview: `bash docs/product-hunt/export.sh`.

## Deploy on Vercel (one-time setup, done by Kunj)

1. Sign in at vercel.com with GitHub. **Add New → Project →** import `Kunjshingala/LinkHive`.
2. Project name `linkhive`; `linkhive.vercel.app` was taken, so the live domain is `get-linkhive.vercel.app`. **Root Directory:** `website`. **Framework Preset:** Other. Leave Build Command and Output Directory empty.
3. Deploy. Production follows `main`; every other branch gets its own preview URL.
4. Done for `get-linkhive.vercel.app`: the canonical, `og:url`, `og:image` and `twitter:image` lines at the top of `website/index.html`.
5. Check the link preview with any card validator, then add the URL to the GitHub repo's "Website" field and to the README.

## Still to do before Product Hunt

- **Release APK.** "Download for Android" points to `/releases/latest`, which is empty until a signed release APK is published there.
- **Real screenshots.** The screens are HTML mockups. Capture them from a phone with demo links (no personal data), then swap each mockup for an `<img>` and re-run the export.
- **License.** The repo is public with an all-rights-reserved LICENSE (decided 2026-10-11; may be opened up after development), so the page says "the code is on GitHub" rather than "open source". With an MIT license, the "Open Source" topic and wording can come back.
- **Font weight.** About 1.2 MB of TTF fonts load on a first visit. Converting to subset WOFF2 would roughly halve it.
