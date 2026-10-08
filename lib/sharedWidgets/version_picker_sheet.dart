import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_enums.dart';
import '../core/extensions/context_extension.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/locator.dart';
import '../features/links/manager/link_manager.dart';
import '../features/links/models/link_model.dart';
import 'custom_button.dart';

/// What the user picked in [showVersionPickerSheet].
typedef VersionChoice = ({String url, bool keepOnly});

/// Opens [link], first asking which version when it was saved under more than
/// one URL (e.g. once plain and once through a creator's affiliate link).
///
/// Links with a single URL open straight away, exactly as before. "Keep only
/// this one" makes the pick the link's only URL, then opens it. Used by every
/// in-app Open: LinkCard, Up Next and Today. The home-screen widget routes to
/// Today for these links, so it ends up here too.
Future<void> openLinkWithVersions(BuildContext context, LinkModel link) async {
  final manager = locator<LinkManager>();
  if (link.otherUrls.isEmpty) return manager.openLink(link);

  final choice = await showVersionPickerSheet(context, link);
  if (choice == null) return;
  if (choice.keepOnly) await manager.keepOnlyVersion(link, choice.url);
  await manager.openLink(link, url: choice.url);
}

/// Bottom sheet listing the link's main URL then its other versions. Each row
/// shows where it goes and which query parts it carries ("utm_source · cid"),
/// so an affiliate version is recognisable. Returns null when dismissed.
Future<VersionChoice?> showVersionPickerSheet(
  BuildContext context,
  LinkModel link,
) {
  return showModalBottomSheet<VersionChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: (_) => VersionPickerSheet(link: link),
  );
}

/// The sheet's content. Public so it can be widget-tested on its own.
class VersionPickerSheet extends StatefulWidget {
  final LinkModel link;

  const VersionPickerSheet({super.key, required this.link});

  @override
  State<VersionPickerSheet> createState() => _VersionPickerSheetState();
}

class _VersionPickerSheetState extends State<VersionPickerSheet> {
  late final List<String> _urls = [widget.link.url, ...widget.link.otherUrls];
  late String _selected = _urls.first;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.versionPickerTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: AppSpacing.sm),
            Flexible(
              child: SingleChildScrollView(
                child: RadioGroup<String>(
                  groupValue: _selected,
                  onChanged: (url) => setState(() => _selected = url!),
                  child: Column(
                    children: [
                      for (final url in _urls)
                        RadioListTile<String>(
                          key: ValueKey('version:$url'),
                          value: url,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _whereItGoes(url),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if (url == _urls.first)
                                context.l10n.versionPickerSavedFirst,
                              _queryKeys(url) ??
                                  context.l10n.versionPickerNoTracking,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            NeoBrutalistButton(
              key: const ValueKey('versionPickerOpen'),
              text: context.l10n.todayOpen,
              icon: Icons.open_in_new_rounded,
              onPressed: () =>
                  context.pop<VersionChoice>((url: _selected, keepOnly: false)),
            ),
            SizedBox(height: AppSpacing.sm),
            NeoBrutalistButton(
              key: const ValueKey('versionPickerKeepOnly'),
              text: context.l10n.versionPickerKeepOnly,
              variant: ButtonVariant.outlined,
              onPressed: () =>
                  context.pop<VersionChoice>((url: _selected, keepOnly: true)),
            ),
          ],
        ),
      ),
    );
  }

  /// Host and path without `www.`, scheme or query: "tatacliq.com/sennheiser-…".
  String _whereItGoes(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    final host = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
    return '$host${uri.path == '/' ? '' : uri.path}';
  }

  /// The query's keys, e.g. "utm_source · cid", or null when there are none.
  String? _queryKeys(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.query.isEmpty) return null;
    final keys = uri.queryParametersAll.keys.toList();
    return keys.isEmpty ? null : keys.join(' · ');
  }
}
