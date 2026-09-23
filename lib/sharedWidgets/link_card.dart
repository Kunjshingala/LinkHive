import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/extensions/context_extension.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/category_utils.dart';
import '../core/utils/utils.dart';
import '../features/links/models/link_model.dart';
import 'confirmation_bottom_sheet.dart';
import 'neo_popup_menu.dart';
import 'priority_badge.dart';

/// Reusable card widget that displays a single [LinkModel] in a list.
///
/// ## Layout
/// ```
/// ┌─────────────────────────────────────────────┐
/// │ [_FaviconAvatar] │ [_LinkContent] │ [_MoreMenu] │
/// │                  │   title        │             │
/// │   image/letter   │   host URL     │   ⋮ menu    │
/// │                  │   tags + time  │             │
/// └─────────────────────────────────────────────┘
/// ```
///
/// ## Design System
/// All visual values (padding, border radius, colors, typography) are sourced
/// from the design system tokens ([AppSpacing], [AppColors], [AppTypography])
/// via `context.neoBrutal` — no raw literals are used inline.
///
/// ## Usage
/// ```dart
/// LinkCard(
///   link: myLink,
///   searchQuery: 'flutter',
///   onEdit: () => context.push('/edit/${myLink.id}'),
///   onDelete: () => context.read<LinkBloc>().add(LinkDeleted(myLink.id)),
/// )
/// ```
///
/// Both [onEdit] and [onDelete] are optional. When both are null the three-dot
/// menu is hidden entirely (see [_MoreMenu]).
class LinkCard extends StatelessWidget {
  /// The link to display.
  final LinkModel link;

  /// Called when the user selects "Edit" from the popup menu.
  /// Null hides the "Edit" menu item.
  final VoidCallback? onEdit;

  /// Called when the user confirms deletion via the bottom sheet.
  /// Null hides the "Delete" menu item.
  final VoidCallback? onDelete;

  /// Current Home search query. Matching title and host text is highlighted
  /// only when this value is non-empty.
  final String searchQuery;

  const LinkCard({super.key, required this.link, this.searchQuery = '', this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    // Retrieve the Neo-Brutalist design extension (border color, width, etc.)
    // from the current theme via the context extension.
    final neo = context.neoBrutal;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: neo.borderColor, width: neo.borderWidth),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              onTap: () => _openLink(context),
              child: Padding(
                padding: EdgeInsetsDirectional.all(AppSpacing.cardPaddingH),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FaviconAvatar(link: link),
                    SizedBox(width: AppSpacing.md - 4),
                    Expanded(child: _LinkContent(link: link, searchQuery: searchQuery)),
                    _MoreMenu(link: link, onEdit: onEdit, onDelete: onDelete),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!link.isRead)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accentOrange,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openLink(BuildContext context) async {
    try {
      final uri = Uri.parse(link.url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        showSnackBar('Could not launch ${link.url}');
      }
    } catch (_) {
      showSnackBar('Could not launch ${link.url}');
    }
  }
}
// ─── Favicon / Avatar ─────────────────────────────────────────────────────────

/// Displays a 38×38 px avatar at the leading edge of the card.
///
/// Shows the link's preview image ([LinkModel.image]) when available, using
/// [CachedNetworkImage] for efficient loading and disk caching. Falls back
/// to [_LetterAvatar] when:
/// - [LinkModel.image] is empty (no image returned by Open Graph metadata).
/// - The image URL fails to load (network error, 404, etc.).
class _FaviconAvatar extends StatelessWidget {
  final LinkModel link;
  const _FaviconAvatar({required this.link});

  @override
  Widget build(BuildContext context) {
    if (link.image.isNotEmpty && !_isSvgUrl(link.image)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 2),
        child: CachedNetworkImage(
          imageUrl: link.image,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorWidget: (ctx, url, err) => _LetterAvatar(link: link),
        ),
      );
    }
    return _LetterAvatar(link: link);
  }
}
/// Fallback avatar that displays the first character of the link's title (or URL).
///
/// The background color is deterministically derived from the character's
/// Unicode code point so the same link always gets the same color, making the
/// list visually consistent between app restarts without storing any color data.
class _LetterAvatar extends StatelessWidget {
  final LinkModel link;
  const _LetterAvatar({required this.link});

