# Components & UI Reference

Quick-reference for all shared UI components, design tokens, and localization.

---

## Shared Widgets (`lib/sharedWidgets/`)

| Widget / Function | File | Description | Key Props |
|---|---|---|---|
| `NeoBrutalistButton` | `custom_button.dart` | Full-width Neo-Brutalist action button | `label`, `onPressed`, `icon`, `isOutlined`, `shadowColor`, `isLoading` |
| `CustomTextField` | `custom_text_field.dart` | TextFormField with Neo-Brutalist styling | `controller`, `label`, `hint`, `validator`, `prefixIcon`, `obscureText` |
| `LinkCard` | `link_card.dart` | Displays a single saved link | `link` (LinkModel), `onDelete`, `onEdit` |
| `CategoryChip` | `category_chip.dart` | Filter chip with selected/unselected states | `label`, `isSelected`, `onTap` |
| `AddCategoryChip` | `add_category_chip.dart` | Button to create a new custom category | `onTap` |
| `CommonAppBar` | `common_app_bar.dart` | Reusable app bar matching Neo-Brutalist design | `title`, `actions`, `showBackButton` |
| `AppLogo` | `app_logo.dart` | Brand logo widget | `size` |
| `PriorityBadge` | `priority_badge.dart` | Displays priority (High / Normal / Low) | `priority` (String) |
| `EmptyState` | `empty_state.dart` | No-data placeholder | `title`, `subtitle`, `icon` |
| `NeoPopupMenu` | `neo_popup_menu.dart` | Context menu button for link actions | `onEdit`, `onDelete` |
| `LocalModeBanner` | `local_mode_banner.dart` | Banner indicating offline / unauthenticated mode | — |

## Bottom Sheets (`lib/sharedWidgets/`)

| Function | File | Returns | Use When |
|---|---|---|---|
| `showConfirmationBottomSheet()` | `confirmation_bottom_sheet.dart` | `Future<bool?>` | Any confirm/cancel action; set `isDestructive: true` for dangerous actions |
| `showLogoutBottomSheet()` | `logout_bottom_sheet.dart` | `Future<(bool confirmed, bool clearLocal, bool clearRemote)?>` | Logout flow only |
| `showOptionsBottomSheet<T>()` | `options_bottom_sheet.dart` | `Future<T?>` | Generic option selection; uses `BottomSheetOption<T>` items |

**Never use `showDialog` / `AlertDialog`.** Always use these bottom sheets.

---

## AppColors (`lib/core/theme/app_colors.dart`)

### Base Palette
| Constant | Hex | Use |
|---|---|---|
| `AppColors.black` | `#1E1E1E` | Primary text, borders |
| `AppColors.white` | `#FFFFFF` | Backgrounds, surfaces |
| `AppColors.gray50` | `#F9FAFB` | Subtle backgrounds |
| `AppColors.gray100` | `#F3F4F6` | Secondary surface |
| `AppColors.gray200` | `#E5E7EB` | Dividers |
| `AppColors.gray600` | `#4B5563` | Secondary text |
| `AppColors.gray800` | `#1F2937` | Dark theme surface |
| `AppColors.gray900` | `#111827` | Dark text |

### Brand
| Constant | Hex | Use |
|---|---|---|
| `AppColors.brandBackground` | `#ECE2D5` | Splash screen, brand moments |

### Light Theme Semantic
| Constant | Value | Use |
|---|---|---|
| `AppColors.background` | `white` | Page background |
| `AppColors.surface` | `white` | Card background |
| `AppColors.secondarySurface` | `gray100` | Secondary cards |
| `AppColors.textPrimary` | `black` | Main text |
| `AppColors.textSecondary` | `gray600` | Captions, subtitles |

### Dark Theme Semantic
| Constant | Value | Use |
|---|---|---|
| `AppColors.backgroundDark` | `#121212` | Dark page background |
| `AppColors.surfaceDark` | `#1E1E1E` | Dark card background |
| `AppColors.textPrimaryDark` | `gray200` | Dark main text |

