import 'package:flutter/material.dart';
import 'package:paybar_app/core/theme/app_colors.dart';
import 'package:paybar_app/models/notification_model.dart';
import 'package:paybar_app/services/notification_service.dart';

class PayBarNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const PayBarNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  State<PayBarNavBar> createState() => _PayBarNavBarState();
}

class _PayBarNavBarState extends State<PayBarNavBar> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    NotificationService().getNotifications().listen((notifications) {
      if (mounted) {
        setState(() {
          _unreadCount = notifications.where((n) => !n.isRead).length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: widget.currentIndex,
      onDestinationSelected: widget.onDestinationSelected,
      backgroundColor: AppColors.white,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
          label: 'Beranda',
        ),
        const NavigationDestination(
          icon: Icon(Icons.group_outlined),
          selectedIcon: Icon(Icons.group_rounded, color: AppColors.primary),
          label: 'Grup',
        ),
        const NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon:
              Icon(Icons.notifications_rounded, color: AppColors.primary),
          label: 'Reminder',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: _unreadCount > 0,
            label: Text('$_unreadCount'),
            child: const Icon(Icons.inbox_outlined),
          ),
          selectedIcon:
              const Icon(Icons.inbox_rounded, color: AppColors.primary),
          label: 'Notifikasi',
        ),
      ],
    );
  }
}