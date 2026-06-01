import 'dart:async';
import 'package:flutter/material.dart';
import 'package:paybar_app/core/theme/app_colors.dart';
import 'package:paybar_app/core/theme/app_typography.dart';
import 'package:paybar_app/models/transaction_model.dart';
import 'package:paybar_app/services/currency_service.dart';
import 'package:paybar_app/services/transaction_service.dart';

class TransactionScreen extends StatefulWidget {
  final String groupId;
  final Map<String, String> memberNames; // uid → name
  final String currentUserUid;
  final TransactionModel? existing;

  const TransactionScreen({
    super.key,
    required this.groupId,
    required this.memberNames,
    required this.currentUserUid,
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

  double? _idrEquivalent;
  bool _isConverting = false;
  bool _isSaving = false;
  Timer? _debounce;

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

    if (existing != null) {
      _descController.text = existing.description;
      _amountController.text = existing.amount.toString();
      if (existing.currency != 'IDR') _fetchConversion();
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onAmountOrCurrencyChanged() {
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

    setState(() => _isSaving = true);
    try {
      final amount = double.parse(
        _amountController.text.trim().replaceAll(',', ''),
      );

      final tx = TransactionModel(
        id: widget.existing?.id ?? '',
        description: _descController.text.trim(),
        amount: amount,
        currency: _selectedCurrency,
        paidBy: _selectedPaidBy,
        participants: _selectedParticipants.toList(),
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
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

    // Per-person calculation
    final rawAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    final perPerson = _selectedParticipants.isNotEmpty && rawAmount > 0
        ? rawAmount / _selectedParticipants.length
        : null;

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
              // Deskripsi
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

              // Jumlah + Currency
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
                      onChanged: (_) => setState(() {
                        _onAmountOrCurrencyChanged();
                      }),
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
                      ? const Row(
                          children: [
                            SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textSecondary)),
                            SizedBox(width: 8),
                            Text('Mengambil kurs...'),
                          ],
                        )
                      : _idrEquivalent != null
                          ? Row(
                              children: [
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
                                Text(
                                  '  (kurs hari ini)',
                                  style: AppTypography.caption,
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                ),
              ],
              const SizedBox(height: 20),

              // Dibayar oleh
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
                onChanged: (val) =>
                    setState(() => _selectedPaidBy = val!),
              ),
              const SizedBox(height: 20),

              // Dibagi ke
              _FieldLabel('Dibagi ke siapa?'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: members.entries.map((e) {
                    final isSelected =
                        _selectedParticipants.contains(e.key);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (val) => setState(() {
                        if (val == true) {
                          _selectedParticipants.add(e.key);
                        } else {
                          _selectedParticipants.remove(e.key);
                        }
                      }),
                      title: Text(e.value, style: AppTypography.body),
                      activeColor: AppColors.primary,
                      checkColor: AppColors.white,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    );
                  }).toList(),
                ),
              ),

              // Per-person calculation
              if (perPerson != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calculate_outlined,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Per orang (${_selectedParticipants.length} org): ',
                        style: AppTypography.body
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      Text(
                        CurrencyService.formatCurrency(
                            perPerson, _selectedCurrency),
                        style: AppTypography.nominal
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
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

// Currency dropdown
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

// Section label helper
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
