import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:paybar_app/core/theme/app_colors.dart';
import 'package:paybar_app/core/theme/app_typography.dart';
import 'package:paybar_app/models/settlement_model.dart';
import 'package:paybar_app/models/transaction_model.dart';
import 'package:paybar_app/services/currency_service.dart';
import 'package:paybar_app/services/settlement_service.dart';
import 'package:paybar_app/services/transaction_service.dart';
import 'package:paybar_app/widgets/receipt_picker_widget.dart';

class SettlementScreen extends StatefulWidget {
  final String groupId;
  final Map<String, String> memberNames; // uid → name
  final Map<String, Map<String, String>> bankDetails;

  const SettlementScreen({
    super.key,
    required this.groupId,
    required this.memberNames,
    required this.bankDetails
  });

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen>
    with SingleTickerProviderStateMixin {
  final _settlementService = SettlementService();
  final _txService = TransactionService();

  late final TabController _tabController;
  Key _streamKey = UniqueKey();

  String get _currentUid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _retry() => setState(() => _streamKey = UniqueKey());

  void _showCreateBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateSettlementSheet(
        groupId: widget.groupId,
        memberNames: widget.memberNames,
        currentUid: _currentUid,
        txService: _txService,
        settlementService: _settlementService,
        onCreated: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pembayaran tercatat! Menunggu konfirmasi. 🕐'),
            ),
          );
        },
        bankDetails: widget.bankDetails,
      ),
    );
  }

  Future<void> _confirmSettlement(SettlementModel s) async {
    try {
      await _settlementService.confirmSettlement(
          widget.groupId, s.settlementId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran dikonfirmasi! Lunas. ✅')),
        );
      }
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('not-authorized')
          ? 'Hanya penerima yang bisa konfirmasi.'
          : e.toString().contains('already-settled')
              ? 'Settlement ini sudah dikonfirmasi.'
              : 'Aduh, ada gangguan. Coba lagi ya.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showUnconfirmDialog(SettlementModel s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        title: Text('Batalkan Konfirmasi?', style: AppTypography.h2),
        content: Text(
          'Status lunas akan dibatalkan dan menunggu konfirmasi ulang.',
          style:
              AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _settlementService.unconfirmSettlement(
                    widget.groupId, s.settlementId);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Aduh, ada gangguan. Coba lagi ya.')),
                  );
                }
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.negative),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(SettlementModel s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        title: Text('Hapus Settlement?', style: AppTypography.h2),
        content: Text(
          'Catatan pembayaran ini akan dihapus. Aksi ini nggak bisa di-undo.',
          style:
              AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _settlementService.deleteSettlement(
                    widget.groupId, s.settlementId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Settlement dihapus.')),
                  );
                }
              } on Exception catch (e) {
                if (!mounted) return;
                final msg = e.toString().contains('not-authorized')
                    ? 'Hanya pengirim yang bisa hapus.'
                    : e.toString().contains('already-confirmed')
                        ? 'Settlement yang sudah dikonfirmasi tidak bisa dihapus.'
                        : 'Aduh, ada gangguan. Coba lagi ya.';
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(msg)));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.negative),
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
      appBar: AppBar(
        title: Text('Settlement', style: AppTypography.h2),
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Perlu Konfirmasi'),
            Tab(text: 'Semua'),
          ],
        ),
      ),
      body: StreamBuilder<List<SettlementModel>>(
        key: _streamKey,
        stream: _settlementService.getSettlements(widget.groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError) {
            return _ErrorState(onRetry: _retry);
          }

          final allSettlements = snapshot.data ?? [];
          final pending = allSettlements
              .where((s) => !s.settled)
              .toList();
          final all = allSettlements;

          return TabBarView(
            controller: _tabController,
            children: [
              _SettlementList(
                settlements: pending,
                currentUid: _currentUid,
                memberNames: widget.memberNames,
                emptyIcon: Icons.check_circle_outline_rounded,
                emptyTitle: 'Semua sudah terkonfirmasi!',
                emptySubtitle: 'Nggak ada yang perlu dikonfirmasi sekarang. 🎉',
                onConfirm: _confirmSettlement,
                onUnconfirm: _showUnconfirmDialog,
                onDelete: _showDeleteDialog,
                groupId: widget.groupId,
              ),
              _SettlementList(
                settlements: all,
                currentUid: _currentUid,
                memberNames: widget.memberNames,
                emptyIcon: Icons.receipt_long_outlined,
                emptyTitle: 'Belum ada settlement',
                emptySubtitle:
                    'Tekan tombol + untuk catat pembayaran pertama.',
                onConfirm: _confirmSettlement,
                onUnconfirm: _showUnconfirmDialog,
                onDelete: _showDeleteDialog,
                groupId: widget.groupId,
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateBottomSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tandai Bayar'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 2,
      ),
    );
  }
}

