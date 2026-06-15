import 'dart:async';
import 'package:flutter/material.dart';
import 'package:paybar_app/core/theme/app_colors.dart';
import 'package:paybar_app/core/theme/app_typography.dart';
import 'package:paybar_app/models/transaction_model.dart';
import 'package:paybar_app/services/currency_service.dart';
import 'package:paybar_app/services/transaction_service.dart';
import 'package:paybar_app/widgets/receipt_picker_widget.dart';

class TransactionScreen extends StatefulWidget {
  final String groupId;
  final Map<String, String> memberNames; // uid → name
  final Map<String, Map<String, String>> bankDetails;
  final String currentUserUid;
  final TransactionModel? existing;

  const TransactionScreen({
    super.key,
    required this.groupId,
    required this.memberNames,
    required this.currentUserUid,
    required this.bankDetails,
    this.existing,
  });

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  final _txService = TransactionService();
  final _currencyService = CurrencyService();

  late String _selectedCurrency;
  late String _selectedPaidBy;
  late Set<String> _selectedParticipants;

  // uid → controller untuk nominal tagihan masing-masing peserta
  late final Map<String, TextEditingController> _splitControllers;

  double? _idrEquivalent;
  bool _isConverting = false;
  bool _isSaving = false;
  Timer? _debounce;
  String? _pendingReceiptUrl;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final members = widget.memberNames.keys.toList();

    _selectedCurrency = existing?.currency ?? 'IDR';
    _selectedPaidBy = (existing != null && members.contains(existing.paidBy))
        ? existing.paidBy
        : (members.contains(widget.currentUserUid)
            ? widget.currentUserUid
            : members.first);

    _selectedParticipants = existing != null
        ? Set<String>.from(existing.participants)
        : Set<String>.from(members);

    // Inisialisasi satu controller per member
    _splitControllers = {
      for (final uid in members) uid: TextEditingController(),
    };

