# UI Design System & Architecture

LinkHive strictly uses the **Neo-Brutalism UI Pattern**. The design favors high contrast, pure colors, thick borders, and hard drop shadows to create a playful but stark aesthetic.

## 1. Core Visual Characteristics

- **Backgrounds:** Never use off-white or dark colors for the main background. Use pure white (`#FAFAFA` or `#FFFFFF`).
- **Surfaces/Cards:** Use pure white (`#FFFFFF`) with pure black borders.
- **Accents:** Use bright, highly saturated pastel colors (e.g., Mint, Peach, Sky Blue, Orange) for active states, tags, and shadows.
- **Shadows:** Avoid soft blurred drop shadows. Use hard off-set shadows (e.g., `Offset(3, 4)`) with solid accent colors and no blur.
- **Borders:** Thick black borders (typically 2px width: `Border.all(color: AppColors.border, width: 2)`) on all interactive or elevated elements.
- **Border Radius:** Soft and round — generally **16px to 24px** for cards, completely pill-shaped for buttons/floating action bars.

---

## 2. Typography System

LinkHive relies on a stark, bold typographic hierarchy (Inter/SF Pro style) with heavy weights mimicking the massive Timespent metrics display.

| Usage | Size | Weight |
|---|---|---|
| Screen Titles | 24–32 | Bold (w700) / ExtraBold (w800) |
| Section Titles | 18–22 | SemiBold (w600) |
| Body | 14–16 | Medium (w500) |
| Metadata/Labels | 12–14 | SemiBold (w600) |

- **Primary Text:** Pure Black (`#000000`) or near black.
- **Secondary Text:** Deep gray (`#333333` or `#6B7280`).
- **Tertiary Text:** Mid gray (`#9CA3AF`).

---

## 3. Theming Implementation Architecture

All UI colors, spacing, and typography are tokenized. **You must NEVER hardcode styles in widget files.**

Always import from `lib/core/theme/`:
- `AppColors.dart` (e.g., `AppColors.background`, `AppColors.buttonPrimary`, `AppColors.accentBlue`, `AppColors.shadowMint`)
- `AppSpacing.dart` (e.g., `AppSpacing.md`, `AppSpacing.radiusXl`)
- `AppTypography.dart` (e.g., `AppTypography.displayLarge`, `AppTypography.titleMedium`)

### The `buildLinkHiveTheme()` Base
The global Flutter Material 3 `ThemeData` is constructed in `lib/core/theme/app_theme.dart` and injected into `MaterialApp`. The base theme handles standard component styling (like `AppBar`, `TextFormField`, `Card`), so you rarely need to style these manually in the UI layer.

---

## 4. UI Component Guidelines

### App Bar
- Transparent background over the scout view.
- High-contrast typography for the title.
- No elevation (`elevation: 0`).

### Search/Text Inputs
- Pure white background (`#FFFFFF`).
- Solid 2px black border around the input.
- High border radius (`radiusMd` / `12px`).

### Cards / List Items
- Pure White background (`#FFFFFF`).
- 2px pure black border (`#000000`).
- Hard shadow underneath using a solid pastel color with an offset (no blur).

### Floating Action Buttons (FAB) / Bottom Nav
- Pill shape (`radius.circular(100)`).
- Solid black border and hard offset shadows.
- High-contrast foreground icons.

### Tags / Chips
- Bright accent primary background (e.g., Orange, Mint, Blue).
- Solid black text outline or deep black text color.
- Solid black borders.

### Pop-ups and Overlays
- **ALWAYS use BottomSheets** (`showModalBottomSheet`) for all dialogs, alerts, and selections. 
- **NO Dialogs** (`AlertDialog`, `showDialog`, etc.) allowed in the UI.
- BottomSheets must use a stark pure white background (`AppColors.surface`) with a high border radius at the top (`radiusXl`), thick boundaries, and avoid blurry drop shadows.
