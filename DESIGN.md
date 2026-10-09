---
# gstack: design-md-format=spec
name: LinkHive
description: Neo-Brutalist link keeper that brings saved links back. Heavy ink outlines, hard pastel shadows, no blur.
colors:
  ink: "#1E1E1E"
  surface: "#FFFFFF"
  surface-muted: "#F3F4F6"
  text: "#1E1E1E"
  text-secondary: "#4B5563"
  text-tertiary: "#9CA3AF"
  border: "#1E1E1E"
  brand-background: "#ECE2D5"
  return: "#F4EBFF"
  accent-green: "#D1FADF"
  accent-orange: "#FEF0C7"
  accent-blue: "#D1E9FF"
  shadow-mint: "#B5E4CA"
  shadow-peach: "#FFDAB9"
  shadow-sky: "#BBE4FB"
  shadow-rose: "#FFD1DC"
  shadow-lemon: "#FDF0A6"
  success: "#22C55E"
  warning: "#F59E0B"
  error: "#EF4444"
  dark-background: "#121212"
  dark-surface: "#1E1E1E"
  dark-surface-muted: "#2C2C2C"
  dark-text: "#E5E7EB"
  dark-text-secondary: "#A3A3A3"
  dark-text-tertiary: "#737373"
  dark-border: "#E5E7EB"
typography:
  display:
    fontFamily: Anek Latin
    fontWeight: 800
    fontSize: 34px
    lineHeight: 1.1
    letterSpacing: -1px
  headline-lg:
    fontFamily: Anek Latin
    fontWeight: 800
    fontSize: 28px
    lineHeight: 1.2
    letterSpacing: -0.8px
  headline-md:
    fontFamily: Anek Latin
    fontWeight: 700
    fontSize: 22px
    lineHeight: 1.25
    letterSpacing: -0.5px
  title-lg:
    fontFamily: Anek Latin
    fontWeight: 700
    fontSize: 20px
    lineHeight: 1.3
    letterSpacing: -0.3px
  title-md:
    fontFamily: Anek Latin
    fontWeight: 700
    fontSize: 18px
    lineHeight: 1.35
    letterSpacing: -0.2px
  title-sm:
    fontFamily: Anek Latin
    fontWeight: 700
    fontSize: 16px
    lineHeight: 1.4
    letterSpacing: -0.1px
  body:
    fontFamily: Anek Latin
    fontWeight: 500
    fontSize: 15px
    lineHeight: 1.5
  label:
    fontFamily: Anek Latin
    fontWeight: 600
    fontSize: 13px
    lineHeight: 1.4
    letterSpacing: 0.2px
  caption:
    fontFamily: Anek Latin
    fontWeight: 700
    fontSize: 11px
    lineHeight: 1.4
    letterSpacing: 0.5px
rounded:
  sm: 8px
  md: 12px
  lg: 16px
  xl: 20px
  full: 100px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  xxl: 48px
  page: 20px
components:
  button:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.full}"
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.surface}"
    rounded: "{rounded.full}"
  card:
    backgroundColor: "{colors.surface}"
    borderColor: "{colors.border}"
    rounded: "{rounded.lg}"
  today-card:
    backgroundColor: "{colors.surface}"
    borderColor: "{colors.border}"
    rounded: "{rounded.xl}"
  return-chip:
    backgroundColor: "{colors.return}"
    textColor: "{colors.ink}"
    rounded: "{rounded.full}"
  bottom-sheet:
    backgroundColor: "{colors.surface}"
    borderColor: "{colors.border}"
    rounded: "{rounded.xl}"
---

# LinkHive

## Overview

**Creative North Star:** A hard-edged, hand-stamped notebook for links, built so the one thing you remember is that it brings your links back.
**Product context:** Personal link manager and OS share target for people who save links from Instagram, YouTube, LinkedIn and shops, then forget them. Android first, iOS second. English, Hindi, Gujarati, Arabic.
**Mode per surface:** Today and Home are Operate (decide, open, snooze). Link detail and the Add form are Operate. Nothing in the app is long-form Read or Persuade.
**Reference sites:** Raindrop, Instapaper, Readwise Reader, Gumroad (researched 2026-10-07; screenshots in the gstack designs folder for this project).
**Key characteristics:**
- 2px ink outline on every surface that holds content.
- Hard pastel offset shadow, zero blur.
- Pastel accents always carry ink text, never white.
- Purple appears only when something came back.
- Pill buttons (52px tall) and 44px icon buttons.

**As built.** This file records the system as the code implements it, including the purple "return" rule and the Anek + Readex Pro typeface (bundled 2026-10-09).

## Colors

