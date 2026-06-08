import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paybar_app/core/theme/app_colors.dart';
import 'package:paybar_app/core/theme/app_typography.dart';
import 'package:paybar_app/models/group_model.dart';
import 'package:paybar_app/models/transaction_model.dart';
import 'package:paybar_app/services/currency_service.dart';
import 'package:paybar_app/services/group_service.dart';
import 'package:paybar_app/services/transaction_service.dart';
import 'package:paybar_app/screens/transaction/transaction_screen.dart';
import 'package:paybar_app/screens/settlement/settlement_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _groupService = GroupService();
  final _txService = TransactionService();
  Map<String, String> _memberNames = {};
  List<String> _lastMemberIds = [];

  // Reload nama anggota hanya jika daftar member berubah
  void _refreshMemberNamesIfNeeded(List<String> currentIds) {
    final sorted = List<String>.from(currentIds)..sort();
    final lastSorted = List<String>.from(_lastMemberIds)..sort();
    if (sorted.join() == lastSorted.join()) return;

    _lastMemberIds = List.from(currentIds);
    _groupService.getMemberNames(currentIds).then((names) {
      if (mounted) setState(() => _memberNames = names);
    });
  }

  void _openTransactionForm(BuildContext context, {TransactionModel? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionScreen(
          groupId: widget.groupId,
          memberNames: _memberNames,
          currentUserUid: FirebaseAuth.instance.currentUser!.uid,
          existing: existing,
        ),
      ),
    );
  }

  void _openSettlementScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettlementScreen(
          groupId: widget.groupId,
          memberNames: _memberNames,
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, GroupModel group) {
    final controller = TextEditingController(text: group.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        title: Text('Edit Nama Grup', style: AppTypography.h2),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nama baru'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await _groupService.updateGroupName(
                  widget.groupId, controller.text);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => _InviteDialog(
        onInvite: (email) => _groupService.inviteMember(widget.groupId, email),
        emailController: controller,
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teman berhasil diundang! 🎉')),
          );
          // Reload member names setelah invite
          _lastMemberIds = [];
        },
      ),
    );
  }

  void _confirmLeave(BuildContext context, GroupModel group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        title: Text('Keluar dari Grup?', style: AppTypography.h2),
        content: Text(
          group.members.length <= 1
              ? 'Kamu satu-satunya anggota. Grup ini akan dihapus permanen.'
              : 'Kamu akan keluar dari "${group.name}". Transaksi tetap tersimpan.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _groupService.leaveOrDeleteGroup(widget.groupId);
              if (context.mounted) Navigator.pop(context);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.negative),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, GroupModel group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        title: Text('Hapus Grup?', style: AppTypography.h2),
        content: Text(
          '"${group.name}" akan dihapus permanen. Semua anggota tidak bisa mengakses grup ini lagi.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _groupService.deleteGroup(widget.groupId);
              if (context.mounted) Navigator.pop(context);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.negative),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTransaction(BuildContext context, TransactionModel tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        title: Text('Hapus Transaksi?', style: AppTypography.h2),
        content: RichText(
          text: TextSpan(
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            children: [
              const TextSpan(text: 'Hapus transaksi '),
              TextSpan(
                text: '"${tx.description}"',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const TextSpan(text: '? Aksi ini nggak bisa di-undo.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _txService.deleteTransaction(widget.groupId, tx.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaksi dihapus.')),
                );
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.negative),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: (value == 'leave' || value == 'delete_group')
                  ? AppColors.negative
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<GroupModel>(
      stream: _groupService.getGroupById(widget.groupId),
      builder: (context, groupSnap) {
        if (!groupSnap.hasData) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: AppColors.white,
              leading: const BackButton(),
            ),
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final group = groupSnap.data!;

        // Reload member names jika daftar anggota berubah
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _refreshMemberNamesIfNeeded(group.members);
        });

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.white,
            elevation: 0,
            scrolledUnderElevation: 1,
            leading: const BackButton(),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: AppTypography.h2),
                Text(
                  '${group.members.length} anggota',
                  style: AppTypography.caption,
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  switch (val) {
                    case 'edit':
                      _showEditNameDialog(context, group);
                    case 'invite':
                      _showInviteDialog(context);
                    case 'leave':
                      _confirmLeave(context, group);
                    case 'delete_group':
                      _confirmDeleteGroup(context, group);
                  }
                },
                itemBuilder: (_) => [
                  _menuItem('edit', Icons.edit_rounded, 'Edit Nama Grup',
                      AppColors.primary),
                  _menuItem('invite', Icons.person_add_rounded,
                      'Undang Anggota', AppColors.positive),
                  _menuItem('leave', Icons.logout_rounded, 'Keluar Grup',
                      AppColors.negative),
                  if (group.isCreator(currentUid))
                    _menuItem('delete_group', Icons.delete_rounded,
                        'Hapus Grup', AppColors.negative),
                ],
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              // Tombol Pelunasan
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  color: AppColors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: ElevatedButton.icon(
                    onPressed: () => _openSettlementScreen(context),
                    icon: const Icon(Icons.handshake_rounded, size: 18),
                    label: const Text('Pelunasan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.positive,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

              // Anggota
              SliverToBoxAdapter(
                child: _MembersSection(
                  group: group,
                  memberNames: _memberNames,
                  onInvite: () => _showInviteDialog(context),
                ),
              ),

              // Header transaksi
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Text('Transaksi', style: AppTypography.h2),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _openTransactionForm(context),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Tambah'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Daftar transaksi (realtime)
              StreamBuilder<List<TransactionModel>>(
                stream: _txService.getTransactions(widget.groupId),
                builder: (ctx, txSnap) {
                  if (txSnap.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        ),
                      ),
                    );
                  }

                  final transactions = txSnap.data ?? [];

                  if (transactions.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _EmptyTransactions(
                        onAdd: () => _openTransactionForm(context),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _TransactionCard(
                          tx: transactions[i],
                          memberNames: _memberNames,
                          index: i,
                          onEdit: () => _openTransactionForm(context,
                              existing: transactions[i]),
                          onDelete: () =>
                              _confirmDeleteTransaction(context, transactions[i]),
                        ),
                        childCount: transactions.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openTransactionForm(context),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add_rounded, color: AppColors.white),
          ),
        );
      },
    );
  }
}

