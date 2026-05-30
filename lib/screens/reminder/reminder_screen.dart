import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paybar_app/core/theme/app_colors.dart';
import 'package:paybar_app/core/theme/app_typography.dart';
import 'package:paybar_app/models/reminder_model.dart';
import 'package:paybar_app/services/reminder_service.dart';
import 'package:paybar_app/services/notification_service.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final _reminderService = ReminderService();

  void _showAddEditSheet({ReminderModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReminderFormSheet(
        existing: existing,
        onSave: (reminder) async {
          if (existing == null) {
            await _reminderService.addReminder(reminder);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text('Pengingat ditambahkan! 🔔'),
                    ],
                  ),
                  backgroundColor: const Color(0xFF1A2A3A),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
              await NotificationService().showLocalNotification(
                title: 'Pengingat Baru',
                body:
                    '${reminder.title} — ${DateFormat('dd MMM yyyy').format(reminder.dueDate)}',
              );
            }
          } else {
            await _reminderService.updateReminder(reminder);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Pengingat diperbarui!'),
                  backgroundColor: const Color(0xFF1A2A3A),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _confirmDelete(ReminderModel reminder) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.negative.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_outline_rounded,
                  color: AppColors.negative, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Hapus Pengingat?', style: AppTypography.h2),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            children: [
              const TextSpan(text: 'Yakin mau hapus '),
              TextSpan(
                text: '"${reminder.title}"',
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '? Aksi ini nggak bisa di-undo ya.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _reminderService.deleteReminder(reminder.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Pengingat dihapus.'),
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
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // AppBar
      appBar: AppBar(
        title: Text('Pengingat', style: AppTypography.h2),
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => _showAddEditSheet(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ),
        ],
      ),
      // Body
      body: StreamBuilder<List<ReminderModel>>(
        stream: _reminderService.getReminders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: () => setState(() {}));
          }

          final reminders = snapshot.data ?? [];

          if (reminders.isEmpty) {
            return _EmptyState(onAdd: () => _showAddEditSheet());
          }

          final pending = reminders.where((r) => !r.isDone).toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
          final done = reminders.where((r) => r.isDone).toList()
            ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

          // Stats bar
          final overdueCount =
              pending.where((r) => r.dueDate.isBefore(DateTime.now())).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Stats mini banner
              if (reminders.isNotEmpty)
                _StatsBanner(
                  pendingCount: pending.length,
                  doneCount: done.length,
                  overdueCount: overdueCount,
                ),

              if (pending.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionHeader(
                  label: 'Belum Selesai',
                  count: pending.length,
                  color: AppColors.primary,
                  icon: Icons.pending_actions_rounded,
                ),
                const SizedBox(height: 10),
                ...pending.asMap().entries.map(
                      (e) => _ReminderCard(
                        reminder: e.value,
                        index: e.key,
                        onToggle: (val) =>
                            _reminderService.toggleDone(e.value.id, val),
                        onEdit: () => _showAddEditSheet(existing: e.value),
                        onDelete: () => _confirmDelete(e.value),
                      ),
                    ),
              ],

              if (done.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionHeader(
                  label: 'Sudah Selesai',
                  count: done.length,
                  color: AppColors.textSecondary,
                  icon: Icons.task_alt_rounded,
                ),
                const SizedBox(height: 10),
                ...done.asMap().entries.map(
                      (e) => _ReminderCard(
                        reminder: e.value,
                        index: e.key,
                        onToggle: (val) =>
                            _reminderService.toggleDone(e.value.id, val),
                        onEdit: () => _showAddEditSheet(existing: e.value),
                        onDelete: () => _confirmDelete(e.value),
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// Stats Banner
class _StatsBanner extends StatelessWidget {
  final int pendingCount;
  final int doneCount;
  final int overdueCount;

  const _StatsBanner({
    required this.pendingCount,
    required this.doneCount,
    required this.overdueCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00B8A9), Color(0xFF00D4C3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B8A9).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: 'Aktif',
              value: '$pendingCount',
              icon: Icons.notifications_active_rounded,
              light: true,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _StatItem(
              label: 'Selesai',
              value: '$doneCount',
              icon: Icons.check_circle_outline_rounded,
              light: true,
            ),
          ),
          if (overdueCount > 0) ...[
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            Expanded(
              child: _StatItem(
                label: 'Terlambat',
                value: '$overdueCount',
                icon: Icons.warning_amber_rounded,
                light: true,
                isWarning: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool light;
  final bool isWarning;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.light = false,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = light
        ? (isWarning ? const Color(0xFFFFD93D) : Colors.white)
        : AppColors.primary;
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Section Header
class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

// Reminder Card
class _ReminderCard extends StatelessWidget {
  final ReminderModel reminder;
  final int index;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReminderCard({
    required this.reminder,
    required this.index,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  bool get _isOverdue =>
      !reminder.isDone && reminder.dueDate.isBefore(DateTime.now());

  Color get _accentColor {
    if (_isOverdue) return AppColors.negative;
    if (reminder.isDone) return AppColors.textSecondary;
    final colors = [
      AppColors.primary,
      const Color(0xFF4ECDC4),
      const Color(0xFFFFD93D),
      const Color(0xFF6C63FF),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isOverdue
              ? AppColors.negative.withValues(alpha: 0.35)
              : AppColors.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2A3A).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Colored left accent bar
              Container(
                width: 4,
                color: reminder.isDone
                    ? AppColors.border
                    : _accentColor.withValues(alpha: 0.7),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Checkbox
                      GestureDetector(
                        onTap: () => onToggle(!reminder.isDone),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: reminder.isDone
                                ? AppColors.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: reminder.isDone
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: reminder.isDone
                              ? const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder.title,
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: reminder.isDone
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                                decoration: reminder.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _isOverdue
                                        ? AppColors.negative
                                            .withValues(alpha: 0.1)
                                        : reminder.isDone
                                            ? AppColors.border
                                                .withValues(alpha: 0.5)
                                            : _accentColor
                                                .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isOverdue
                                            ? Icons.warning_amber_rounded
                                            : Icons.calendar_today_rounded,
                                        size: 11,
                                        color: _isOverdue
                                            ? AppColors.negative
                                            : reminder.isDone
                                                ? AppColors.textSecondary
                                                : _accentColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isOverdue
                                            ? 'Terlambat · ${DateFormat('dd MMM').format(reminder.dueDate)}'
                                            : DateFormat('dd MMM yyyy')
                                                .format(reminder.dueDate),
                                        style: AppTypography.caption.copyWith(
                                          color: _isOverdue
                                              ? AppColors.negative
                                              : reminder.isDone
                                                  ? AppColors.textSecondary
                                                  : _accentColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Menu button
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded,
                            color: AppColors.textSecondary, size: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.edit_rounded,
                                      size: 14, color: AppColors.primary),
                                ),
                                const SizedBox(width: 10),
                                Text('Edit', style: AppTypography.body),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.negative
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(Icons.delete_rounded,
                                      size: 14, color: AppColors.negative),
                                ),
                                const SizedBox(width: 10),
                                Text('Hapus',
                                    style: AppTypography.body
                                        .copyWith(color: AppColors.negative)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (val) {
                          if (val == 'edit') onEdit();
                          if (val == 'delete') onDelete();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Empty State
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

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
                  colors: [Color(0xFF00B8A9), Color(0xFF4ECDC4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00B8A9).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 52,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Belum ada pengingat',
              style: AppTypography.h1.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Tambahkan pengingat biar nggak lupa tagihan kamu!',
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah Pengingat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Error State
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.negative.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded,
                  size: 40, color: AppColors.negative),
            ),
            const SizedBox(height: 20),
            Text('Aduh, ada gangguan.', style: AppTypography.h2),
            const SizedBox(height: 8),
            Text(
              'Coba lagi ya.',
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Form Bottom Sheet
class _ReminderFormSheet extends StatefulWidget {
  final ReminderModel? existing;
  final Future<void> Function(ReminderModel) onSave;

  const _ReminderFormSheet({this.existing, required this.onSave});

  @override
  State<_ReminderFormSheet> createState() => _ReminderFormSheetState();
}

class _ReminderFormSheetState extends State<_ReminderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _titleController.text = widget.existing!.title;
      _selectedDate = widget.existing!.dueDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(DateTime.now())
          ? DateTime.now()
          : _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final reminder = ReminderModel(
        id: widget.existing?.id ?? '',
        title: _titleController.text.trim(),
        dueDate: _selectedDate,
        groupId: widget.existing?.groupId,
        isDone: widget.existing?.isDone ?? false,
      );

      await widget.onSave(reminder);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Aduh, ada gangguan. Coba lagi ya.'),
            backgroundColor: AppColors.negative,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00B8A9), Color(0xFF4ECDC4)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isEdit
                        ? Icons.edit_notifications_rounded
                        : Icons.add_alert_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Pengingat' : 'Tambah Pengingat',
                    style: AppTypography.h2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Title field
            Text(
              'Judul',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Contoh: Bayar tagihan listrik',
                prefixIcon: const Icon(Icons.title_rounded,
                    color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.border, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.negative, width: 1.5),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Judul nggak boleh kosong ya';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date picker
            Text(
              'Tanggal Jatuh Tempo',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
                            .format(_selectedDate),
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.5),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        isEdit ? 'Simpan Perubahan' : 'Tambah Pengingat',
                        style: AppTypography.button,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
