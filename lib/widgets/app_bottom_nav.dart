// Barra inferior reutilizada pelas áreas autenticadas do aplicativo.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Exibe atalhos para Home, Catálogo e Balcão.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.backgroundColor,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final Color? backgroundColor;

  static const _primaryColor = Color(0xFF4C3BCF);

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).extension<AppThemeColors>()!;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      color: backgroundColor,
      padding: EdgeInsets.fromLTRB(24, 0, 24, 14 + bottomPadding),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        decoration: BoxDecoration(
          color: themeColors.navSurface,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: themeColors.shadow.withValues(alpha: 0.45),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _AppBottomNavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              selected: selectedIndex == 0,
              onTap: () => onItemSelected(0),
            ),
            _AppBottomNavItem(
              icon: Icons.menu_book_outlined,
              label: 'Catálogo',
              selected: selectedIndex == 1,
              onTap: () => onItemSelected(1),
            ),
            _AppBottomNavItem(
              icon: Icons.swap_horiz,
              label: 'Balcão',
              selected: selectedIndex == 2,
              onTap: () => onItemSelected(2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item acessível da barra, com aparência diferente quando selecionado.
class _AppBottomNavItem extends StatelessWidget {
  const _AppBottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppBottomNav._primaryColor
        : Theme.of(context).colorScheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
