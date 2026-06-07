import 'package:flutter/material.dart';
import 'package:paybar_app/screens/home/nav_index.dart';
import 'package:paybar_app/screens/group/group_list_screen.dart';
import 'package:paybar_app/screens/notification/notification_inbox_screen.dart';
import 'package:paybar_app/screens/reminder/reminder_screen.dart';
import 'package:paybar_app/services/auth_service.dart';
import 'package:paybar_app/widgets/bottom_nav_bar.dart';
import 'package:paybar_app/screens/dashboard/dashboard_screen.dart';
import 'package:paybar_app/screens/home/nav_index.dart';

// ---------------------------------------------------------------------------
// HOME SCREEN — IndexedStack + NavigationBar
//
// Cara kerja navigasi dari quick action di Dashboard:
//   1. DashboardScreen menerima callback `onNavigateTo`.
//   2. Untuk tab switch (Grup, Reminder): panggil onNavigateTo(index).
//   3. Untuk push di atas tab Grup (mis. SettlementScreen):
//      panggil onNavigateTo(NavIndex.grup) terlebih dulu,
//      lalu push via groupNavigatorKey — nav bar tetap tampil.
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = NavIndex.beranda;

  // Navigator key untuk tab Grup — digunakan agar push dari Dashboard
  // tetap berada di dalam tab Grup dengan nav bar terlihat.
  final GlobalKey<NavigatorState> _grupNavKey = GlobalKey<NavigatorState>();

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
  }

  // Push screen di atas tab Grup sambil nav bar tetap tampil.
  // Dipanggil dari DashboardScreen melalui callback onPushToGrup.
  void _pushToGrup(Widget screen) {
    // Pastikan tab Grup aktif dulu
    if (_currentIndex != NavIndex.grup) {
      setState(() => _currentIndex = NavIndex.grup);
    }
    // Beri satu frame agar IndexedStack sudah render tab Grup
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

      // ── Tab 1: Grup — punya Navigator sendiri agar push tetap di dalam tab
      Navigator(
        key: _grupNavKey,
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => const GroupListScreen(),
        ),
      ),
      const ReminderScreen(),
      const NotificationInboxScreen(),
    ];

    return Scaffold(
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
    );
  }
}