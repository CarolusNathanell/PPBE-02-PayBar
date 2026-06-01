import 'package:flutter/material.dart';
import 'package:paybar_app/core/theme/app_colors.dart';
import 'package:paybar_app/core/theme/app_typography.dart';

// ---------------------------------------------------------------------------
// MODEL DUMMY — ganti dengan data Firestore nanti
// ---------------------------------------------------------------------------

class BalanceItem {
  final String initials;
  final String name;
  final String groupName;
  final int amount; // positif = piutang (dia hutang ke kamu), negatif = kamu hutang
  final Color avatarBg;
  final Color avatarFg;

  const BalanceItem({
    required this.initials,
    required this.name,
    required this.groupName,
    required this.amount,
    required this.avatarBg,
    required this.avatarFg,
  });
}

class GroupItem {
  final IconData icon;
  final String name;
  final String meta;
  final int? pendingAmount; // null = lunas
  final String? pendingLabel;

  const GroupItem({
    required this.icon,
    required this.name,
    required this.meta,
    this.pendingAmount,
    this.pendingLabel,
  });
}

// ---------------------------------------------------------------------------
// DATA DUMMY
// ---------------------------------------------------------------------------

const List<BalanceItem> _dummyBalances = [
  BalanceItem(
    initials: 'BW',
    name: 'Bima Wahyu',
    groupName: 'Makan bareng Jumat · Grup Kantor',
    amount: 75000,
    avatarBg: Color(0xFFFFF0F0),
    avatarFg: Color(0xFFFF6B6B),
  ),
  BalanceItem(
    initials: 'DS',
    name: 'Dinda Sari',
    groupName: 'Bensin Bali · Liburan Geng',
    amount: 160000,
    avatarBg: Color(0xFFF0F4FF),
    avatarFg: Color(0xFF5B7FE5),
  ),
  BalanceItem(
    initials: 'AF',
    name: 'Anisa Fitri',
    groupName: 'Kos bulanan · Squad Kos',
    amount: -50000,
    avatarBg: Color(0xFFE8FDF9),
    avatarFg: Color(0xFF0B8C76),
  ),
  BalanceItem(
    initials: 'MR',
    name: 'Muhammad Rizal',
    groupName: 'Tagihan listrik · Squad Kos',
    amount: -75000,
    avatarBg: Color(0xFFFFF8E6),
    avatarFg: Color(0xFFD08000),
  ),
];

const List<GroupItem> _dummyGroups = [
  GroupItem(
    icon: Icons.work_outline_rounded,
    name: 'Grup Kantor',
    meta: '5 orang · 2 transaksi belum lunas',
    pendingAmount: 75000,
    pendingLabel: 'Rp 75K',
  ),
  GroupItem(
    icon: Icons.beach_access_outlined,
    name: 'Liburan Geng',
    meta: '4 orang · 1 transaksi belum lunas',
    pendingAmount: 160000,
    pendingLabel: 'Rp 160K',
  ),
  GroupItem(
    icon: Icons.home_outlined,
    name: 'Squad Kos',
    meta: '3 orang · semua lunas',
    pendingAmount: null,
  ),
];

// ---------------------------------------------------------------------------
// WARNA (sesuai design system PayBar)
// ---------------------------------------------------------------------------

// class AppColors {
//   static const primary = Color(0xFF00B8A9);
//   static const dark = Color(0xFF1A2A3A);
//   static const background = Color(0xFFF7F8FA);
//   static const negative = Color(0xFFFF6B6B);
//   static const positive = Color(0xFF4ECDC4);
//   static const accent = Color(0xFFFFD93D);
//   static const textPrimary = Color(0xFF2D3436);
//   static const textSecondary = Color(0xFF636E72);
//   static const border = Color(0xFFDFE6E9);
//   static const white = Color(0xFFFFFFFF);
//   static const settledBg = Color(0xFFE8FDF9);
//   static const settledFg = Color(0xFF0B8C76);
//   static const pendingBg = Color(0xFFFFF3CD);
//   static const pendingFg = Color(0xFFD08000);
// }

// ---------------------------------------------------------------------------
// HELPER FORMAT RUPIAH
// ---------------------------------------------------------------------------

String _formatRupiah(int amount) {
  final abs = amount.abs();
  if (abs >= 1000000) {
    return 'Rp ${(abs / 1000000).toStringAsFixed(1)}Jt';
  } else if (abs >= 1000) {
    return 'Rp ${(abs ~/ 1000)}K';
  }
  return 'Rp $abs';
}

String _formatRupiahFull(int amount) {
  final abs = amount.abs();
  final s = abs.toString();
  final buffer = StringBuffer();
  int counter = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    if (counter != 0 && counter % 3 == 0) buffer.write('.');
    buffer.write(s[i]);
    counter++;
  }
  return 'Rp ${buffer.toString().split('').reversed.join('')}';
}

