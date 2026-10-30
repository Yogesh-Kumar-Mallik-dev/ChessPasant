import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Authentic SVG Icon Widget matching apps/web/src/lib/components/icons/Icon.svelte
class AppIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const AppIcon({
    super.key,
    required this.name,
    this.size = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color ?? Colors.white;
    final svgContent = _getSvgElements(name);

    final fullSvg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="${size.toInt()}" height="${size.toInt()}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$svgContent</svg>';

    return SvgPicture.string(
      fullSvg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
    );
  }

  static String _getSvgElements(String name) {
    switch (name) {
      case 'crown':
        return '<path d="M11.562 3.266a.5.5 0 0 1 .876 0L15.39 8.87a1 1 0 0 0 1.516.294L21.183 5.5a.5.5 0 0 1 .798.519l-2.834 10.77a2 2 0 0 1-1.936 1.491H6.789a2 2 0 0 1-1.936-1.49L2.019 6.02a.5.5 0 0 1 .798-.519l4.276 3.664a1 1 0 0 0 1.516-.294z" /><path d="M5 21h14" />';
      case 'bishop':
        return '<circle cx="12" cy="4" r="1.5" /><path d="M7 17.5c0-3 1.5-6 2.5-8.5a3.2 3.2 0 0 1 5 0c1 2.5 2.5 5.5 2.5 8.5" /><path d="m10 10.5 4 3.5" /><path d="M7 17.5l-1 3.5h12l-1-3.5Z" />';
      case 'menu':
        return '<line x1="4" x2="20" y1="6" y2="6" /><line x1="4" x2="20" y1="12" y2="12" /><line x1="4" x2="20" y1="18" y2="18" />';
      case 'sparkles':
        return '<path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275z" /><path d="M5 3v4" /><path d="M19 17v4" /><path d="M3 5h4" /><path d="M17 19h4" />';
      case 'swords':
        return '<polyline points="14.5 17.5 3 6 3 3 6 3 17.5 14.5" /><line x1="13" y1="19" x2="19" y2="13" /><line x1="16" y1="16" x2="20" y2="20" /><line x1="19" y1="21" x2="21" y2="19" /><polyline points="14.5 6.5 18 3 21 3 21 6 17.5 9.5" /><line x1="5" y1="14" x2="9" y2="18" /><line x1="7" y1="17" x2="4" y2="20" /><line x1="3" y1="19" x2="5" y2="21" />';
      case 'zap':
      case 'bolt':
        return '<polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" fill="currentColor" />';
      case 'flame':
        return '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 3.5z" />';
      case 'timer':
        return '<line x1="10" y1="2" x2="14" y2="2" /><line x1="12" y1="14" x2="15" y2="11" /><circle cx="12" cy="14" r="8" />';
      case 'clock':
        return '<circle cx="12" cy="12" r="10" /><polyline points="12 6 12 12 16 14" />';
      case 'hourglass':
        return '<path d="M5 22h14" /><path d="M5 2h14" /><path d="M17 22v-4.172a2 2 0 0 0-.586-1.414L12 12l-4.414 4.414A2 2 0 0 0 7 17.828V22" /><path d="M7 2v4.172a2 2 0 0 0 .586 1.414L12 12l4.414-4.414A2 2 0 0 0 17 6.172V2" />';
      case 'trophy':
        return '<path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6" /><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18" /><path d="M4 22h16" /><path d="M10 14.66V17c0 .55-.45 1-1 1H7c-.55 0-1-.45-1-1v-2.34" /><path d="M14 14.66V17c0 .55.45 1 1 1h2c.55 0 1-.45 1-1v-2.34" /><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z" />';
      case 'shield':
        return '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />';
      case 'rotate-cw':
      case 'refresh-cw':
        return '<path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8" /><polyline points="21 3 21 8 16 8" />';
      case 'rotate-ccw':
        return '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" /><polyline points="3 3 3 8 8 8" />';
      case 'puzzle':
        return '<path d="M19.439 7.85c-.049-.322-.059-.659-.059-1a4 4 0 0 0-4-4c-1.396 0-2.617.712-3.327 1.792A4.004 4.004 0 0 0 8 3a4 4 0 0 0-4 4c0 .341.01.678.059 1A4.004 4.004 0 0 0 3 11a4 4 0 0 0 4 4c.341 0 .678-.01 1-.059A4.004 4.004 0 0 0 11 17a4 4 0 0 0 4-4c.341 0 .678-.01 1-.059A4.004 4.004 0 0 0 19 11a4 4 0 0 0-4-4c0-.341.01-.678.059-1A4.004 4.004 0 0 0 19.439 7.85z" />';
      case 'search':
        return '<circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />';
      case 'user':
        return '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" /><circle cx="12" cy="7" r="4" />';
      case 'users':
        return '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M22 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />';
      case 'flag':
        return '<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z" /><line x1="4" y1="22" x2="4" y2="15" />';
      case 'handshake':
        return '<path d="m11 17 2 2a1 1 0 0 0 1.4 0l4.3-4.3a1 1 0 0 0 0-1.4l-2-2" /><path d="m18 10 1.3-1.3a2.5 2.5 0 0 0 0-3.5v0a2.5 2.5 0 0 0-3.5 0L14 7" /><path d="m6 18 1.3-1.3a2.5 2.5 0 0 0 0-3.5v0a2.5 2.5 0 0 0-3.5 0L2 15" /><path d="m8 14 3-3" />';
      case 'play':
        return '<polygon points="5 3 19 12 5 21 5 3" fill="currentColor" />';
      case 'arrow-right':
        return '<line x1="5" y1="12" x2="19" y2="12" /><polyline points="12 5 19 12 12 19" />';
      case 'chevron-right':
        return '<polyline points="9 18 15 12 9 6" />';
      case 'chevron-left':
        return '<polyline points="15 18 9 12 15 6" />';
      case 'chevrons-right':
        return '<polyline points="13 17 18 12 13 7" /><polyline points="6 17 11 12 6 7" />';
      case 'chevrons-left':
        return '<polyline points="11 17 6 12 11 7" /><polyline points="18 17 13 12 18 7" />';
      case 'log-out':
        return '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" /><polyline points="16 17 21 12 16 7" /><line x1="21" y1="12" x2="9" y2="12" />';
      case 'check':
        return '<polyline points="20 6 9 17 4 12" />';
      case 'x':
        return '<line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />';
      case 'settings':
        return '<circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" />';
      case 'volume-2':
        return '<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" /><path d="M15.54 8.46a5 5 0 0 1 0 7.07" /><path d="M19.07 4.93a10 10 0 0 1 0 14.14" />';
      case 'volume-x':
        return '<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" /><line x1="22" y1="9" x2="16" y2="15" /><line x1="16" y1="9" x2="22" y2="15" />';
      case 'download':
        return '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" /><polyline points="7 10 12 15 17 10" /><line x1="12" y1="15" x2="12" y2="3" />';
      case 'smart_toy':
      case 'bot':
        return '<rect width="18" height="12" x="3" y="6" rx="2" /><circle cx="9" cy="12" r="1.5" /><circle cx="15" cy="12" r="1.5" /><path d="M12 2v4" /><path d="M2 12h1" /><path d="M21 12h1" />';
      default:
        return '<circle cx="12" cy="12" r="10" />';
    }
  }
}
