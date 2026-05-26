import 'package:flutter/material.dart';
import 'package:paybar_app/core/theme/app_colors.dart';
import 'package:paybar_app/core/theme/app_typography.dart';
import 'package:paybar_app/services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('PayBar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () => authService.signOut(),
            // signOut() memicu authStateChanges → StreamBuilder di main.dart
            // otomatis kembali ke LoginScreen
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
                  Icons.construction_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Aplikasi sedang dalam\nproses pengembangan',
                style: AppTypography.h2.copyWith(height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Fitur akan segera hadir',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
