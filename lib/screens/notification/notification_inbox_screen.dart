import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paybar_app/core/theme/app_colors.dart';
import 'package:paybar_app/core/theme/app_typography.dart';
import 'package:paybar_app/models/notification_model.dart';
import 'package:paybar_app/services/notification_service.dart';

class NotificationInboxScreen extends StatelessWidget {
  const NotificationInboxScreen({super.key});

  // konfirmasi hapus semua
  void _confirmClearAll(
      BuildContext context, NotificationService service) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.negative.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_sweep_rounded,
                  color: AppColors.negative, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Hapus Semua?', style: AppTypography.h2),
            ),
          ],
        ),
        content: Text(
          'Semua histori notifikasi akan dihapus permanen. Aksi ini nggak bisa di-undo ya.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await service.deleteAllNotifications();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Semua notifikasi dihapus'),
                    backgroundColor: const Color(0xFF1A2A3A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Notifikasi', style: AppTypography.h2),
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: service.getNotifications(),
            builder: (context, snapshot) {
              final notifications = snapshot.data ?? [];
              final hasUnread = notifications.any((n) => !n.isRead);
              final hasAny = notifications.isNotEmpty;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tandai semua dibaca
                  if (hasUnread)
                    TextButton.icon(
                      onPressed: () async {
                        await service.markAllAsRead();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Semua notifikasi ditandai dibaca'),
                              backgroundColor: const Color(0xFF1A2A3A),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: const Text('Baca Semua'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),

                  // Hapus semua
                  if (hasAny)
                    IconButton(
                      onPressed: () =>
                          _confirmClearAll(context, service),
                      icon: const Icon(Icons.delete_sweep_rounded),
                      color: AppColors.negative,
                      tooltip: 'Hapus semua notifikasi',
                    ),

                  const SizedBox(width: 4),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: service.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: () {});
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const _EmptyState();
          }

          final unreadCount = notifications.where((n) => !n.isRead).length;

          return Column(
            children: [
              // Unread badge bar
              if (unreadCount > 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00B8A9), Color(0xFF4ECDC4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                            Icons.notifications_active_rounded,
                            color: Colors.white,
                            size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$unreadCount notifikasi belum dibaca',
                        style: AppTypography.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              // Petunjuk swipe hapus
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.swipe_left_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Geser kiri untuk hapus notifikasi',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              // List notifikasi
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: notifications.length,
                  itemBuilder: (ctx, i) => _NotificationCard(
                    notification: notifications[i],
                    onTap: () async {
                      if (!notifications[i].isRead) {
                        await service.markAsRead(notifications[i].id);
                      }
                    },
                    onDelete: () async {
                      await service
                          .deleteNotification(notifications[i].id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Notifikasi dihapus'),
                            backgroundColor: const Color(0xFF1A2A3A),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Notification card
class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  Color get _typeColor {
    switch (notification.type) {
      case NotificationType.transaction:
        return AppColors.primary;
      case NotificationType.settlement:
        return AppColors.positive;
      case NotificationType.reminder:
        return const Color(0xFFFFD93D);
      case NotificationType.general:
        return AppColors.textSecondary;
    }
  }

  IconData get _typeIcon {
    switch (notification.type) {
      case NotificationType.transaction:
        return Icons.receipt_long_rounded;
      case NotificationType.settlement:
        return Icons.payments_rounded;
      case NotificationType.reminder:
        return Icons.alarm_rounded;
      case NotificationType.general:
        return Icons.notifications_rounded;
    }
  }

  String get _typeLabel {
    switch (notification.type) {
      case NotificationType.transaction:
        return 'Transaksi';
      case NotificationType.settlement:
        return 'Settlement';
      case NotificationType.reminder:
        return 'Pengingat';
      case NotificationType.general:
        return 'Info';
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.negative,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 24),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isUnread
                ? AppColors.primary.withValues(alpha: 0.04)
                : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.border,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A2A3A).withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon, color: _typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _typeLabel,
                              style: AppTypography.caption.copyWith(
                                color: _typeColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTime(notification.createdAt),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.title,
                        style: AppTypography.body.copyWith(
                          fontWeight: isUnread
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isUnread) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Empty state
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF4ECDC4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  size: 52, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text('Belum ada notifikasi',
                style: AppTypography.h1, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Semua aktivitas grup dan pengingat\nakan muncul di sini.',
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Error state 
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 48, color: AppColors.negative),
          const SizedBox(height: 16),
          Text('Aduh, ada gangguan.', style: AppTypography.h2),
          const SizedBox(height: 8),
          Text('Coba lagi ya.',
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}