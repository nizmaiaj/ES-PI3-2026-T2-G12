import 'package:flutter/material.dart';

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
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 25),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
    final color = selected ? AppBottomNav._primaryColor : Colors.black87;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