// ── Members Section ──────────────────────────────────────────────────────────

class _MembersSection extends StatelessWidget {
  final GroupModel group;
  final Map<String, String> memberNames;
  final VoidCallback onInvite;

  const _MembersSection({
    required this.group,
    required this.memberNames,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Anggota',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${group.members.length}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...group.members.map((uid) {
                final name = memberNames[uid] ?? '...';
                final isCreator = group.isCreator(uid);
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  label: Text(name),
                  labelStyle: AppTypography.body.copyWith(
                    fontWeight:
                        isCreator ? FontWeight.w600 : FontWeight.w400,
                  ),
                  backgroundColor: isCreator
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : AppColors.background,
                  side: BorderSide(
                    color: isCreator
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.person_add_outlined,
                    size: 16, color: AppColors.primary),
                label: const Text('Undang'),
                labelStyle: AppTypography.body
                    .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                backgroundColor: AppColors.primary.withValues(alpha: 0.06),
                side:
                    const BorderSide(color: AppColors.primary, width: 0.8),
                onPressed: onInvite,
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(height: 20),
        ],
      ),
    );
  }
}

// ── Transaction Card ─────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final TransactionModel tx;
  final Map<String, String> memberNames;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TransactionCard({
    required this.tx,
    required this.memberNames,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  static const _accentColors = [
    AppColors.primary,
    Color(0xFF6C63FF),
    AppColors.accent,
    AppColors.positive,
    Color(0xFFFF9A3C),
  ];

  Color get _accent => _accentColors[index % _accentColors.length];

  @override
  Widget build(BuildContext context) {
    final paidByName = memberNames[tx.paidBy] ?? 'Seseorang';
    final dateStr = DateFormat('dd MMM yyyy').format(tx.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2A3A).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 4,
                color: _accent,
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                            Icon(Icons.receipt_long_rounded, color: _accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      // Description + meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.description,
                              style: AppTypography.body
                                  .copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$paidByName bayar · $dateStr',
                              style: AppTypography.caption,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${tx.participants.length} orang · per org: '
                              '${CurrencyService.formatCurrency(tx.perPerson, tx.currency)}',
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Amount + menu
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyService.formatCurrency(
                                tx.amount, tx.currency),
                            style: AppTypography.nominal
                                .copyWith(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded,
                                size: 18, color: AppColors.textSecondary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.edit_rounded,
                                        size: 14, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Edit', style: AppTypography.body),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.negative
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Icon(Icons.delete_rounded,
                                        size: 14, color: AppColors.negative),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Hapus',
                                      style: AppTypography.body.copyWith(
                                          color: AppColors.negative)),
                                ]),
                              ),
                            ],
                            onSelected: (val) {
                              if (val == 'edit') onEdit();
                              if (val == 'delete') onDelete();
                            },
                          ),
                        ],
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

// ── Empty Transactions ───────────────────────────────────────────────────────

class _EmptyTransactions extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTransactions({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('Belum ada transaksi',
              style: AppTypography.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Tambah transaksi pertama untuk\nmulai catat patungan!',
            style:
                AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah Transaksi'),
          ),
        ],
      ),
    );
  }
}

// ── Invite Dialog ────────────────────────────────────────────────────────────

class _InviteDialog extends StatefulWidget {
  final Future<void> Function(String email) onInvite;
  final TextEditingController emailController;
  final VoidCallback onSuccess;

  const _InviteDialog({
    required this.onInvite,
    required this.emailController,
    required this.onSuccess,
  });

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.white,
      title: Text('Undang Anggota', style: AppTypography.h2),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Masukkan email teman yang sudah daftar di PayBar.',
            style:
                AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'email@teman.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  if (widget.emailController.text.trim().isEmpty) return;
                  setState(() => _isLoading = true);
                  // Capture sebelum await agar aman setelah gap async
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await widget.onInvite(widget.emailController.text);
                    if (mounted) {
                      nav.pop();
                      widget.onSuccess();
                    }
                  } on Exception catch (e) {
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    final msg = e.toString().contains('user-not-found')
                        ? 'Email ini belum terdaftar di PayBar.'
                        : e.toString().contains('already-member')
                            ? 'Teman ini sudah jadi anggota grup.'
                            : 'Aduh, gagal mengundang. Coba lagi ya.';
                    messenger.showSnackBar(SnackBar(content: Text(msg)));
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Undang'),
        ),
      ],
    );
  }
}