  @override
  Widget build(BuildContext context) {
    // Derive the display letter: prefer title, fall back to URL, then '?'.
    final letter = link.title.isNotEmpty
        ? link.title[0].toUpperCase()
        : (link.url.isNotEmpty ? link.url[0].toUpperCase() : '?');

    final colors = _avatarColor(letter, context);

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: colors.$1, borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 2)),
      alignment: Alignment.center,
      child: Text(letter, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: colors.$2, fontSize: 15)),
    );
  }

  /// Returns a `(backgroundColor, textColor)` pair deterministically chosen
  /// from a fixed palette based on the character's Unicode code point.
  ///
  /// Using `code % palette.length` distributes letters across the palette
  /// evenly. The text color is always `colorScheme.onSurface` so it remains
  /// readable in both light and dark themes regardless of the background.
  (Color, Color) _avatarColor(String letter, BuildContext context) {
    final code = letter.codeUnitAt(0);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final palette = [
      (AppColors.accentBlue, onSurface),
      (AppColors.accentGreen, onSurface),
      (AppColors.accentOrange, onSurface),
      (AppColors.accentPurple, onSurface),
      (Theme.of(context).colorScheme.surfaceContainerHighest, onSurface),
    ];
    return palette[code % palette.length];
  }
}

// ─── Link Content ─────────────────────────────────────────────────────────────

/// The central content column of the card: title, host URL, and the tags row.
class _LinkContent extends StatelessWidget {
  final LinkModel link;
  final String searchQuery;

