import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:paybar_app/core/theme/app_colors.dart';
import 'package:paybar_app/core/theme/app_typography.dart';
import 'package:paybar_app/models/group_model.dart';
import 'package:paybar_app/models/transaction_model.dart';
import 'package:paybar_app/screens/group/group_detail_screen.dart';
import 'package:paybar_app/services/group_service.dart';
import 'package:paybar_app/services/transaction_service.dart';

// ---------------------------------------------------------------------------
// HELPER FORMAT RUPIAH
// ---------------------------------------------------------------------------

String _formatRupiahShort(double amount) {
  final abs = amount.abs();
  if (abs >= 1000000) return 'Rp ${(abs / 1000000).toStringAsFixed(1)}Jt';
  if (abs >= 1000) return 'Rp ${(abs ~/ 1000)}K';
  return 'Rp ${abs.toStringAsFixed(0)}';
}

String _formatRupiahFull(double amount) {
  final abs = amount.abs().toStringAsFixed(0);
  final buffer = StringBuffer();
  int counter = 0;
  for (int i = abs.length - 1; i >= 0; i--) {
    if (counter != 0 && counter % 3 == 0) buffer.write('.');
    buffer.write(abs[i]);
    counter++;
  }
  return 'Rp ${buffer.toString().split('').reversed.join('')}';
}

// ---------------------------------------------------------------------------
// DATA CLASS HASIL KALKULASI BALANCE
// Dihitung dari semua TransactionModel di semua grup user.
//
// Logika per transaksi:
//   - paidBy == currentUid  → setiap participant lain hutang (perPerson) ke kamu
//   - participant == currentUid && paidBy != currentUid → kamu hutang (perPerson) ke paidBy
// ---------------------------------------------------------------------------

/// Agregasi balance dari semua transaksi di semua grup.
/// Returns map uid → net amount (dari sudut pandang currentUid).
Map<String, double> _calcBalances(
  String currentUid,
  List<TransactionModel> allTx,
) {
  final map = <String, double>{};

  for (final tx in allTx) {
    if (!tx.participants.contains(currentUid)) continue;

    final perPerson = tx.perPerson;

    if (tx.paidBy == currentUid) {
      // Kamu yang bayar → semua participant lain hutang ke kamu
      for (final uid in tx.participants) {
        if (uid == currentUid) continue;
        map[uid] = (map[uid] ?? 0) + perPerson;
      }
    } else if (tx.participants.contains(currentUid)) {
      // Orang lain yang bayar → kamu hutang ke paidBy
      map[tx.paidBy] = (map[tx.paidBy] ?? 0) - perPerson;
    }
  }

  return map;
}

// ---------------------------------------------------------------------------
// DASHBOARD SCREEN
// ---------------------------------------------------------------------------

class DashboardScreen extends StatefulWidget {
  /// Callback untuk pindah tab di HomeScreen (ganti index nav bar).
  final void Function(int index)? onNavigateTo;

  /// Callback untuk push screen di atas tab Grup, nav bar tetap tampil.
  final void Function(Widget screen)? onPushToGrup;

  final void Function()? onLogout;

