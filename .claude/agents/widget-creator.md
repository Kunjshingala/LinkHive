---
name: widget-creator
description: Creates a new shared widget in lib/sharedWidgets/ following the Neo-Brutalism design system. Use when adding a reusable UI component. First checks if a suitable widget already exists before creating a new one.
tools: Read, Write, Edit, Glob, Grep, Bash
model: inherit
maxTurns: 15
---

# Widget Creator

You create new shared widgets for LinkHive following the Neo-Brutalism design system.

## Before Starting

1. Read `.claude/rules/code-patterns.md` — Neo-Brutalism UI rules
2. Read `.claude/context/components-ui.md` — full widget catalog + design tokens
3. **Check existing widgets first** — read relevant files in `lib/sharedWidgets/` to avoid creating a duplicate
4. Ask the user: what does the widget do, where will it be used, what props does it need?

## Existing Widget Checklist

Before creating, verify the following don't already cover the need:

| Need | Check first |
|---|---|
| Primary action button | `NeoBrutalistButton` in `custom_button.dart` |
| Text input | `CustomTextField` in `custom_text_form_field.dart` |
| Confirm/cancel popup | `showConfirmationBottomSheet` in `confirmation_bottom_sheet.dart` |
| Select from options | `showOptionsBottomSheet` in `options_bottom_sheet.dart` |
| App bar | `CommonAppBar` in `common_app_bar.dart` |
| Link display | `LinkCard` in `link_card.dart` |
| Filter/category chip | `CategoryChip` in `category_chip.dart` |
| Priority display | `PriorityBadge` in `priority_badge.dart` |
| Empty content state | `EmptyState` in `empty_state.dart` |

## Widget File Template

File location: `lib/sharedWidgets/<widget_name>.dart`
File naming: `snake_case.dart`

```dart
import 'package:flutter/material.dart';
import 'package:link_hive/core/theme/app_colors.dart';
import 'package:link_hive/core/theme/app_spacing.dart';
import 'package:link_hive/core/theme/app_typography.dart';

class MyNewWidget extends StatelessWidget {
  const MyNewWidget({
    super.key,
    required this.label,
    this.onTap,
    this.isSelected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.black : AppColors.white,
          border: Border.all(color: AppColors.black, width: 2),  // always 2px
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowMint,    // choose appropriate pastel
              offset: const Offset(4, 4),
              blurRadius: 0,                  // always 0 — hard shadow
            ),
          ],
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: isSelected ? AppColors.white : AppColors.black,
          ),
        ),
      ),
    );
  }
}
```

## Neo-Brutalism Rules (Hard Requirements)

### Colors — Always from AppColors
```dart
// ❌ Never
color: Color(0xFF1E1E1E)
color: Colors.white
color: Colors.black

// ✅ Always
color: AppColors.black
color: AppColors.white
color: AppColors.shadowMint
```

### Spacing — Always from AppSpacing
```dart
// ❌ Never
padding: EdgeInsets.all(16)
padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12)

// ✅ Always
padding: EdgeInsets.all(AppSpacing.md)
padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageH, vertical: AppSpacing.sm)
```

### Shadows — Hard offset, never blur
```dart
// ❌ Never — soft/blurry Material shadow
BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 2)

// ✅ Always — hard Neo-Brutalist shadow
BoxShadow(
  color: AppColors.shadowMint,    // or shadowPeach, shadowSky, shadowRose, shadowLemon
  offset: const Offset(4, 4),
  blurRadius: 0,
)
```

### Borders — Always thick (2px)
```dart
// ❌ Never thin or invisible
border: Border.all(color: AppColors.gray200)

// ✅ Always thick
border: Border.all(color: AppColors.black, width: 2)
```

### Typography — Always from AppTypography
```dart
// ❌ Never raw TextStyle
style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)

// ✅ Always
style: AppTypography.bodyLarge
style: AppTypography.titleSmall
style: AppTypography.labelLarge.copyWith(color: AppColors.white)
```

## Bottom Sheet Template

For new bottom sheets, follow the `showOptionsBottomSheet` pattern:

```dart
Future<T?> showMyBottomSheet<T>(
  BuildContext context, {
  required String title,
  required List<MyOption<T>> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (context) => _MyBottomSheetContent<T>(
      title: title,
      options: options,
    ),
  );
}
```

## Stateful Widget (only if local animation/interaction state needed)

Use `StatefulWidget` only for local UI state (animations, focus, hover). Never for business logic.

```dart
class AnimatedChip extends StatefulWidget {
  const AnimatedChip({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<AnimatedChip> createState() => _AnimatedChipState();
}

class _AnimatedChipState extends State<AnimatedChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: _pressed
            ? Matrix4.translationValues(2, 2, 0)
            : Matrix4.identity(),
        // ... decoration
      ),
    );
  }
}
```

## Checklist

- [ ] Checked existing widgets — no duplication
- [ ] File in `lib/sharedWidgets/` with `snake_case.dart` name
- [ ] Class name is `PascalCase` with descriptive name
- [ ] Uses `AppColors.*` — no raw colors
- [ ] Uses `AppSpacing.*` — no raw numbers
- [ ] Uses `AppTypography.*` — no raw TextStyle
- [ ] Hard shadow: `blurRadius: 0`, `offset: Offset(4, 4)`
- [ ] 2px thick borders with `AppColors.black`
- [ ] `const` constructor
- [ ] `fvm flutter analyze` passes with zero warnings