class _SettlementList extends StatelessWidget {
  final List<SettlementModel> settlements;
  final String currentUid;
  final Map<String, String> memberNames;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function(SettlementModel) onConfirm;
  final void Function(SettlementModel) onUnconfirm;
  final void Function(SettlementModel) onDelete;
  final String groupId;

  const _SettlementList({
    required this.settlements,
    required this.currentUid,
    required this.memberNames,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onConfirm,
    required this.onUnconfirm,
    required this.onDelete,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    if (settlements.isEmpty) {
      return _EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: settlements.length,
      itemBuilder: (ctx, i) => _SettlementCard(
        settlement: settlements[i],
        currentUid: currentUid,
        memberNames: memberNames,
        onConfirm: () => onConfirm(settlements[i]),
        onUnconfirm: () => onUnconfirm(settlements[i]),
        onDelete: () => onDelete(settlements[i]),
        groupId: groupId,
      ),
    );
  }
}

class _SettlementCard extends StatefulWidget {
  final SettlementModel settlement;
  final String currentUid;
  final Map<String, String> memberNames;
  final VoidCallback onConfirm;
  final VoidCallback onUnconfirm;
  final VoidCallback onDelete;
  final String groupId;

  const _SettlementCard({
    required this.settlement,
    required this.currentUid,
    required this.memberNames,
    required this.onConfirm,
    required this.onUnconfirm,
    required this.onDelete,
    required this.groupId,
  });

  @override
  State<_SettlementCard> createState() => _SettlementCardState();
}

class _SettlementCardState extends State<_SettlementCard> {
  bool _isConfirming = false;

  String _nameOf(String uid) =>
      widget.memberNames[uid] ?? '...';

