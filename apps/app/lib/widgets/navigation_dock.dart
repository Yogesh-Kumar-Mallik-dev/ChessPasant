import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

class NavigationDockItem {
  final String icon;
  final String label;

  const NavigationDockItem({required this.icon, required this.label});
}

class NavigationDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const NavigationDock({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  static const List<NavigationDockItem> items = [
    NavigationDockItem(icon: 'swords', label: 'Play'),
    NavigationDockItem(icon: 'zap', label: 'Online'),
    NavigationDockItem(icon: 'puzzle', label: 'Puzzles'),
    NavigationDockItem(icon: 'search', label: 'Analysis'),
    NavigationDockItem(icon: 'user', label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppColors.border,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      final isActive = currentIndex == index;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onTabSelected(index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.surfaceHover
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: isActive
                                  ? Border.all(
                                      color: AppColors.borderProminent,
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AppIcon(
                                  name: item.icon,
                                  size: 19,
                                  color: isActive
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isActive
                                        ? AppColors.textPrimary
                                        : AppColors.textMuted,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
