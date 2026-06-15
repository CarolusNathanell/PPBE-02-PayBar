import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paybar_app/screens/home/nav_index.dart';
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
  int _currentIndex = NavIndex.beranda;

  final GlobalKey<NavigatorState> _grupNavKey = GlobalKey<NavigatorState>();

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
  }

  void _pushToGrup(Widget screen) {
    // Pastikan tab Grup aktif dulu
    if (_currentIndex != NavIndex.grup) {
      setState(() => _currentIndex = NavIndex.grup);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _grupNavKey.currentState?.push(
        MaterialPageRoute(builder: (_) => screen),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Screens didefinisikan di sini agar _grupNavKey bisa di-pass
    final screens = [
      DashboardScreen(
        onNavigateTo: _navigateTo,
        onPushToGrup: _pushToGrup,
        onLogout: AuthService().signOut,
      ),

      Navigator(
        key: _grupNavKey,
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => const GroupListScreen(),
        ),
      ),
      const ReminderScreen(),
      const NotificationInboxScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex == NavIndex.grup &&
            (_grupNavKey.currentState?.canPop() ?? false)) {
          _grupNavKey.currentState?.pop();
          return;
        }
        if (_currentIndex != NavIndex.beranda) {
          setState(() => _currentIndex = NavIndex.beranda);
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: PayBarNavBar(
          currentIndex: _currentIndex,
          onDestinationSelected: (i) {
            // Tombol Grup: pop ke root kalau user tap ulang tab yang sudah aktif
            if (i == NavIndex.grup &&
                _currentIndex == NavIndex.grup &&
                (_grupNavKey.currentState?.canPop() ?? false)) {
              _grupNavKey.currentState?.popUntil((r) => r.isFirst);
              return;
            }
            setState(() => _currentIndex = i);
          },
        ),
      ),
    );
  }
}