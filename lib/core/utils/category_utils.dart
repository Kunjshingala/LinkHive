import 'package:flutter/widgets.dart';
import '../extensions/context_extension.dart';

class CategoryUtils {
  /// The built-in / suggested category keys shared across the whole app.
  /// Add or remove entries here to update every screen at once.
  static const List<String> suggestedCategories = ['Dev', 'Design', 'Read', 'Tools', 'Docs', 'AI', 'Finance', 'News'];

  /// Returns a localized category name if it's a suggested category,
  /// otherwise returns the original name.
  static String getLocalizedCategory(BuildContext context, String catKey) {
    final l10n = context.l10n;
    return switch (catKey) {
      'Dev' => l10n.catDev,
      'Design' => l10n.catDesign,
      'Read' => l10n.catRead,
      'Tools' => l10n.catTools,
      'Docs' => l10n.catDocs,
      'AI' => l10n.catAI,
      'Finance' => l10n.catFinance,
      'News' => l10n.catNews,
      _ => catKey,
    };
  }
}
