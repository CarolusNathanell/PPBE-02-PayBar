import 'package:flutter/material.dart';
import 'package:paybar_app/core/theme/app_colors.dart';

class PayBarNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const PayBarNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: AppColors.white,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.group_outlined),
          selectedIcon: Icon(Icons.group_rounded, color: AppColors.primary),
          label: 'Grup',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon:
              Icon(Icons.notifications_rounded, color: AppColors.primary),
          label: 'Reminder',
        ),
      ],
    );
  }
}