### Neo-Brutalist Pastel Shadows
| Constant | Hex | Pairing |
|---|---|---|
| `AppColors.shadowMint` | `#B5E4CA` | Green-tinted cards |
| `AppColors.shadowPeach` | `#FFDAB9` | Warm-tinted cards |
| `AppColors.shadowSky` | `#BBE4FB` | Blue-tinted cards |
| `AppColors.shadowRose` | `#FFD1DC` | Pink-tinted cards |
| `AppColors.shadowLemon` | `#FDF0A6` | Yellow-tinted cards |

### Semantic Status
| Constant | Hex | Use |
|---|---|---|
| `AppColors.success` | `#22C55E` | Success states |
| `AppColors.error` | `#EF4444` | Error states |
| `AppColors.warning` | `#F59E0B` | Warning states |

### Tag Accents
| Constant | Hex | Use |
|---|---|---|
| `AppColors.accentGreen` | `#D1FADF` | Category/tag backgrounds |
| `AppColors.accentOrange` | `#FEF0C7` | Category/tag backgrounds |
| `AppColors.accentBlue` | `#D1E9FF` | Category/tag backgrounds |
| `AppColors.accentPurple` | `#F4EBFF` | Category/tag backgrounds |

---

## AppSpacing (`lib/core/theme/app_spacing.dart`)

### Base Scale
| Constant | Value | Use |
|---|---|---|
| `AppSpacing.xs` | `4` | Tight gaps, icon padding |
| `AppSpacing.sm` | `8` | Small gaps, compact spacing |
| `AppSpacing.md` | `16` | Standard padding |
| `AppSpacing.lg` | `24` | Section gaps |
| `AppSpacing.xl` | `32` | Large section gaps |
| `AppSpacing.xxl` | `48` | Hero sections |

### Specific Constants
| Constant | Value | Use |
|---|---|---|
| `AppSpacing.radiusSm` | `8` | Small cards, inputs |
| `AppSpacing.radiusMd` | `12` | Standard cards |
| `AppSpacing.radiusLg` | `16` | Large cards |
| `AppSpacing.radiusXl` | `20` | Large modals |
| `AppSpacing.radiusFull` | `100` | Pills, chips, circular buttons |
| `AppSpacing.cardPaddingH` | `16` | Card horizontal padding |
| `AppSpacing.cardPaddingV` | `14` | Card vertical padding |
| `AppSpacing.pageH` | `20` | Page horizontal padding |

---

## AppTypography (`lib/core/theme/app_typography.dart`)

| Style | Size / Weight | Use |
|---|---|---|
| `AppTypography.displayLarge` | 34px / w800 | Screen titles |
| `AppTypography.headlineLarge` | 28px / w800 | Section headers |
| `AppTypography.headlineMedium` | 22px / w700 | Sub-section headers |
| `AppTypography.titleLarge` | 20px / w700 | Card titles |
| `AppTypography.titleMedium` | 18px / w700 | Dialog titles |
| `AppTypography.titleSmall` | 16px / w700 | List item titles |
| `AppTypography.bodyLarge` | 16px / w600 | Primary body text |
| `AppTypography.bodyMedium` | 15px / w500 | Secondary body |
| `AppTypography.bodySmall` | 14px / w500 | Captions (gray) |
| `AppTypography.labelLarge` | 13px / w600 | Chips, tags |
| `AppTypography.labelSmall` | 12px / w700 | Small badges |
| `AppTypography.caption` | 11px / w700 | Timestamps, metadata |

---

## Theme Extensions

Access via context extensions (defined in `lib/core/extensions/context_extension.dart`):

```dart
context.neoBrutal    // AppNeoBrutalTheme — shadowColor, borderColor, borderWidth, shadowOffset
context.colors       // ColorScheme
context.text         // TextTheme
context.l10n         // AppLocalizations — all localization strings
```

---

## Localization

ARB files: `lib/l10n/app_en.arb`, `app_ar.arb`, `app_hi.arb`, `app_gu.arb`
Generated class: `lib/l10n/localization/app_localizations.dart`

**Access pattern:**
```dart
context.l10n.homeTitle          // "Links"
context.l10n.homeEmptyStateTitle // "No Links yet!"
context.l10n.authWelcome        // "Welcome Back"
context.l10n.priorityHigh       // "High"
```

**Adding a new key:**
1. Add to `lib/l10n/app_en.arb` (and other ARB files)
2. Run `fvm flutter gen-l10n`
3. Use via `context.l10n.yourNewKey`