  @override
  Widget build(BuildContext context) {
    final s = widget.settlement;
    final isFromMe = s.fromUid == widget.currentUid;
    final isToMe = s.toUid == widget.currentUid;
    final isPending = !s.settled;
    final canConfirm = isToMe && isPending;
    final canDelete = isFromMe && isPending;
    final canUnconfirm = isToMe && s.settled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: s.settled ? AppColors.positive.withValues(alpha: 0.4) : AppColors.border,
          width: s.settled ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: s.settled
                        ? AppColors.positive.withValues(alpha: 0.12)
                        : AppColors.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    s.settled
                        ? Icons.check_circle_rounded
                        : Icons.hourglass_top_rounded,
                    color: s.settled ? AppColors.positive : AppColors.pendingFg,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: AppTypography.body,
                          children: [
                            TextSpan(
                              text: _nameOf(s.fromUid),
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: ' bayar ke ',
                              style: AppTypography.body.copyWith(
                                  color: AppColors.textSecondary),
                            ),
                            TextSpan(
                              text: _nameOf(s.toUid),
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatRupiahFull(s.amount),
                        style: AppTypography.nominal.copyWith(
                          color: AppColors.primary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _StatusChip(settlement: s),
                      const SizedBox(height: 4),
                      ReceiptPickerWidget(
                        groupId: widget.groupId,
                        docId: s.settlementId,
                        type: ReceiptType.settlement,
                        existingUrl: s.receiptUrl,
                        readOnly: !isFromMe,
                      ),
                    ],
                  ),
                ),

                if (canDelete || canUnconfirm)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded,
                        size: 18, color: AppColors.textSecondary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      if (canUnconfirm)
                        PopupMenuItem(
                          value: 'unconfirm',
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.undo_rounded,
                                  size: 14, color: AppColors.pendingFg),
                            ),
                            const SizedBox(width: 10),
                            Text('Batalkan Konfirmasi',
                                style: AppTypography.body),
                          ]),
                        ),
                      if (canDelete)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.negative.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.delete_rounded,
                                  size: 14, color: AppColors.negative),
                            ),
                            const SizedBox(width: 10),
                            Text('Hapus',
                                style: AppTypography.body
                                    .copyWith(color: AppColors.negative)),
                          ]),
                        ),
                    ],
                    onSelected: (val) {
                      if (val == 'delete') widget.onDelete();
                      if (val == 'unconfirm') widget.onUnconfirm();
                    },
                  ),
              ],
            ),
          ),

          if (canConfirm) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isConfirming
                      ? null
                      : () async {
                          setState(() => _isConfirming = true);
                          widget.onConfirm();
                          if (mounted) {
                            setState(() => _isConfirming = false);
                          }
                        },
                  icon: _isConfirming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                      _isConfirming ? 'Mengonfirmasi...' : 'Konfirmasi Terima'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.positive,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],

          if (isFromMe && isPending) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Menunggu konfirmasi dari ${_nameOf(s.toUid)}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final SettlementModel settlement;
  const _StatusChip({required this.settlement});

  @override
  Widget build(BuildContext context) {
    final s = settlement;
    if (s.settled && s.settledAt != null) {
      return Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.settledBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Lunas ✓',
              style: AppTypography.caption.copyWith(
                color: AppColors.settledFg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            DateFormat('d MMM y', 'id_ID').format(s.settledAt!),
            style: AppTypography.caption,
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.pendingBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Menunggu konfirmasi',
        style: AppTypography.caption.copyWith(
          color: AppColors.pendingFg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Memilih transaksi yang mau di-settle, lalu input jumlah.
class _CreateSettlementSheet extends StatefulWidget {
  final String groupId;
  final Map<String, String> memberNames;
  final String currentUid;
  final TransactionService txService;
  final SettlementService settlementService;
  final VoidCallback onCreated;
  final Map<String, Map<String, String>> bankDetails;

  const _CreateSettlementSheet({
    required this.groupId,
    required this.memberNames,
    required this.currentUid,
    required this.txService,
    required this.settlementService,
    required this.onCreated,
    required this.bankDetails,
  });

  @override
  State<_CreateSettlementSheet> createState() =>
      _CreateSettlementSheetState();
}

class _CreateSettlementSheetState extends State<_CreateSettlementSheet> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _currencyService = CurrencyService();

  TransactionModel? _selectedTx;
  bool _isSaving = false;

  double? _idrEquivalent;
  bool _isConverting = false;
  Timer? _debounce;

  String _nameOf(String uid) => widget.memberNames[uid] ?? '...';

  Map<String, String> _bankDetailsOf(String uid) => widget.bankDetails[uid] ?? <String, String>{"...": "..."};

  Future<void> _copyAccountNumber(String accountNumber) async {
    await Clipboard.setData(ClipboardData(text: accountNumber));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nomor rekening disalin')),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Konversi ke IDR untuk transaksi non-IDR, supaya user tahu nominal transfer sebenarnya.
  void _onAmountChanged() {
    final tx = _selectedTx;
    if (tx == null || tx.currency == 'IDR') {
      setState(() => _idrEquivalent = null);
      return;
    }
    final amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _idrEquivalent = null);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(
        const Duration(milliseconds: 500), () => _fetchConversion(amount, tx.currency));
  }

  Future<void> _fetchConversion(double amount, String currency) async {
    setState(() => _isConverting = true);
    try {
      final idr = await _currencyService.convertToIdr(amount, currency);
      if (mounted) setState(() => _idrEquivalent = idr);
    } catch (_) {
      if (mounted) setState(() => _idrEquivalent = null);
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedTx == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih transaksi dulu ya.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final amount =
          double.parse(_amountController.text.trim().replaceAll(',', ''));
      await widget.settlementService.createSettlement(
        widget.groupId,
        transactionId: _selectedTx!.id,
        toUid: _selectedTx!.paidBy,
        amount: amount,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Aduh, gagal menyimpan. Coba lagi ya.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Tandai Sudah Bayar', style: AppTypography.h2),
              ],
            ),
            const SizedBox(height: 20),

            _FieldLabel('Transaksi yang dibayar'),
            StreamBuilder<List<TransactionModel>>(
              stream: widget.txService.getTransactions(widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    ),
                  );
                }

                // Filter: hanya transaksi yang melibatkan currentUser sebagai participant,
                // paidBy bukan currentUser (berarti currentUser punya hutang), dan masih
                // ada sisa tagihan (belum lunas lewat pelunasan terkonfirmasi sebelumnya).
                final txList = (snapshot.data ?? [])
                    .where((tx) =>
                        tx.participants.contains(widget.currentUid) &&
                        tx.paidBy != widget.currentUid &&
                        tx.remainingFor(widget.currentUid) > 1)
                    .toList();

                if (txList.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.textSecondary, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Nggak ada transaksi yang perlu dibayar.',
                          style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: txList.map((tx) {
                      final isSelected = _selectedTx?.id == tx.id;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedTx = tx;
                            // Auto-isi sisa tagihan (memperhitungkan custom split & pelunasan sebelumnya)
                            _amountController.text = tx
                                .remainingFor(widget.currentUid)
                                .toStringAsFixed(0);
                          });
                          _onAmountChanged();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.06)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.3))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.description,
                                      style: AppTypography.body.copyWith(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Builder(builder: (_) {
                                      final share =
                                          tx.splitFor(widget.currentUid);
                                      final remaining = tx
                                          .remainingFor(widget.currentUid);
                                      final hasPartialPaid =
                                          remaining < share - 1;
                                      final remainingStr =
                                          CurrencyService.formatCurrency(
                                              remaining, tx.currency);
                                      final shareStr =
                                          CurrencyService.formatCurrency(
                                              share, tx.currency);
                                      return Text(
                                        hasPartialPaid
                                            ? 'Dibayar ${_nameOf(tx.paidBy)} · Sisa $remainingStr dari $shareStr'
                                            : 'Dibayar ${_nameOf(tx.paidBy)} · Tagihan kamu $shareStr',
                                        style: AppTypography.caption,
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            _FieldLabel('Jumlah yang kamu bayar'),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0',
                prefixText:
                    '${CurrencyService.currencySymbols[_selectedTx?.currency ?? 'IDR'] ?? 'Rp'} ',
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
              onChanged: (_) => _onAmountChanged(),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Jumlah wajib diisi';
                }
                final v =
                    double.tryParse(val.trim().replaceAll(',', ''));
                if (v == null || v <= 0) return 'Jumlah tidak valid';
                return null;
              },
            ),
            // Uang transfer tetap dalam Rupiah, jadi tampilkan estimasi nilainya
            if (_selectedTx != null && _selectedTx!.currency != 'IDR') ...[
              const SizedBox(height: 6),
              _isConverting
                  ? Row(children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text('Mengonversi ke Rupiah...',
                          style: AppTypography.caption),
                    ])
                  : _idrEquivalent != null
                      ? Row(children: [
                          const Icon(Icons.sync_alt_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            '≈ ${CurrencyService.formatCurrency(_idrEquivalent!, 'IDR')} (kurs hari ini)',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ])
                      : const SizedBox.shrink(),
            ],
            if (_selectedTx != null) ...[
              const SizedBox(height: 8),
              Builder(builder: (_) {
                final details = _bankDetailsOf(_selectedTx!.paidBy);
                final bankName = details.keys.first;
                final accountNumber = details.values.first;
                final hasAccount = accountNumber != '...';
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_outlined,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$bankName · $accountNumber',
                          style: AppTypography.body
                              .copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (hasAccount)
                        IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 18, color: AppColors.primary),
                          tooltip: 'Salin nomor rekening',
                          onPressed: () => _copyAccountNumber(accountNumber),
                        ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white),
                      )
                    : const Text('Catat Pembayaran'),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: AppTypography.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              subtitle,
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

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.negative),
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