  const DashboardScreen({
    super.key,
    this.onNavigateTo,
    this.onPushToGrup,
    this.onLogout,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _groupService = GroupService();
  final _txService = TransactionService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String get _currentUid => _auth.currentUser!.uid;

  // Nama user saat ini (diambil dari Firestore sekali)
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    final doc =
        await _firestore.collection('users').doc(_currentUid).get();
    if (!mounted) return;
    setState(() {
      _displayName =
          (doc.data()?['name'] as String?) ?? _auth.currentUser?.email ?? '';
    });
  }

  /// Inisial dari nama (maks 2 huruf kapital)
  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  /// Warna avatar deterministik berdasarkan hash uid
  Color _avatarBg(String uid) {
    const colors = [
      Color(0xFFFFF0F0),
      Color(0xFFF0F4FF),
      Color(0xFFE8FDF9),
      Color(0xFFFFF8E6),
      Color(0xFFF5F0FF),
      Color(0xFFE8F4FF),
    ];
    return colors[uid.hashCode.abs() % colors.length];
  }

  Color _avatarFg(String uid) {
    const colors = [
      Color(0xFFFF6B6B),
      Color(0xFF5B7FE5),
      Color(0xFF0B8C76),
      Color(0xFFD08000),
      Color(0xFF7C5CBF),
      Color(0xFF1E7EC8),
    ];
    return colors[uid.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<List<GroupModel>>(
          stream: _groupService.getGroups(),
          builder: (context, groupSnap) {
            if (groupSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (groupSnap.hasError) {
              return _buildError('Gagal memuat grup. Coba lagi ya.');
            }

            final groups = groupSnap.data ?? [];

            // Stream semua transaksi dari semua grup secara paralel,
            // lalu gabungkan dengan StreamBuilder bertingkat.
            return _DashboardBody(
              groups: groups,
              txService: _txService,
              currentUid: _currentUid,
              displayName: _displayName,
              initials: _initials,
              avatarBg: _avatarBg,
              avatarFg: _avatarFg,
              onNavigateTo: widget.onNavigateTo,
              onPushToGrup: widget.onPushToGrup,
              onLogout: widget.onLogout,
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          msg,
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DASHBOARD BODY
// Dipisah agar bisa subscribe stream transaksi setelah grup sudah tersedia.
// ---------------------------------------------------------------------------

class _DashboardBody extends StatelessWidget {
  final List<GroupModel> groups;
  final TransactionService txService;
  final String currentUid;
  final String displayName;
  final String Function(String) initials;
  final Color Function(String) avatarBg;
  final Color Function(String) avatarFg;
  final void Function(int index)? onNavigateTo;
  final void Function(Widget screen)? onPushToGrup;
  final void Function()? onLogout;

  const _DashboardBody({
    required this.groups,
    required this.txService,
    required this.currentUid,
    required this.displayName,
    required this.initials,
    required this.avatarBg,
    required this.avatarFg,
    this.onNavigateTo,
    this.onPushToGrup,
    this.onLogout,
  });

  /// Gabungkan stream transaksi dari semua grup menjadi satu List<TransactionModel>.
  /// Menggunakan StreamBuilder bertumpuk — cocok untuk jumlah grup kecil (free tier).
  Stream<List<TransactionModel>> _allTransactionsStream() async* {
    if (groups.isEmpty) {
      yield [];
      return;
    }

    // Emit setiap kali salah satu grup berubah
    final streams =
        groups.map((g) => txService.getTransactions(g.id)).toList();

    // Combine dengan reduce sederhana menggunakan rxdart tidak tersedia,
    // jadi kita gunakan pendekatan: StreamController yang di-feed dari semua stream.
    // Karena free tier groups kecil, approach ini aman.
    final combined = <String, List<TransactionModel>>{};
    for (final g in groups) {
      combined[g.id] = [];
    }

    // yield pertama langsung kosong sementara menunggu data
    yield [];

    // Untuk Flutter tanpa rxdart, gunakan StreamController merge manual
    final controller = StreamController<List<TransactionModel>>.broadcast();

    final subs = <StreamSubscription>[];
    for (int i = 0; i < groups.length; i++) {
      final gId = groups[i].id;
      final sub = streams[i].listen((txList) {
        combined[gId] = txList;
        final all = combined.values.expand((e) => e).toList();
        if (!controller.isClosed) controller.add(all);
      });
      subs.add(sub);
    }

    yield* controller.stream;

    // Cleanup subs saat stream ini di-cancel
    // (StreamController akan di-GC karena tidak ada ref lain)
    for (final s in subs) {
      s.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransactionModel>>(
      stream: _allTransactionsStream(),
      builder: (context, txSnap) {
        final allTx = txSnap.data ?? [];
        final balanceMap = _calcBalances(currentUid, allTx);

        // Hitung total piutang & utang
        double totalPiutang = 0;
        double totalUtang = 0;
        for (final net in balanceMap.values) {
          if (net > 0) {
            totalPiutang += net;
          } else {
            totalUtang += net.abs();
          }
        }
        final netBalance = totalPiutang - totalUtang;

        return CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildHeader(displayName, initials(displayName)),
            ),

            // ── Net Balance Card ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildNetBalanceCard(
                netBalance: netBalance,
                totalPiutang: totalPiutang,
                totalUtang: totalUtang,
                groupCount: groups.length,
                isLoading: txSnap.connectionState == ConnectionState.waiting,
              ),
            ),

            // ── Siapa yang belum bayar ─────────────────────────────────────
            if (balanceMap.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionTitle('Siapa yang belum bayar? 💸'),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = balanceMap.entries.toList()[index];
                    return _BalanceListItem(
                      uid: entry.key,
                      net: entry.value,
                      avatarBg: avatarBg(entry.key),
                      avatarFg: avatarFg(entry.key),
                      // Tampilkan nama grup paling relevan
                      groupHint: _groupHintForUid(entry.key, allTx),
                    );
                  },
                  childCount: balanceMap.length,
                ),
              ),
            ] else if (txSnap.connectionState != ConnectionState.waiting) ...[
              SliverToBoxAdapter(
                child: _buildSectionTitle('Siapa yang belum bayar? 💸'),
              ),
              SliverToBoxAdapter(child: _buildEmptyBalance()),
            ],

            // ── Grup Aktif ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionTitle('Grup aktif'),
            ),
            if (groups.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyGroups())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final g = groups[index];
                    // Filter transaksi milik grup ini menggunakan groupId
                    final groupTx = (txSnap.data ?? [])
                        .where((tx) => _txBelongsToGroup(tx, g.id))
                        .toList();
                    final groupBalance =
                        _calcBalances(currentUid, groupTx);
                    final groupNet = groupBalance.values
                        .fold<double>(0, (s, v) => s + v);
                    return _GroupListItem(
                      group: g,
                      netAmount: groupNet,
                      onTap: () => onPushToGrup?.call(
                        GroupDetailScreen(groupId: g.id),
                      ),
                    );
                  },
                  childCount: groups.length,
                ),
              ),

            // ── TODO: Ringkasan per Bulan ──────────────────────────────────
            // SliverToBoxAdapter(child: _buildMonthlyChart(allTx)),
 
            // ── TODO: Aktivitas Terbaru ────────────────────────────────────
            // SliverToBoxAdapter(child: _buildRecentActivity(allTx)),
          ],
        );
      },
    );
  }

  /// Cari nama grup paling relevan untuk uid tertentu berdasarkan transaksi
  String _groupHintForUid(String uid, List<TransactionModel> allTx) {
    for (final tx in allTx) {
      if (!tx.participants.contains(uid)) continue;
      if (!tx.participants.contains(currentUid) && tx.paidBy != currentUid) {
        continue;
      }
      // Cari nama grup dari list groups
      final match = groups.where((g) => g.id == tx.groupId).firstOrNull;
      if (match != null) return match.name;
    }
    return '';
  }
 
  /// Cek apakah transaksi ini milik grup tertentu — sekarang pakai groupId.
  bool _txBelongsToGroup(TransactionModel tx, String groupId) {
    return tx.groupId == groupId;
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(String name, String avatarText) {
    return Container(
      color: AppColors.dark,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PayBar',
                  style: AppTypography.h1.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Halo kembali,',
                  style: AppTypography.caption.copyWith(fontSize: 11, color: AppColors.textSecondary),
                ),
                Text(
                  '$displayName 👋',
                  style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.white),
                ),
              ],
            ),
          ),
          Row(
            children: [
              PopupMenuButton<String>(
                icon: 
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials(displayName),
                      style: AppTypography.avatar,
                    ),
                  ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  switch (val) {
                    case 'edit':
                    case 'logout':
                      onLogout!();
                  }
                },
                itemBuilder: (_) => [
                  _menuItem('edit', Icons.edit_rounded, 'Edit Profile',
                      AppColors.primary),
                  _menuItem('logout', Icons.logout_rounded, 'Logout',
                      AppColors.negative),
                ],
              ),
            ],
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
  // ── Net Balance Card ─────────────────────────────────────────────────────

  Widget _buildNetBalanceCard({
    required double netBalance,
    required double totalPiutang,
    required double totalUtang,
    required int groupCount,
    required bool isLoading,
  }) {
    final isPositive = netBalance >= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total ${isPositive ? 'Piutang' : 'Utang'} Bersih',
              style: AppTypography.caption.copyWith(color:  AppColors.white.withAlpha(195)),
            ),
            const SizedBox(height: 4),
            Text(
              '${isPositive ? '+' : '-'}${_formatRupiahFull(netBalance.abs())}',
              style: AppTypography.h1.copyWith(color: AppColors.white),
            ),
            Text(
              'Di $groupCount grup aktif · diperbarui barusan',
              style: AppTypography.caption.copyWith(color:  AppColors.white.withAlpha(195)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _NetMiniCard(
                    icon: Icons.trending_up_rounded,
                    label: 'Piutang',
                    amount: totalPiutang,
                    isLoading: isLoading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NetMiniCard(
                    icon: Icons.trending_down_rounded,
                    label: 'Utang',
                    amount: totalUtang,
                    isLoading: isLoading,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Title ────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: AppTypography.body,
      ),
    );
  }

  // ── Empty States ─────────────────────────────────────────────────────────

  Widget _buildEmptyBalance() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.positive, size: 24),
            const SizedBox(width: 12),
            Text(
              'Semua lunas, nggak ada tanggungan! 🎉',
              style: AppTypography.caption.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyGroups() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.group_add_outlined,
                color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Text(
              'Belum ada grup. Yuk, buat yang pertama!',
              style: AppTypography.caption.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NET MINI CARD
// ---------------------------------------------------------------------------

class _NetMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final bool isLoading;

  const _NetMiniCard({
    required this.icon,
    required this.label,
    required this.amount,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.85), size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.white.withAlpha(195)),
          ),
          const SizedBox(height: 2),
          Text(
            _formatRupiahShort(amount),
            style: AppTypography.bodyLarge.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BALANCE LIST ITEM
// Menampilkan nama uid → di-resolve realtime dari Firestore
// ---------------------------------------------------------------------------

class _BalanceListItem extends StatelessWidget {
  final String uid;
  final double net; // positif = dia hutang ke kamu, negatif = kamu hutang
  final Color avatarBg;
  final Color avatarFg;
  final String groupHint;

  const _BalanceListItem({
    required this.uid,
    required this.net,
    required this.avatarBg,
    required this.avatarFg,
    this.groupHint = '',
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = net >= 0;
    final amountColor = isPositive ? AppColors.positive : AppColors.negative;
    final statusText =
        isPositive ? 'dia hutang ke kamu' : 'kamu hutang ke dia';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      // Resolve nama dari Firestore
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?;
          final name = (data?['name'] as String?) ?? '...';
          final initials = _initials(name);

          return Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: AppTypography.avatar,
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.body,
                      ),
                      if (groupHint.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          groupHint,
                          style: AppTypography.caption.copyWith(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isPositive ? '+' : '-'}${_formatRupiahFull(net.abs())}',
                      style: AppTypography.nominal.copyWith(color: amountColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: AppTypography.subCaption.copyWith(fontSize:11, color: amountColor),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }
}

// ---------------------------------------------------------------------------
// GROUP LIST ITEM — data dari GroupModel Firestore
// ---------------------------------------------------------------------------
class _GroupListItem extends StatelessWidget {
  final GroupModel group;
  final double netAmount; // net balance user di grup ini (positif=piutang, negatif=utang)
  final VoidCallback? onTap;
 
  const _GroupListItem({
    required this.group,
    required this.netAmount,
    this.onTap,
  });
 
  @override
  Widget build(BuildContext context) {
    final hasBalance = netAmount.abs() > 1;
    final isPositive = netAmount >= 0;
 
    // Warna & teks badge
    final badgeBg = !hasBalance
        ? AppColors.settledBg
        : isPositive
            ? const Color(0xFFE8FDF9)
            : const Color(0xFFFFF0F0);
    final badgeFg = !hasBalance
        ? AppColors.settledFg
        : isPositive
            ? AppColors.positive
            : AppColors.negative;
    final badgeText = !hasBalance
        ? 'Lunas ✓'
        : '${isPositive ? '+' : '-'}${_formatRupiahShort(netAmount.abs())}';
 
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Icon box
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.group_outlined,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: AppTypography.body,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${group.members.length} anggota',
                        style: AppTypography.subCaption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Badge nominal + chevron
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badgeText,
                        style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600, color: badgeFg),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}