import 'package:flutter/material.dart';
import 'package:paybar_app/core/theme/app_colors.dart';
import 'package:paybar_app/core/theme/app_typography.dart';
import 'package:paybar_app/screens/group/group_list_screen.dart';
import 'package:paybar_app/screens/notification/notification_inbox_screen.dart';
import 'package:paybar_app/screens/reminder/reminder_screen.dart';
import 'package:paybar_app/services/auth_service.dart';
import 'package:paybar_app/widgets/bottom_nav_bar.dart';
import 'package:paybar_app/screens/dashboard/dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Tiap tab punya Scaffold sendiri — HomeScreen hanya menyediakan
  // IndexedStack + NavigationBar tanpa AppBar tambahan
  late final List<Widget> _screens = [
    const DashboardScreen(),
    // _BerandaTab(onLogout: AuthService().signOut),
    const GroupListScreen(),
    const ReminderScreen(),
    const NotificationInboxScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: PayBarNavBar(
        currentIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// Tab Beranda: placeholder sampai fitur Dashboard (Orang 2) selesai
class _BerandaTab extends StatelessWidget {
  final Future<void> Function() onLogout;
  const _BerandaTab({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PayBar'),
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: onLogout,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.dashboard_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Dashboard segera hadir',
                style: AppTypography.h2.copyWith(height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ringkasan hutang-piutang akan tampil di sini.',
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
