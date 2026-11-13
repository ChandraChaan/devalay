import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/favorites.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/theme.dart';

class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.radius = 0, this.color, this.alignment});
  final String url;
  final BoxFit fit;
  final double radius;
  final Color? color;
  final Alignment? alignment;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (color ?? Palette.marigold).withValues(alpha: 0.35),
            (color ?? Palette.saffron).withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Text('ॐ', style: TextStyle(fontSize: 32, color: Colors.white70)),
      ),
    );
    final image = url.isEmpty
        ? placeholder
        : CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            alignment: alignment ?? Alignment.topCenter,
            fadeInDuration: const Duration(milliseconds: 250),
            // Wikimedia asks clients to identify themselves.
            httpHeaders: const {'User-Agent': 'Devalay/1.0 (https://github.com/ChandraChaan/devalay)'},
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );
    return radius == 0 ? image : ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Shimmering placeholder used while content loads.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 120, this.width, this.radius = 20});
  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(radius)),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1400.ms, color: Colors.white.withValues(alpha: 0.25));
  }
}

class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.count = 6, this.height = 72});
  final int count;
  final double height;
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: count,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (_, _) => SkeletonBox(height: height),
  );
}

class ErrorRetry extends ConsumerWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = error is ApiException && (error as ApiException).isOffline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(offline ? tr(ref, 'error') : '$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: Text(tr(ref, 'retry'))),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    ),
  );
}

class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.colors,
    required this.child,
    this.onTap,
    this.padding = 20,
    this.radius = 24,
  });
  final List<Color> colors;
  final Widget child;
  final VoidCallback? onTap;
  final double padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(color: colors.last.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: EdgeInsets.all(padding), child: child),
        ),
      ),
    );
  }
}

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.item, this.color});
  final FavoriteItem item;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = ref.watch(favoritesProvider.select((m) => m.containsKey(item.key)));
    return IconButton(
      tooltip: t3(appLang, 'Favourite', 'पसंदीदा', 'ఇష్టమైనది'),
      onPressed: () => ref.read(favoritesProvider.notifier).toggle(item),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: Icon(
          fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(fav),
          color: fav ? Palette.vermilion : color,
        ),
      ),
    );
  }
}

/// Credit line for public-domain or Creative Commons media, linking to the source.
class Attribution extends StatelessWidget {
  const Attribution(this.item, {super.key, this.light = false});
  final Licensed item;
  final bool light;

  @override
  Widget build(BuildContext context) {
    if (item.attribution.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: light ? Colors.white70 : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    );
    return InkWell(
      onTap: item.sourceUrl.isEmpty
          ? null
          : () => launchUrl(Uri.parse(item.sourceUrl), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copyright_rounded, size: 14, color: style?.color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(item.attribution, style: style, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

String hhmm(String iso) {
  // Times from the API carry the city's UTC offset; show the wall-clock part.
  if (iso.length < 16 || DateTime.tryParse(iso) == null) return '--';
  final local = iso.substring(11, 16);
  final h = int.parse(local.substring(0, 2));
  final m = local.substring(3, 5);
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m $suffix';
}

/// A label's font size, a little smaller when one word is long enough to break mid-word in a
/// narrow tile (Tamil, Malayalam and Kannada compound words).
double labelSize(String label, double base) {
  final longest = label.split(RegExp(r'\s+')).fold<int>(0, (m, w) => w.runes.length > m ? w.runes.length : m);
  if (longest > 12) return base - 3;
  if (longest > 9) return base - 2;
  return base;
}

/// A tile caption: one long word shrinks to fit instead of breaking mid-word; longer captions
/// wrap to two lines.
class TileLabel extends StatelessWidget {
  const TileLabel(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (!text.trim().contains(' ')) {
      // Full size unless the word is wider than the tile.
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, textAlign: TextAlign.center, style: style),
      );
    }
    final sized = style.copyWith(fontSize: labelSize(text, style.fontSize ?? 14));
    return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: sized);
  }
}