// ---------------------------------------------------------------------------
// DASHBOARD SCREEN
// ---------------------------------------------------------------------------

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Total piutang dan utang dihitung dari dummy data
  int get _totalPiutang => _dummyBalances
      .where((b) => b.amount > 0)
      .fold(0, (sum, b) => sum + b.amount);

  int get _totalUtang => _dummyBalances
      .where((b) => b.amount < 0)
      .fold(0, (sum, b) => sum + b.amount.abs());

  int get _netBalance => _totalPiutang - _totalUtang;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader()),

            // ── Net Balance Card ─────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildNetBalanceCard()),

            // ── "Siapa yang belum bayar?" ────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionTitle('Siapa yang belum bayar? 💸'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _BalanceListItem(item: _dummyBalances[index]),
                childCount: _dummyBalances.length,
              ),
            ),

            // ── Grup Aktif ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionTitle('Grup aktif'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _GroupListItem(item: _dummyGroups[index]),
                childCount: _dummyGroups.length,
              ),
            ),

            // ── Aksi Cepat ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionTitle('Aksi cepat'),
            ),
            SliverToBoxAdapter(child: _buildQuickActions(context)),

            // ── Bottom padding ───────────────────────────────────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── TODO: Ringkasan per Bulan (Chart) ────────────────────────────
            // SliverToBoxAdapter(child: _buildMonthlyChart()),

            // ── TODO: Aktivitas Terbaru ──────────────────────────────────────
            // SliverToBoxAdapter(child: _buildRecentActivity()),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: AppColors.dark,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PayBar',
                  style: AppTypography.h1.copyWith(color: AppColors.primary),
                ),
                Text(
                  'Halo kembali,',
                  style: AppTypography.caption.copyWith(fontSize: 11, color: AppColors.textSecondary),
                ),
                Text(
                  'Rizky Adi 👋',
                  style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.white),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.notifications_outlined,
                  color: Colors.white54, size: 22),
              const SizedBox(width: 12),
              // Avatar initials
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  'RA',
                  style: AppTypography.avatar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Net Balance Card ───────────────────────────────────────────────────────

  Widget _buildNetBalanceCard() {
    final isPositive = _netBalance >= 0;
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
              '${isPositive ? '+' : '-'}${_formatRupiahFull(_netBalance.abs())}',
              style: AppTypography.h1.copyWith(color: AppColors.white),
            ),
            Text(
              'Di ${_dummyGroups.length} grup aktif · diperbarui barusan',
              style: AppTypography.caption.copyWith(color:  AppColors.white.withAlpha(195)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _NetMiniCard(
                    icon: Icons.trending_up_rounded,
                    label: 'Piutang',
                    amount: _totalPiutang,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NetMiniCard(
                    icon: Icons.trending_down_rounded,
                    label: 'Utang',
                    amount: _totalUtang,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Section title ──────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: AppTypography.body,
      ),
    );
  }

  // ── Quick Actions ──────────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.add_rounded,
        label: 'Catat\nTransaksi',
        onTap: () {
          // TODO: Navigate to add transaction screen
        },
      ),
      _QuickAction(
        icon: Icons.check_circle_outline_rounded,
        label: 'Tandai\nLunas',
        onTap: () {
          // TODO: Navigate to settlement screen
        },
      ),
      _QuickAction(
        icon: Icons.group_add_outlined,
        label: 'Buat\nGrup',
        onTap: () {
          // TODO: Navigate to create group screen
        },
      ),
      _QuickAction(
        icon: Icons.notifications_active_outlined,
        label: 'Kirim\nReminder',
        onTap: () {
          // TODO: Reminder popup (Orang 3 - FCM)
          // _showReminderBottomSheet(context);
        },
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: actions.map((a) => _QuickActionButton(action: a)).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NET MINI CARD (dalam Balance Card)
// ---------------------------------------------------------------------------

class _NetMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int amount;

  const _NetMiniCard({
    required this.icon,
    required this.label,
    required this.amount,
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
            _formatRupiah(amount),
            style: AppTypography.bodyLarge.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BALANCE LIST ITEM
// ---------------------------------------------------------------------------

class _BalanceListItem extends StatelessWidget {
  final BalanceItem item;

  const _BalanceListItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPositive = item.amount >= 0;
    final amountColor = isPositive ? AppColors.positive : AppColors.negative;
    final amountText =
        '${isPositive ? '+' : '-'}${_formatRupiahFull(item.amount.abs())}';
    final statusText = isPositive ? 'Piutang' : 'Hutang';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.avatarBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                item.initials,
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
                    item.name,
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.groupName,
                    style: AppTypography.caption.copyWith(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GROUP LIST ITEM
// ---------------------------------------------------------------------------

class _GroupListItem extends StatelessWidget {
  final GroupItem item;

  const _GroupListItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final isSettled = item.pendingAmount == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
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
                color: const Color(0xFFE6FAF8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.meta,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSettled ? AppColors.settledBg : AppColors.pendingBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isSettled ? 'Lunas ✓' : (item.pendingLabel ?? ''),
                style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600, color: isSettled ? AppColors.settledFg : AppColors.pendingFg,),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QUICK ACTION
// ---------------------------------------------------------------------------

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _QuickActionButton extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 6),
            Text(
              action.label,
              style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ENTRY POINT PREVIEW (hapus kalau diintegrasikan ke main.dart)
// ---------------------------------------------------------------------------

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PayBar',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const DashboardScreen(),
    ),
  );
}