  const _LinkContent({required this.link, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final host = _extractHost(link.url);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title: shows link.title if available, otherwise falls back to the
        // raw URL so the card always has a readable label.
        Text.rich(
          _highlightText(
            link.title.isNotEmpty ? link.title : link.url,
            searchQuery,
            Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
            context,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: AppSpacing.xs),
        // Host: the domain portion of the URL, styled in the primary color
        // as a subtle link indicator.
        Row(
          children: [
            Flexible(
              child: Text.rich(
                _highlightText(
                  host,
                  searchQuery,
                  Theme.of(context).textTheme.labelLarge!.copyWith(color: Theme.of(context).colorScheme.primary),
                  context,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            PriorityBadge(priority: link.priority),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        _TagsRow(link: link),
      ],
    );
  }

  /// Parses [url] and returns just the host component with "www." stripped.
  ///
  /// Returns the raw [url] string unchanged if parsing fails (e.g. the URL
  /// is malformed or empty) — this is safer than returning an empty string.
  String _extractHost(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}

// ─── Tags & Time Row ──────────────────────────────────────────────────────────

/// Displays the priority badge, up to 2 category chips, an optional
/// "not synced" indicator, and the relative timestamp — all in a single row.
class _TagsRow extends StatelessWidget {
  final LinkModel link;
  const _TagsRow({required this.link});

  @override
  Widget build(BuildContext context) {
    // Show time since the link was saved (createdAt), not syncedAt — the latter
    // is a server write timestamp that changes on every sync (e.g. marking a
    // link read), which would make the "x ago" label jump to "just now".
    final timeAgo = _formatTime(link.createdAt);

    return Row(
      children: [
        // Show at most 2 category chips to avoid overflowing the row.
        // Categories are localized via CategoryUtils.
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(link.categories.length, (index) {
                return Padding(
                  padding: EdgeInsetsDirectional.only(end: AppSpacing.xs),
                  child: _TagChip(label: CategoryUtils.getLocalizedCategory(context, link.categories[index])),
                );
              }),
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.xs),
        Text(timeAgo, style: AppTypography.caption),
        // "Cloud off" badge — shown when the link hasn’t been pushed to
        // Firestore yet. Subtle red tint signals unsynced state.
        if (!link.isSynced) ...[
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.shadowRose.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: AppColors.error, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [const Icon(Icons.cloud_off_rounded, size: 12, color: AppColors.error)],
            ),
          ),
        ],
      ],
    );
  }

  /// Converts a UTC epoch timestamp (milliseconds) to a human-readable
  /// relative string.
  String _formatTime(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toLocal();
    final diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

/// A small pill-shaped chip that displays a single category label.
///
/// Uses [AppTypography.caption] and `surfaceContainerHighest` background to
/// stay visually lightweight — these chips are secondary information and
/// should not distract from the title.
class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(label, style: AppTypography.caption),
    );
  }
}

// ─── More Menu ────────────────────────────────────────────────────────────────

/// The three-dot popup menu at the trailing edge of the card.
///
/// Renders nothing ([SizedBox.shrink]) when both [onEdit] and [onDelete] are
/// null — this keeps list-view-only contexts (e.g. search results) clean by
/// not showing an actionless menu button.
///
/// Deletion requires a user confirmation via [showConfirmationBottomSheet]
/// before [onDelete] is invoked, preventing accidental data loss.
class _MoreMenu extends StatelessWidget {
  final LinkModel link;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _MoreMenu({required this.link, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return NeoPopupMenu<String>(
      offset: const Offset(0, 30),
      onSelected: (action) async {
        if (action == 'copy') {
          await Clipboard.setData(ClipboardData(text: link.url));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link copied to clipboard')),
            );
          }
        } else if (action == 'share') {
          await SharePlus.instance.share(ShareParams(text: link.url));
        } else if (action == 'edit') {
          onEdit?.call();
        } else if (action == 'delete') {
          final confirm = await showConfirmationBottomSheet(
            context: context,
            title: context.l10n.linkDeleteTitle,
            message: context.l10n.linkDeleteMessage,
            confirmLabel: context.l10n.linkDeleteLabel,
            cancelLabel: context.l10n.accountCancel,
            titleIcon: Icons.warning_amber_rounded,
            isDestructive: true,
          );
          if (confirm == true) {
            onDelete?.call();
          }
        }
      },
      items: [
        const NeoPopupMenuItem(label: 'Copy URL', value: 'copy', icon: Icons.copy_rounded),
        const NeoPopupMenuItem(label: 'Share', value: 'share', icon: Icons.share_rounded),
        if (onEdit != null)
          NeoPopupMenuItem(label: context.l10n.linkEditLabel, value: 'edit', icon: Icons.edit_rounded),
        if (onDelete != null)
          NeoPopupMenuItem(
            label: context.l10n.linkDeleteLabel,
            value: 'delete',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
          ),
      ],
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8.0, top: 4.0, bottom: 4.0),
        child: Icon(Icons.more_vert_rounded, size: 20, color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}

/// Builds text spans for search highlighting without changing the source text.
///
/// Matching is case-insensitive and uses simple index lookup instead of a
/// regular expression. An empty query returns one normal span, so cards that
/// are not displayed through search retain their original appearance.
TextSpan _highlightText(String text, String query, TextStyle baseStyle, BuildContext context) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return TextSpan(text: text, style: baseStyle);

  final lowerText = text.toLowerCase();
  final highlightStyle = baseStyle.copyWith(
    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
    color: Theme.of(context).colorScheme.onSecondaryContainer,
  );
  final spans = <TextSpan>[];
  var searchStart = 0;

  while (searchStart < text.length) {
    final matchStart = lowerText.indexOf(normalizedQuery, searchStart);
    if (matchStart == -1) {
      spans.add(TextSpan(text: text.substring(searchStart), style: baseStyle));
      break;
    }
    if (matchStart > searchStart) {
      spans.add(TextSpan(text: text.substring(searchStart, matchStart), style: baseStyle));
    }
    final matchEnd = matchStart + normalizedQuery.length;
    spans.add(TextSpan(text: text.substring(matchStart, matchEnd), style: highlightStyle));
    searchStart = matchEnd;
  }

  return TextSpan(children: spans);
}

bool _isSvgUrl(String url) {
  final path = url.toLowerCase().split('?').first;
  return path.endsWith('.svg');
}
