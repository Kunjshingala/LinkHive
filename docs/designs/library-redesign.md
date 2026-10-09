# Design: Library Redesign (manage hundreds of links)

Drafted 2026-10-08
Branch: feat/ui-redesign
Repo: Kunjshingala/LinkHive
Status: BUILT on `feat/ui-redesign` (2026-10-08), not yet tested on a device. Plan reviews were skipped at the user's go-ahead after the HTML preview
Related: `DESIGN.md` (visual system), `docs/product-direction-return-engine.md` (Today, Inbox),
`docs/designs/smart-duplicate-merge.md` (Saved N×, `shareCount`, `otherUrls`)

## Problem Statement

Home (`lib/features/home/home.dart`, 1292 lines) does every job on one screen. That works
for 50 links and breaks at a few hundred:

- **Too much chrome before the first link.** The app bar has 4 actions (Account, Today,
  Add, Inbox). The pinned header (search + Categories row + Priorities row) is about 250px
  tall when expanded (`_kFiltersMaxExtent`, `home.dart:1248`).
- **"Older" becomes a pile.** Time grouping is only Today / This week / Older
  (`_timeBucket`, `home.dart:771`). After a month, almost everything is in "Older".
- **One sort order.** Always newest first by `createdAt`.
- **Single-select filters.** One category and one priority at a time
  (`LinksLoaded.activeCategory` / `activePriority` are single strings). The category row
  is a horizontal scroll, so anything past the screen edge is hidden.
- **No bulk actions.** Cleaning up 200 links is 200 swipes.
- **No overview.** Nothing shows how many links each category or site has.
- **Categories depend on effort the capture flow removes on purpose.** Share saves
  instantly with zero required fields (return-engine doc, "Capture design decision"), so
  most links never get a category. Any organization that needs categories fails at scale.

### Category problems found in the code

1. Built-ins are developer-focused: `Dev, Design, Read, Tools, Docs, AI, Finance, News`
   (`lib/core/utils/category_utils.dart:7`). The users in `DESIGN.md` save from Instagram,
   YouTube, LinkedIn and shops.
2. Categories are picked only in the full Add/Edit form, as a wrap of every chip.
3. **Bug:** `LinkRepository.deleteCategory` (`link_repository.dart:321`) removes the
   category record but leaves its name on every link. Those links keep a category that no
   longer appears in any filter.

## Decisions (agreed 2026-10-08)

| # | Decision | Source |
|---|---|---|
| D1 | Replace the single Home with bottom tabs: **Today / Library / Inbox** | User, Q1 |
| D2 | The app opens on **Today** | User, Q2 |
| D3 | Phase 1 = Library overview + Sources + filter sheet + sort + bulk select | User, Q3 |
| D4 | Phase 1 categories: **suggestions by site** + **new built-in set** | User |
| D5 | Not in phase 1: category color/icon, rename/merge screen, one-tap category row | User |
| D6 | Visual: borrow **Litverse's layout only** (square tab row, ruled bottom nav, boxed action cells). Keep `DESIGN.md` styling: rounded cards, pill buttons, hard pastel shadows | Recommended; user didn't object. Confirm in design review |
| D7 | App bar buttons stay **as built**: round 44px `NeoBrutalistButton` with hard shadow and press animation, via `CommonAppBar`. The flat boxed-cell header is shown in the preview as an alternative only | Recommended 2026-10-08; preview has a switch to compare |

## References

Researched 2026-10-08. Mobbin needs a paid plan and Figma Community blocks automated
access, so neither was used. Images are saved locally in
`.gstack/browse-reports/2026-10-08-0842/refs/` (gitignored, not committed: other people's
work).

