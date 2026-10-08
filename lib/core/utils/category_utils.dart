import 'package:flutter/widgets.dart';
import '../extensions/context_extension.dart';

class CategoryUtils {
  /// The built-in / suggested category keys shared across the whole app.
  /// Add or remove entries here to update every screen at once.
  static const List<String> suggestedCategories = ['Watch', 'Read', 'Shop', 'Recipes', 'Travel', 'Learn', 'Work', 'Ideas'];

  /// Built-in keys from before the 2026-10 redesign. No longer offered for new
  /// links, but links saved with them keep a translated label, and the
  /// Library still lists them while any link uses them.
  static const List<String> legacyCategories = ['Dev', 'Design', 'Tools', 'Docs', 'AI', 'Finance', 'News'];

  /// True when [name] is a current or legacy built-in key, ignoring case.
  static bool isBuiltIn(String name) {
    final n = name.trim().toLowerCase();
    return [...suggestedCategories, ...legacyCategories].any((c) => c.toLowerCase() == n);
  }

  /// Returns a localized category name if it's a built-in category,
  /// otherwise returns the original name.
  static String getLocalizedCategory(BuildContext context, String catKey) {
    final l10n = context.l10n;
    return switch (catKey) {
      'Watch' => l10n.catWatch,
      'Read' => l10n.catRead,
      'Shop' => l10n.catShop,
      'Recipes' => l10n.catRecipes,
      'Travel' => l10n.catTravel,
      'Learn' => l10n.catLearn,
      'Work' => l10n.catWork,
      'Ideas' => l10n.catIdeas,
      'Dev' => l10n.catDev,
      'Design' => l10n.catDesign,
      'Tools' => l10n.catTools,
      'Docs' => l10n.catDocs,
      'AI' => l10n.catAI,
      'Finance' => l10n.catFinance,
      'News' => l10n.catNews,
      _ => catKey,
    };
  }
}
