# LinkHive — Existing Feature Polish Plan

> Fix what's built before adding what's new.  
> Ordered by severity: 🔴 Critical → 🟡 Important → 🟢 Polish

last_updated: 2026-07-28

---

## 🔴 Critical — App feels broken without these

### C1. Link Card: Cannot Open Links
- **File:** `lib/sharedWidgets/link_card.dart`
- **Problem:** Tapping a saved link does NOTHING. There's no `GestureDetector`, no `onTap`, and `url_launcher` is not in `pubspec.yaml`. This is the #1 action users expect.
- **Fix:** Add `url_launcher` dependency. Wrap card body with tap handler to open URL in external browser. Add visual tap feedback.

---

### C2. Link Card: Cannot Copy or Share URL
- **File:** `lib/sharedWidgets/link_card.dart`
- **Problem:** The 3-dot menu only has Edit and Delete. Users cannot copy a link to clipboard or share it via OS share sheet — the two most common quick actions.
- **Fix:** Add "Copy URL" (clipboard + snackbar confirmation) and "Share" (OS share sheet) to `NeoPopupMenu`. Consider also adding "Open in Browser" to the menu as an alternative to the tap action.

---

### C3. Add Link: No URL Validation
- **File:** `lib/features/links/bloc/add_link_bloc.dart`
- **Problem:** `_onSaveRequested` only checks if URL is empty. Users can save `"hello world"` as a link — which breaks metadata fetch and will crash url_launcher later.
- **Fix:** Validate URL format before saving (must be a parseable URI with http/https scheme). Show clear error message.

---

### C4. Add Link: Missing Scheme Auto-Prepend
- **File:** `lib/core/services/link_metadata_service.dart`, `lib/features/links/bloc/add_link_bloc.dart`
- **Problem:** Typing `flutter.dev` (without `https://`) causes `Uri.parse` to fail silently. Metadata doesn't load and the user gets no feedback about why.
- **Fix:** Auto-prepend `https://` if the URL has no scheme. Do this before metadata fetch AND before save.

---

## 🟡 Important — Noticeably rough without these

### I1. Search: Not Debounced
- **File:** `lib/features/home/home.dart` (L218)
- **Problem:** `onChanged` fires on every keystroke, causing rapid Bloc events and UI rebuilds. Typing "flutter" triggers 7 separate search queries.
- **Fix:** Add debounce (300ms) using `rxdart` (already in dependencies) or a `Timer` before dispatching `LinkSearchChanged`.

---

### I2. Search: Wrong Empty State
- **File:** `lib/features/home/home.dart`
- **Problem:** Searching for a non-existent term shows *"You don't have any links yet"* (the no-links empty state) instead of *"No results found for 'xyz'"*. Confusing.
- **Fix:** Differentiate between "zero links saved" and "zero search results". Show different message + icon for each.

---

### I3. Home: Pagination Double-Trigger
- **File:** `lib/features/home/home.dart`
- **Problem:** `_onScroll` triggers `LinkLoadNextPageRequested` without a loading guard. Fast scrolling can fire duplicate fetch requests.
- **Fix:** Check if a page load is already in progress before dispatching. Add `isLoadingMore` flag to state.

---

### I4. Categories: Duplicate Names Allowed
- **File:** `lib/features/links/repository/link_repository.dart`
- **Problem:** `addCategory` doesn't check if a category with the same name already exists. Users can create "Dev", "dev", "DEV" as separate categories.
- **Fix:** Case-insensitive duplicate check before adding. Show message if duplicate detected.

---

### I5. Metadata: No Favicon Fallback
- **File:** `lib/core/services/link_metadata_service.dart`
- **Problem:** Only fetches Open Graph `og:image`. Doesn't try `<link rel="icon">` or the standard `/favicon.ico` path. Many sites (especially smaller ones) don't have OG images but do have favicons, causing unnecessary letter-avatar fallbacks.
- **Fix:** Add favicon extraction: first try `<link rel="icon">` from HTML, then fall back to `{domain}/favicon.ico`.

---

## 🟢 Polish — Small tweaks, professional feel

### P1. Search: Add Clear Button
- **File:** `lib/features/home/home.dart`
- **Problem:** No way to clear the search bar quickly. User has to manually delete text.
- **Fix:** Add a suffix "✕" icon to the search field that clears query and resets results.

---

### P2. Text Fields: Mobile Capitalization
- **File:** `lib/features/links/ui/add_link_screen.dart`
- **Problem:** Title and Description fields don't use `TextCapitalization.sentences`. Typing on mobile feels tedious since every sentence starts lowercase.
- **Fix:** Add `textCapitalization: TextCapitalization.sentences` to title and description fields.

---

### P3. Account: Stats Overflow Protection
- **File:** `lib/features/account/account.dart`
- **Problem:** Stats row uses `headlineMedium` font. Could clip/overflow if link count reaches 10,000+.
- **Fix:** Wrap count text in `FittedBox` or use `maxLines: 1` with `overflow: TextOverflow.ellipsis`.

---

### P4. Search: Highlight Matching Text
- **File:** `lib/sharedWidgets/link_card.dart`
- **Problem:** Search results show matching links but don't highlight the matched text. Hard to see WHY a result matched.
- **Fix:** Pass search query to `LinkCard`, use `RichText` to highlight matching substring in title/URL.

---

## Summary

| Priority | Count | Effort Estimate |
|---|---|---|
| 🔴 Critical | 4 fixes | ~2-3 hours |
| 🟡 Important | 5 fixes | ~2-3 hours |
| 🟢 Polish | 4 fixes | ~1-2 hours |
| **Total** | **13 fixes** | **~5-8 hours** |

---

## Suggested Build Order

1. **C1 + C2** — Link Card open/copy/share (this alone makes the app usable)
2. **C3 + C4** — URL validation + scheme auto-prepend (prevents bad data)
3. **I1 + I2 + P1** — Search improvements (debounce + correct empty state + clear button)
4. **I3** — Pagination guard
5. **I4** — Category duplicate prevention
6. **I5** — Favicon fallback
7. **P2 + P3 + P4** — Remaining polish