| Pattern | Seen in | Used for |
|---|---|---|
| Count tiles at the top (All, Unsorted, Today, Trash) | [Anybox](https://apps.apple.com/us/app/anybox-bookmark-read-later/id1593408455) | Smart-list tiles |
| Automatic groups by type/site with counts | [Raindrop](https://apps.apple.com/us/app/raindrop-io/id1021913807) "Filters", Anybox "Kinds" | Sources |
| Compact rows: thumbnail, title, "host · date" | Anybox, [GoodLinks](https://apps.apple.com/us/app/goodlinks/id1474335294), [Matter](https://apps.apple.com/us/app/matter-reading-app/id1501592184) | List row (phase 2 compact toggle) |
| Sort menu + view toggle in the list header | Anybox, Raindrop | Sort sheet |
| Inbox / Later / Archive tabs inside the library | [Readwise Reader](https://apps.apple.com/us/app/readwise-reader/id1567599761) | All / Unread / Read tabs |
| Boxed header, square chip tabs, ruled bottom nav, boxed action cells | [Litverse (Dribbble)](https://dribbble.com/shots/24962649-Litverse-Mobile-App-Design) | Layout skeleton (D6) |
| Search field next to a bordered filter button | [Courses app (Dribbble)](https://dribbble.com/shots/18102313-NeuBrutalism-UI-style-Education-Courses-App) | Library search row |
| Bordered pill rows with a chevron | [ClockWork (Dribbble)](https://dribbble.com/shots/25165407-ClockWork-Mobile-App-Design) | Source and category rows |

## Information Architecture

```
Bottom nav (ruled top border, 3 items)
├── Today      default tab. Unchanged single-card resurface view.
├── Library    overview → link list (filtered by smart list / source / category / search)
└── Inbox (N)  unchanged list of quick-saved links; count badge on the tab
```

- **Account** moves to a round header button on the left of the Library header.
- **Add** moves to a round header button on the right of the Library header. Sharing stays the main way in.
- **Up Next strip and "All caught up" banner** (Home) are dropped. Today already does
  "bring one back", and both are noise in a large library.

## Screens

### 1. Library overview (`LibraryScreen`, new)

```
┌──────┬─────────────────────┬──────┐
│  👤  │       Library       │  ＋  │   boxed header (Litverse layout)
├──────┴─────────────────────┴──────┤
│ [🔍 Search links       ] [ ⚙ ]    │   search + filter button
│                                   │
│ ┌─────────────┐ ┌─────────────┐   │   smart-list tiles, 2 × 2
│ │ Unread  142 │ │ High     12 │   │   (card style, pastel shadow)
│ └─────────────┘ └─────────────┘   │
│ ┌─────────────┐ ┌─────────────┐   │
│ │ Saved 2×+ 9 │ │ Read    310 │   │   Saved 2×+ uses `return` purple
│ └─────────────┘ └─────────────┘   │
│                                   │
│ SOURCES                     All → │   top 5 hosts by count
│ ( ▶ youtube.com          88  › )  │
│ ( 📷 instagram.com        61  › )  │
│ ( in linkedin.com        40  › )  │
│                                   │
│ CATEGORIES                        │   categories in use, by count
│ ( Watch                  34  › )  │
│ ( Recipes                18  › )  │
│                                   │
│ ( All links             512  › )  │
├───────────────────────────────────┤
│  Today   │  Library  │  Inbox (4) │
└───────────────────────────────────┘
```

- Tiles and rows open the link list with that filter applied.
- **Sources** come from each link's host (see Data). No user effort.
- **Categories** lists every category with at least one link: built-in, custom, and
  legacy names found on links. So nothing is ever hidden.
- **Read** is the existing `isRead` state. Today's "Archive" already sets it
  (`LinkManager.archiveLink`, `link_manager.dart:167`). No new field.
- Empty library: the existing `EmptyState` with an Add button.

### 2. Link list (`LinkListScreen`, new)

```
┌──────┬─────────────────────┬──────┐
│  ←   │   youtube.com · 88  │  ⇅   │   title = active scope; ⇅ = sort sheet
├──────┴─────────────────────┴──────┤
│ [All] [Unread] [Read]       [⚙ 2] │   square tab row + filter button with count
│ (Watch ✕) (High ✕)                │   active filter chips, tap ✕ to remove
│ OCTOBER 2026                      │   month headers when sorted by date
│ ┌───────────────────────────────┐ │
│ │ existing LinkCard              │ │   swipe right = read, left = delete (kept)
│ └───────────────────────────────┘ │
```

- **Filter sheet** (bottom sheet): multi-select Categories, multi-select Priority,
  Source. Apply / Reset buttons.
- **Sort sheet**: Newest, Oldest, Priority (High first), Most saved (`shareCount`),
  Site A–Z.
- **Month headers** replace Today / This week / Older when sorting by date. No headers
  for other sorts.
- **Search** from the overview opens this screen in search mode (all links, search field
  in the header). Search matches title, URL and host.
- Pagination stays (`limit`/`offset`, 20 per page).

### 3. Bulk select (in the link list)

- Long-press a card → selection mode. The header shows "3 selected" and Select all.
- Bottom action bar, boxed cells (Litverse layout): **Mark read · Category · Priority ·
  Delete**.
- Category opens a picker sheet with **suggested categories first** (see below), then all.
  It adds the category to the selected links. It doesn't replace their other categories.
- Delete asks for confirmation (`showConfirmationBottomSheet`) with the count.
- Back or the ✕ exits selection.

### 4. Today and Inbox

- **Today** becomes the default tab. Drop its back button. The empty state gets a
  "Browse Library" button, since it's now the first screen people see.
- **Inbox** is unchanged apart from living in a tab. The count badge moves to the tab.

## Categories (phase 1)

### New built-in set

`CategoryUtils.suggestedCategories` becomes:
**Watch, Read, Shop, Recipes, Travel, Learn, Work, Ideas**

- New l10n keys in all 4 ARB files: `catWatch`, `catShop`, `catRecipes`, `catTravel`,
  `catLearn`, `catWork`, `catIdeas` (`catRead` exists).
- **Legacy keys** (`Dev, Design, Tools, Docs, AI, Finance, News`) stay in
  `getLocalizedCategory` so existing links keep their translated labels. They're no
  longer offered as new suggestions. They still show in Library Categories and in
  pickers while any link uses them.
- `addCategory`'s duplicate check (`link_repository.dart:301`) must check legacy keys too.

### Suggestions by site

New pure helper `CategorySuggester` (`lib/core/utils/category_suggester.dart`):

```
suggest(host, allLinks) → ordered List<String>
  1. Categories you already used for this host on 2+ links, most used first
  2. Else a small built-in map:
       youtube.com, youtu.be            → Watch
       amazon.*, flipkart, myntra, ajio → Shop
       airbnb, booking, makemytrip      → Travel
       coursera, udemy                  → Learn
       medium, substack                 → Read
  3. Else nothing
```

Shown as a "Suggested" row at the top of the Add/Edit form's category section and the
bulk picker. In the bulk picker, suggestions are used only when every selected link has
the same host.

### Bug fix: deleting a category (separate commit)

`deleteCategory` also removes the name from every link that has it, and queues those
links for sync. The confirmation message says how many links it affects. This fix is
required: Library lists "categories in use", so without it a deleted category would come
back.

## Data layer

All of these are in-memory filters over the Hive box, like `queryLinks` today.

- **Host key:** `sourceHost(url)`. Lowercase host, strip `www.` and `m.`, and map
  `youtu.be` → `youtube.com`. Put it next to the canonical URL helpers
  (`lib/core/utils/url_canonical.dart`). No stored field; compute it when querying.
- **`LinkQuery`** value object: `search`, `categories` (set), `priorities` (set), `host`,
  `readState` (all / unread / read), `minShareCount`, `sort`. `queryLinks` takes it
  instead of single strings. Inbox (quick-saved) links stay excluded.
- **`getLibraryStats()`**: total, unread, high, savedTwicePlus, read.
- **`getSourceCounts()`** and **`getCategoryCounts()`**: sorted (name, count) lists.
- **Bulk writes:** `markLinksRead(ids)`, `addCategoryToLinks(ids, name)`,
  `setPriorityForLinks(ids, p)`, `deleteLinks(ids)`. Each one marks the links unsynced
  and queues sync exactly like the single-link versions. One Hive `putAll` per call.

## State and routing

- **Feature folders:** `lib/features/library/` (`LibraryBloc`: stats, sources,
  categories; watches the box) and `lib/features/library/link_list/` (`LinkListBloc`:
  query, sort, pagination, selection). Both follow the sealed Event/State pattern in
  `.claude/rules/code-patterns.md`.
- **Routing** (`route.dart`, rules say ask first: this plan is the ask):
  `StatefulShellRoute.indexedStack` with 3 branches: `/today`, `/library`, `/inbox`.
  New route `MyRouteName.linkList` (`/library/links`, extra: `LinkQuery`).
  `MyRouteName.homeScreen` (`/home`) stays as a redirect to `/today`, so login, signup,
  account and share callers keep working.
- **Callers that `pushNamed(MyRouteName.today)`** (`resurface_notification_service.dart:133`,
  `home_widget_service.dart:119`) switch to `goNamed` so they change tabs instead of
  stacking a second Today.
- **Old Home** (`lib/features/home/`) is deleted once Library replaces it. Before
  deleting, check what else uses `LinkBloc`'s filter events.

## Visual additions to `DESIGN.md` (after design review)

- **Bottom nav:** surface background, 2px ink top border, 3 items, label + icon, active
  item with `accent-green` fill pill. 64px tall plus safe area.
- **Header:** no change. `CommonAppBar` with round 44px `NeoBrutalistButton`s (D7).
  Library puts Account on the left and Add (success shadow) on the right.
- **Smart-list tile:** card, 16 radius, label + big count (title-lg), one pastel shadow
  each. "Saved 2×+" uses `return` fill.
- **Selection action bar:** 4 equal boxed cells, icon + label, 2px ink rules, sits above
  the bottom nav.
- `DESIGN.md` says "Today shows exactly one card at a time" and "Single column". Both
  still hold. The 2 × 2 tiles are the one exception and need a decision-log entry.

## Not in scope (phase 2 or later)

- Compact row toggle and fast-scroll handle
- Category color/icon, rename, merge, reorder (needs a migration to category IDs)
- One-tap category row on the Saved bar and Inbox items
- Grid view, nested folders, tags, saved searches
- Inbox triage mode (ruled out by the return-engine doc)

## Implementation order (one commit each)

1. Category delete bug fix + tests
2. `sourceHost` helper + tests
3. `LinkQuery`, `queryLinks` rewrite, stats/counts methods, bulk writes + repository tests
4. New built-in categories + l10n (4 ARB files, `gen-l10n`) + `CategorySuggester` + tests
5. Shell route + bottom nav; Today as default; Inbox tab; `/home` redirect; notification
   and widget callers
6. `LibraryBloc` + Library overview screen
7. `LinkListBloc` + list screen: tabs, filter sheet, sort sheet, month headers, search
8. Bulk selection + action bar + category picker with suggestions
9. Delete old Home; update `DESIGN.md`, `.ai/context/project.md`, CLAUDE.md route table

`fvm flutter analyze` with zero issues and `fvm flutter test` passing after every step.

## Tests

- `sourceHost`: www/m stripping, youtu.be alias, IP and invalid URLs
- `CategorySuggester`: history beats the default map, 2-link threshold, unknown host
- Repository: each `LinkQuery` field alone and combined, every sort order, quick-saved
  links excluded, counts match queries, bulk writes queue sync for every link
- `deleteCategory` removes the name from links and queues sync
- `LinkListBloc` (`bloc_test`): filter, sort, paging, enter/exit selection, bulk action
  then reload
- Widget tests: bottom nav switches tabs and keeps each tab's scroll position; Library
  tiles open the right filtered list; selection bar appears on long-press
- Existing Today, Inbox and share tests stay green

## Success criteria

- From launch, any link out of 500 is reachable in **3 taps or fewer** through a source,
  category or smart list.
- 50 links get a category in **under 30 seconds** with bulk select.
- The first link on the list screen is visible with no scrolling on a 6.1" phone.
- No regression in Today, Inbox, share-to-save or the 9am notification.

## Open questions

1. Label for read links: the app says "Read" in lists and "Archive" on Today. Pick one
   word for the tile and the tab.
2. Should Today's header also show the Account cell, or only Library?
3. Does the Android home-screen widget's "home" deep link go to Today or Library?

## As built (2026-10-08)

Where the build differs from the plan above:

- **Query API:** the Library uses a new `LinkRepository.findLinks(LinkQuery)` plus `countLinks`. The old `queryLinks` stays in the repository because about ten repository tests use it to read the box; the manager no longer exposes it.
- **Selection bar replaces the bottom nav** instead of sitting above it (`AppShell.navVisible`), as shown in the preview.
- **No data access in widgets.** Category suggestions live in `AddLinkForm` (from `AddLinkBloc`); the filter and category sheets each have a cubit (`FilterSheetCubit`, `CategoryPickerCubit`); the Inbox badge is `InboxBadgeCubit`. `setState` is left only for UI-only state (swipe direction, press effect).
- **Today is a live tab:** `TodayBloc` now watches the links box and re-picks without a loading flash (`TodayRefreshRequested`).
- **Back button:** `HomeBloc` moved to `ShellBloc`. Back on Library or Inbox goes to Today; on Today it needs a second press to exit.
- **Swipe card** moved from Home to `lib/sharedWidgets/swipeable_link_card.dart` and gained a long-press hook; a `mounted` guard fixes a `setState` after dispose when long-press swaps the card.
- **Add form** also shows selected legacy categories (like "Dev") so they can still be removed.
- **Primary buttons** use the real `NeoBrutalistButton` primary style (white fill, colored shadow), not the solid ink fill drawn in the preview.
- **Open questions resolved by default:** "Read" is the label for finished links; Account appears only on Library; the widget's "home" link goes to Today.
- **Not done:** "Manage" categories link (phase 2), on-device check.

## v2: Links-first (2026-10-09)

After 5-6 minutes on the phone the user said the overall UX was not good:
links were too far away (the Library overview was a dashboard, not a list),
opening on Today was wrong, it looked plain, things were hard to find, and
everything felt loaded at once. v2 was previewed (`docs/designs/preview/ui-redesign-preview-v2.html`,
nav picked from `nav-options.html`) and approved before building.

- **Tabs:** Links (opens here) · Today · Inbox, in a floating pill nav. Back on Today or Inbox goes to Links.
- **Links tab = the list.** Search (always visible), quick chips with counts (All, Unread, High, Saved 2×+, Read), then Source / Category / Sort buttons, then the links. Filters apply in place; "N links" shows when anything narrows the list. The Library overview, its bloc, the multi-select filter sheet and `/library/links` are gone.
- **Grouping:** Today / This week / month headers for date sorts; **By site** groups under "youtube.com · 88" headers, sites with most links first; Priority groups by High / Normal / Low.
- **Category sheet** adds "No category" (`LinkQuery.uncategorized`) so unsorted links can be tidied with bulk select.
- **Select button** in the header starts bulk select with nothing picked; long-press still works.
- **Add** is a solid ink round button; Open, Save and "Add to N links" are solid ink too.
- **Anek + Readex Pro** bundled (see `DESIGN.md`).
- Code: `lib/features/link_list/` (screen, `LinkListBloc` with sync and overview counts, `CategoryPickerCubit`); `LinkQuery` gained `QuickFilter` presets and `hasFilters`.
