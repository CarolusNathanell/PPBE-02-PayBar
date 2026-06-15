import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paybar_app/core/theme/app_colors.dart';
import 'package:paybar_app/core/theme/app_typography.dart';
import 'package:paybar_app/services/auth_service.dart';
import 'package:paybar_app/services/profile_service.dart';

// ---------------------------------------------------------------------------
// DAFTAR BANK INDONESIA (pilihan dropdown)
// ---------------------------------------------------------------------------

const _bankList = [
  'BCA',
  'Mandiri',
  'BRI',
  'BNI',
  'CIMB Niaga',
  'Danamon',
  'Permata',
  'BTN',
  'OCBC NISP',
  'Maybank',
  'Jenius (BTPN)',
  'Jago',
  'SeaBank',
  'Blu by BCA Digital',
  'Neobank',
  'Allo Bank',
  'Gopay (GoPay Tabungan)',
  'OVO',
  'Dana',
  'ShopeePay',
  'Lainnya',
];

// ---------------------------------------------------------------------------
// PROFILE SCREEN
// ---------------------------------------------------------------------------

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileService = ProfileService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Profil', style: AppTypography.h2),
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: StreamBuilder<UserModel>(
        stream: profileService.getProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'Aduh, gagal memuat profil. Coba lagi ya.',
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            );
          }

          final user = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [
              // ── Avatar & nama ──────────────────────────────────────────────
              _AvatarHeader(user: user),
              const SizedBox(height: 24),

              // ── Info akun ──────────────────────────────────────────────────
              _SectionLabel('Informasi Akun'),
              _InfoCard(
                items: [
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Nama',
                    value: user.name,
                    onEdit: () => _showEditNameSheet(context, user.name),
                  ),
                  _InfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user.email,
                    // Email tidak bisa diubah langsung (Firebase limitation)
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Info bank ──────────────────────────────────────────────────
              _SectionLabel('Informasi Bank'),
              _InfoCard(
                items: [
                  _InfoRow(
                    icon: Icons.account_balance_outlined,
                    label: 'Bank',
                    value: user.bankName ?? '—',
                    isEmpty: !user.hasBankInfo,
                    onEdit: () =>
                        _showEditBankSheet(context, user),
                  ),
                  _InfoRow(
                    icon: Icons.credit_card_outlined,
                    label: 'Nomor Rekening',
                    value: user.accountNumber != null
                        ? _maskAccountNumber(user.accountNumber!)
                        : '—',
                    isEmpty: !user.hasBankInfo,
                    onEdit: () =>
                        _showEditBankSheet(context, user),
                  ),
                ],
              ),
              if (user.hasBankInfo) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showRemoveBankDialog(context),
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: AppColors.negative),
                    label: Text(
                      'Hapus info bank',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.negative),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ── Keamanan ───────────────────────────────────────────────────
              _SectionLabel('Keamanan'),
              _ActionCard(
                items: [
                  _ActionRow(
                    icon: Icons.lock_outline_rounded,
                    label: 'Ganti Password',
                    onTap: () => _showChangePasswordSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Lainnya ────────────────────────────────────────────────────
              _SectionLabel('Lainnya'),
              _ActionCard(
                items: [
                  _ActionRow(
                    icon: Icons.logout_rounded,
                    label: 'Keluar',
                    color: AppColors.negative,
                    onTap: () => _showLogoutDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => _showDeleteAccountDialog(context),
                  child: Text(
                    'Hapus akun',
                    style:
                        AppTypography.caption.copyWith(color: AppColors.negative),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Mask nomor rekening: tampilkan 4 digit terakhir saja.
  String _maskAccountNumber(String acc) {
    if (acc.length <= 4) return acc;
    final masked = '•' * (acc.length - 4);
    return '$masked${acc.substring(acc.length - 4)}';
  }

  // ── Bottom Sheet: Edit Nama ─────────────────────────────────────────────────

  void _showEditNameSheet(BuildContext context, String currentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditNameSheet(currentName: currentName),
    );
  }

  // ── Bottom Sheet: Edit Bank ─────────────────────────────────────────────────

  void _showEditBankSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditBankSheet(user: user),
    );
  }

  // ── Bottom Sheet: Ganti Password ────────────────────────────────────────────

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  // ── Dialog: Hapus Info Bank ─────────────────────────────────────────────────

  void _showRemoveBankDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        title: Text('Hapus info bank?', style: AppTypography.h2),
        content: Text(
          'Nomor rekening dan nama bank akan dihapus dari profilmu.',
          style:
              AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ProfileService().removeBankInfo();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Info bank dihapus.')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Aduh, ada gangguan. Coba lagi ya.')),
                  );
                }
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

  // ── Dialog: Logout ──────────────────────────────────────────────────────────

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        title: Text('Keluar?', style: AppTypography.h2),
        content: Text(
          'Kamu akan keluar dari akun ini.',
          style:
              AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().signOut();
              // main.dart StreamBuilder authStateChanges otomatis redirect ke LoginScreen
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.negative),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  // ── Dialog: Hapus Akun ──────────────────────────────────────────────────────

  void _showDeleteAccountDialog(BuildContext context) {
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        title: Text('Hapus akun?', style: AppTypography.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Akun dan semua datamu akan dihapus permanen. Aksi ini tidak bisa di-undo.',
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Masukkan password untuk konfirmasi',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (passController.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ProfileService()
                    .deleteAccount(passController.text);
                // authStateChanges otomatis redirect ke LoginScreen
              } on Exception catch (e) {
                if (context.mounted) {
                  final msg = e.toString().contains('wrong-password') ||
                          e.toString().contains('invalid-credential')
                      ? 'Password salah. Coba lagi ya.'
                      : 'Aduh, ada gangguan. Coba lagi ya.';
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(msg)));
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.negative),
            child: const Text('Hapus Akun'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AVATAR HEADER
// ---------------------------------------------------------------------------

class _AvatarHeader extends StatelessWidget {
  final UserModel user;
  const _AvatarHeader({required this.user});

  String get _initials {
    final parts = user.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _initials,
            style: AppTypography.h1.copyWith(
              color: Colors.white,
              fontSize: 28,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(user.name, style: AppTypography.h2),
        const SizedBox(height: 4),
        Text(
          user.email,
          style:
              AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        if (user.hasBankInfo) ...[
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.settledBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_balance_outlined,
                    size: 12, color: AppColors.settledFg),
                const SizedBox(width: 4),
                Text(
                  user.bankName!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.settledFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION LABEL
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// INFO CARD (read-only rows dengan tombol edit)
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items
            .asMap()
            .entries
            .map((e) => Column(
                  children: [
                    e.value,
                    if (e.key < items.length - 1)
                      const Divider(
                          height: 1, indent: 16, endIndent: 16,
                          color: AppColors.border),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isEmpty;
  final VoidCallback? onEdit;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isEmpty = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.body.copyWith(
                    color: isEmpty
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontStyle:
                        isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined,
                    size: 14, color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ACTION CARD (tombol navigasi tanpa nilai)
// ---------------------------------------------------------------------------

class _ActionCard extends StatelessWidget {
  final List<_ActionRow> items;
  const _ActionCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items
            .asMap()
            .entries
            .map((e) => Column(
                  children: [
                    e.value,
                    if (e.key < items.length - 1)
                      const Divider(
                          height: 1, indent: 16, endIndent: 16,
                          color: AppColors.border),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: AppTypography.body.copyWith(color: color)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BOTTOM SHEET: EDIT NAMA
// ---------------------------------------------------------------------------

class _EditNameSheet extends StatefulWidget {
  final String currentName;
  const _EditNameSheet({required this.currentName});

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController _controller;
  final _service = ProfileService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.text.trim() == widget.currentName) {
      Navigator.pop(context);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _service.updateName(_controller.text);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama berhasil diperbarui! ✅')),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().contains('name-empty')
              ? 'Nama tidak boleh kosong.'
              : 'Aduh, ada gangguan. Coba lagi ya.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Edit Nama',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Nama lengkap',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 24),
          _SaveButton(isSaving: _isSaving, onPressed: _save),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BOTTOM SHEET: EDIT BANK
// ---------------------------------------------------------------------------

class _EditBankSheet extends StatefulWidget {
  final UserModel user;
  const _EditBankSheet({required this.user});

  @override
  State<_EditBankSheet> createState() => _EditBankSheetState();
}

class _EditBankSheetState extends State<_EditBankSheet> {
  final _accController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _service = ProfileService();

  String? _selectedBank;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Isi nilai awal dari profil yang ada
    _selectedBank = widget.user.bankName;
    _accController.text = widget.user.accountNumber ?? '';
  }

  @override
  void dispose() {
    _accController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _service.updateBankInfo(
        bankName: _selectedBank ?? '',
        accountNumber: _accController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Info bank disimpan! 🏦')),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        final msg = e.toString().contains('bank-name-empty')
            ? 'Pilih nama bank dulu ya.'
            : e.toString().contains('account-number-empty')
                ? 'Nomor rekening tidak boleh kosong.'
                : e.toString().contains('account-number-invalid')
                    ? 'Nomor rekening harus 6–20 digit angka.'
                    : 'Aduh, ada gangguan. Coba lagi ya.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Info Bank',
      icon: Icons.account_balance_outlined,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Pilih bank ───────────────────────────────────────────────
            _FieldLabel('Bank'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBank,
                  isExpanded: true,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'Pilih bank',
                      style: AppTypography.body
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  icon: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  items: _bankList
                      .map((b) => DropdownMenuItem(
                            value: b,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(b, style: AppTypography.body),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedBank = val),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Nomor rekening ───────────────────────────────────────────
            _FieldLabel('Nomor Rekening'),
            TextFormField(
              controller: _accController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Contoh: 1234567890',
                prefixIcon: Icon(Icons.credit_card_outlined),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Wajib diisi';
                if (!RegExp(r'^\d{6,20}$').hasMatch(val)) {
                  return 'Masukkan 6-20 digit angka';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Digunakan teman untuk transfer ke kamu.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SaveButton(isSaving: _isSaving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BOTTOM SHEET: GANTI PASSWORD
// ---------------------------------------------------------------------------

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _service = ProfileService();

  bool _isSaving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _service.updatePassword(
        currentPassword: _currentPassController.text,
        newPassword: _newPassController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password berhasil diubah! 🔐')),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        final msg = e.toString().contains('wrong-password') ||
                e.toString().contains('invalid-credential')
            ? 'Password lama salah.'
            : e.toString().contains('password-too-short')
                ? 'Password baru minimal 6 karakter.'
                : 'Aduh, ada gangguan. Coba lagi ya.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Ganti Password',
      icon: Icons.lock_outline_rounded,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _PasswordField(
              controller: _currentPassController,
              label: 'Password Lama',
              hint: 'Masukkan password saat ini',
              visible: _showCurrent,
              onToggle: () =>
                  setState(() => _showCurrent = !_showCurrent),
              validator: (val) =>
                  (val == null || val.isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            _PasswordField(
              controller: _newPassController,
              label: 'Password Baru',
              hint: 'Minimal 6 karakter',
              visible: _showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Wajib diisi';
                if (val.length < 6) return 'Minimal 6 karakter';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _PasswordField(
              controller: _confirmPassController,
              label: 'Konfirmasi Password Baru',
              hint: 'Ulangi password baru',
              visible: _showConfirm,
              onToggle: () =>
                  setState(() => _showConfirm = !_showConfirm),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Wajib diisi';
                if (val != _newPassController.text) {
                  return 'Password tidak cocok';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _SaveButton(isSaving: _isSaving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SHARED SHEET SCAFFOLD
// ---------------------------------------------------------------------------

class _SheetScaffold extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SheetScaffold({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
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
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: AppTypography.h2),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SHARED WIDGETS
// ---------------------------------------------------------------------------

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
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onPressed;

  const _SaveButton({required this.isSaving, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSaving ? null : onPressed,
        child: isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.white),
              )
            : const Text('Simpan'),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool visible;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.visible,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        TextFormField(
          controller: controller,
          obscureText: !visible,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondary,
                size: 18,
              ),
              onPressed: onToggle,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}