    if (existing != null) {
      _descController.text = existing.description;
      _amountController.text = existing.amount.toString();

      // Isi splits: dari data existing jika ada, fallback sama rata
      if (existing.splits.isNotEmpty) {
        for (final uid in existing.participants) {
          final val = existing.splits[uid];
          if (val != null) {
            _splitControllers[uid]?.text = _formatSplitValue(val);
          }
        }
      } else {
        _recalculateSplits();
      }

      if (existing.currency != 'IDR') _fetchConversion();
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    for (final c in _splitControllers.values) {
      c.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  Map<String, String> _bankDetailsOf(String uid) => widget.bankDetails[uid] ?? <String, String>{"...": "..."};

  String _formatSplitValue(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  // Distribusi ulang secara sama rata ke semua peserta yang dipilih.
  // Dipanggil saat total amount berubah atau peserta berubah.
  void _recalculateSplits() {
    final total = double.tryParse(
            _amountController.text.trim().replaceAll(',', '')) ??
        0;
    final count = _selectedParticipants.length;
    if (count == 0 || total <= 0) {
      for (final uid in _selectedParticipants) {
        _splitControllers[uid]?.text = '';
      }
      return;
    }
    final share = total / count;
    for (final uid in _selectedParticipants) {
      _splitControllers[uid]?.text = _formatSplitValue(share);
    }
  }

  double get _splitsTotal => _selectedParticipants.fold(0.0, (sum, uid) {
        final raw = _splitControllers[uid]?.text.trim().replaceAll(',', '') ?? '';
        return sum + (double.tryParse(raw) ?? 0);
      });

  void _onAmountOrCurrencyChanged() {
    _recalculateSplits();
    if (_selectedCurrency == 'IDR') {
      setState(() => _idrEquivalent = null);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _fetchConversion);
  }

  Future<void> _fetchConversion() async {
    final raw = _amountController.text.trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      setState(() => _idrEquivalent = null);
      return;
    }
    setState(() => _isConverting = true);
    try {
      final idr =
          await _currencyService.convertToIdr(amount, _selectedCurrency);
      if (mounted) setState(() => _idrEquivalent = idr);
    } catch (_) {
      if (mounted) setState(() => _idrEquivalent = null);
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 orang untuk dibagi.')),
      );
      return;
    }

    final amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) return;

    // Validasi: jumlah splits harus ≈ total (toleransi Rp 1 untuk pembulatan)
    final total = _splitsTotal;
    if ((total - amount).abs() > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Total tagihan (${CurrencyService.formatCurrency(total, _selectedCurrency)}) '
            'belum sama dengan jumlah transaksi.',
          ),
        ),
      );
      return;
    }

    // Bangun splits map; kosongkan jika semua peserta dapat porsi sama
    final splitsMap = <String, double>{
      for (final uid in _selectedParticipants)
        uid: double.tryParse(
                _splitControllers[uid]?.text.trim().replaceAll(',', '') ??
                    '') ??
            0,
    };
    final equalShare = amount / _selectedParticipants.length;
    final isEffectivelyEqual = splitsMap.values
        .every((v) => (v - equalShare).abs() <= 1);
    final finalSplits = isEffectivelyEqual ? <String, double>{} : splitsMap;

    setState(() => _isSaving = true);
    try {
      final tx = TransactionModel(
        id: widget.existing?.id ?? '',
        groupId: widget.groupId,
        description: _descController.text.trim(),
        amount: amount,
        currency: _selectedCurrency,
        paidBy: _selectedPaidBy,
        participants: _selectedParticipants.toList(),
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        splits: finalSplits,
        receiptUrl: _pendingReceiptUrl,
      );

      if (widget.existing == null) {
        await _txService.addTransaction(widget.groupId, tx);
      } else {
        await _txService.updateTransaction(widget.groupId, tx);
      }

      if (mounted) Navigator.pop(context);
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
    final isEdit = widget.existing != null;
    final members = widget.memberNames;
    final rawAmount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '')) ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Transaksi' : 'Tambah Transaksi',
          style: AppTypography.h2,
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: const BackButton(),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Deskripsi ──────────────────────────────────────────────
              _FieldLabel('Deskripsi'),
              TextFormField(
                controller: _descController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Mis. Makan siang, bayar bensin',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Deskripsi wajib diisi'
                    : null,
              ),
              const SizedBox(height: 20),

              // ── Jumlah + Currency ──────────────────────────────────────
              _FieldLabel('Jumlah'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: '0',
                        prefixText:
                            _selectedCurrency == 'IDR' ? 'Rp ' : null,
                      ),
                      onChanged: (_) => setState(_onAmountOrCurrencyChanged),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Jumlah wajib diisi';
                        }
                        final v = double.tryParse(
                            val.trim().replaceAll(',', ''));
                        if (v == null || v <= 0) return 'Jumlah tidak valid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CurrencyDropdown(
                    value: _selectedCurrency,
                    onChanged: (val) {
                      setState(() => _selectedCurrency = val!);
                      _onAmountOrCurrencyChanged();
                    },
                  ),
                ],
              ),

              // IDR conversion hint
              if (_selectedCurrency != 'IDR') ...[
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isConverting
                      ? const Row(children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textSecondary),
                          ),
                          SizedBox(width: 8),
                          Text('Mengambil kurs...'),
                        ])
                      : _idrEquivalent != null
                          ? Row(children: [
                              const Icon(Icons.sync_alt_rounded,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                '≈ ${CurrencyService.formatCurrency(_idrEquivalent!, 'IDR')}',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text('  (kurs hari ini)',
                                  style: AppTypography.caption),
                            ])
                          : const SizedBox.shrink(),
                ),
              ],
              const SizedBox(height: 20),

              // ── Dibayar oleh ───────────────────────────────────────────
              _FieldLabel('Dibayar oleh'),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedPaidBy),
                initialValue: _selectedPaidBy,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.account_circle_outlined),
                ),
                items: members.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedPaidBy = val!),
              ),
              const SizedBox(height: 4),
              Text("${_bankDetailsOf(_selectedPaidBy).keys.first}: ${_bankDetailsOf(_selectedPaidBy).values.first}"),

              const SizedBox(height: 20),

              // ── Dibagi ke siapa + nominal per orang ───────────────────
              Row(
                children: [
                  Expanded(
                    child: _FieldLabel('Dibagi ke siapa?'),
                  ),
                  if (rawAmount > 0 && _selectedParticipants.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(_recalculateSplits),
                      child: Row(
                        children: [
                          const Icon(Icons.refresh_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Reset sama rata',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: members.entries.map((e) {
                    final uid = e.key;
                    final name = e.value;
                    final isSelected = _selectedParticipants.contains(uid);
                    return Column(
                      children: [
                        CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) => setState(() {
                            if (val == true) {
                              _selectedParticipants.add(uid);
                            } else {
                              _selectedParticipants.remove(uid);
                              _splitControllers[uid]?.text = '';
                            }
                            _recalculateSplits();
                          }),
                          title: Text(name, style: AppTypography.body),
                          activeColor: AppColors.primary,
                          checkColor: AppColors.white,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding:
                              const EdgeInsets.only(left: 12, right: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        // Input nominal — hanya tampil jika peserta dipilih
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: TextFormField(
                              controller: _splitControllers[uid],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                isDense: true,
                                prefixText: _selectedCurrency == 'IDR'
                                    ? 'Rp '
                                    : null,
                                hintText: 'Nominal tagihan $name',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),

              // ── Indikator alokasi ──────────────────────────────────────
              if (rawAmount > 0 && _selectedParticipants.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SplitIndicator(
                  total: rawAmount,
                  allocated: _splitsTotal,
                  currency: _selectedCurrency,
                ),
              ],

              const SizedBox(height: 24),
              ReceiptPickerWidget(
                groupId: widget.groupId,
                docId: (widget.existing?.id ?? ""),  // kosong saat create
                type: ReceiptType.transaction,
                onUploaded: (url) => setState(() => _pendingReceiptUrl = url),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white),
                      )
                    : Text(isEdit ? 'Simpan Perubahan' : 'Tambah Transaksi'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Split indicator ───────────────────────────────────────────────────────────

class _SplitIndicator extends StatelessWidget {
  final double total;
  final double allocated;
  final String currency;

  const _SplitIndicator({
    required this.total,
    required this.allocated,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = total - allocated;
    final isBalanced = remaining.abs() <= 1;
    final color = isBalanced ? AppColors.positive : AppColors.negative;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isBalanced ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isBalanced
                  ? 'Semua sudah teralokasi'
                  : remaining > 0
                      ? 'Sisa ${CurrencyService.formatCurrency(remaining, currency)} belum dialokasikan'
                      : 'Kelebihan ${CurrencyService.formatCurrency(remaining.abs(), currency)}',
              style: AppTypography.body.copyWith(color: color),
            ),
          ),
          Text(
            '${CurrencyService.formatCurrency(allocated, currency)} / ${CurrencyService.formatCurrency(total, currency)}',
            style: AppTypography.caption
                .copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Currency dropdown ─────────────────────────────────────────────────────────

class _CurrencyDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _CurrencyDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          items: CurrencyService.supportedCurrencies
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c,
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w600)),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ── Section label helper ──────────────────────────────────────────────────────

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