**Strategy:** Full palette, restrained by rules. Ink and white carry structure; pastels carry meaning.
**Light or dark:** Both ship. Light is the default (reading a list in daylight on a phone, often one-handed); dark follows the system setting. Dark swaps surfaces and flips the outline to light gray; pastel shadows stay the same.

- `ink` / `border` (#1E1E1E) is both text and outline. Never use a tint of it for borders.
- Shadow pastels (`shadow-mint` default, then peach, sky, rose, lemon) are depth, not decoration. One shadow color per component.
- `accent-*` fills mark categories and priority chips (orange = High). Text on them is always `ink`.
- **`return` (#F4EBFF) is the signature.** It marks "this came back": the Saved N× chip, the "Already saved" merge bar, the version picker badge. Do not use it for anything else, and do not add other purples.
- `text-secondary` (#4B5563) is the floor for secondary copy. `text-tertiary` (#9CA3AF) is for captions and placeholders only, never for information the user must read.
- `success`, `warning`, `error` are semantic only. `success` also colors the primary Open button's shadow.

## Typography

**Typeface (built):** Anek (Ek Type) for Latin, Devanagari and Gujarati, Readex Pro for Arabic, bundled as static weights 400 to 800 in `assets/fonts/` (`AppTypography.fontFamily` plus `fontFamilyFallback`). Licenses ship in `assets/licenses/` and show on the license page. Both are on Google Fonts under the OFL license (checked 2026-10-07). Anek has a width axis: use the condensed width for titles and numbers, normal width for reading text. One family across three scripts keeps Hindi and Gujarati from looking like fallback text.

**Scale (as built):** 34 / 28 / 22 / 20 / 18 / 16 at weight 700 to 800 for display and titles; body 15 at 500 (16 at 600 for emphasized body); label 13 at 600; caption 11 at 700. Titles use negative tracking; labels and captions use positive.

**Rules:**
- Test every text-bearing change at 1.3x system text scale in hi, gu and ar. Devanagari and Gujarati need the taller line heights above; do not tighten them.
- Never hardcode a TextStyle; use `AppTypography.*`.
- Arabic is right-to-left: mirror layout with directional padding, and do not mirror icons that have no direction.

## Layout

Single column, phone first. Page inset is 20px (`spacing.page`), and every screen's content aligns to it, including the app bar's leading button. Spacing is a 4px base on a 4 / 8 / 16 / 24 / 32 / 48 scale. Cards stack with 16px between them. Density is medium: one decision per card, titles up to two lines, metadata on one wrapped row. Today shows exactly one card at a time.

## Elevation & Depth

Depth is a hard offset shadow of (4, 4) with blur 0, in one pastel from the shadow set. Pressing a button moves it by the same 4px and drops the shadow to zero over 100ms, so it looks pushed in. No blurred shadows, no glow, no elevation tint. Dark mode keeps the pastel shadows.

## Shapes

Radii: 8 (small chips), 12 (text fields, compact cards), 16 (cards, snackbars), 20 (Today card, bottom sheets), 100 (buttons and pills). Borders are always 2px. Inner radius equals outer radius minus the gap when one rounded shape sits inside another, but avoid nesting cards.

## Components

- **Button (`NeoBrutalistButton`):** text buttons are full-width pills 52px tall (100 radius); icon-only buttons are 44px with a 16 radius. 2px outline, 4px hard shadow. Primary is ink with white text; default is white with ink text. Pressed: shadow collapses over 100ms. Loading shows a 20px spinner in the text color.
- **Link card (`LinkCard`):** 16px radius, 14 by 16 padding, 38px rounded-square avatar with pastel fill and ink letter when no site icon is available. Title 15 at 500, host 13 in secondary text.
- **Today card:** 20px radius, 24px padding, 16:9 thumbnail with 14px radius and outline, title 20 at 700, up to two lines, "Saved N×" chip in `return` next to the metadata.
- **Merge bar and snackbar:** 16px radius, outline, no shadow. A 32px circular badge on the left, message 15 at 600, actions right-aligned. The merge bar badge is `return`.
- **Bottom sheet:** 20px top radius, top outline only, 24px padding. Used for confirmations, option lists and the "Which version?" picker. Never use `AlertDialog`.
- **Bottom nav (`AppBottomNav`):** a floating pill: 64px tall, 16px from the screen edges and bottom, 100 radius, 2px outline and a hard ink shadow at (4, 4). Three tabs: Links, Today, Inbox. The active tab is a solid `primary` pill with icon and label; the others show only their icon (the label stays for screen readers). The Inbox badge is an `accent-orange` pill with an ink outline. The shell uses `extendBody`, so lists scroll under the nav and pad their bottom. Bulk selection replaces the nav with an action bar of four boxed cells separated by 2px ink rules.
- **Quick chips:** 38px pills on one scrolling row (All, Unread, High, Saved 2×+, Read), each with a count badge. One is active at a time: `primary` fill, `onPrimary` text and a mint hard shadow at (3, 3). The Saved 2×+ count badge uses the `return` fill.
- **Filter buttons (Source, Category, Sort):** three equal 42px boxes, 12px radius, 2px outline. A chosen source or category fills `accent-green` with ink text and a ✕ to clear it.
- **Add button:** a 56px solid `primary` circle with a `success` hard shadow, bottom right above the nav.
- **Pick rows (Source and Category sheets):** 54px rows with a 2px divider, a 32px circular letter avatar on a pastel, the name in `title-sm` (800 when picked), the count and a filled check when picked.
- **Suggestion box:** `shadow-lemon` fill, 16px radius, 2px ink outline, "Suggested for <site>" heading with a sparkle icon, then category chips that stay light in both themes.
- **Text field (`CustomTextField`):** 2px outline, 12px radius, focus outline is 3px in the primary color, error outline is 2px in `error`.
- **States to design every time:** empty, loading, error, long text, and 1.3x text scale.

## Do's and Don'ts

- Do: use `AppColors.*`, `AppSpacing.*`, `AppTypography.*`. No raw `Color()`, `EdgeInsets` values or `TextStyle`.
- Do: keep text on pastel fills in `ink`.
- Do: keep every tappable element at least 44px tall.
- Do: reserve `return` purple for return states.
- Do: show the hard shadow at (4, 4) with blur 0 on anything raised.
- Don't: add blurred shadows, glows, gradients or frosted glass.
- Don't: use `ElevatedButton`, `TextButton`, bare `AppBar`, bare `TextFormField` or `AlertDialog`; use the shared widgets.
- Don't: use a colored left border on a rounded card to signal state; use a tint, an icon or a label.
- Don't: put one card inside another.
- Don't: hardcode user-facing strings; all text goes through `context.l10n`.

## Motion

- **Approach:** minimal-functional.
- **Easing:** enter ease-out, exit ease-in, move ease-in-out.
- **Duration:** micro 100ms (button press), short 150 to 250ms (sheets, snackbars), medium 250 to 400ms (page transitions).
- **The one authored moment:** the 100ms hard-shadow press on every button. Nothing else animates for its own sake.

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-07 | Initial design system documented from the built code | Created by /design-consultation. Follows the code where the older docs disagreed: shadow offset (4, 4), radii 8/12/16/20/full, secondary text #4B5563, type scale 34 to 16 |
| 2026-10-07 | Purple `return` (#F4EBFF) reserved for "it came back" states | The app's memorable thing is that it brings links back; one color owning that meaning makes return states recognizable at a glance |
| 2026-10-07 | Target typeface: Anek Latin / Devanagari / Gujarati + Readex Pro (Arabic) | One family across four scripts, OFL license, verified on Google Fonts. Adoption is a separate follow-up, not part of this change |
| 2026-10-07 | Not adopted: stamped return states on cards, "return lane" Home, ticket-style Today | Suggested by both outside voices; recorded as ideas, no decision to build |
| 2026-10-08 | Home split into Today / Library / Inbox tabs; the app opens on Today | One Home screen with search and two chip rows broke down at a few hundred links. See `docs/designs/library-redesign.md` |
| 2026-10-08 | App bar buttons stay round, raised 44px `NeoBrutalistButton`s | Keeps the 100ms press, the one authored moment. Litverse's flat boxed header was considered and not adopted |
| 2026-10-08 | Built-in categories changed to Watch, Read, Shop, Recipes, Travel, Learn, Work, Ideas | The old developer set (Dev, Docs, AI...) didn't match people saving from Instagram, YouTube and shops. Old names keep their labels on existing links |
| 2026-10-09 | Links-first: the app opens on a Links tab (search, quick chips, Source / Category / Sort above the list). Library overview removed; tabs are Links, Today, Inbox | After a first try on the phone, the overview put links one tap too far away and felt like everything loaded at once. Approved in preview v2 |
| 2026-10-09 | Floating pill bottom nav | Picked from three options (floating pill, centre Add, boxed tabs) in `docs/designs/preview/nav-options.html` |
| 2026-10-09 | Main actions (Open, Save, Add) are solid `primary` buttons | They stand out from the white secondary buttons, as approved in preview v2 |
| 2026-10-09 | Anek + Readex Pro bundled | Approved with preview v2; the system font was the main reason the app looked plainer than the preview |
