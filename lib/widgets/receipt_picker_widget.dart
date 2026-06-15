import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paybar_app/core/theme/app_colors.dart';
import 'package:paybar_app/core/theme/app_typography.dart';
import 'package:paybar_app/services/receipt_service.dart';
import 'package:paybar_app/services/cloudinary_service.dart';

// ---------------------------------------------------------------------------
// RECEIPT PICKER WIDGET
//
// Widget reusable untuk upload/lihat/hapus nota.
// Dipakai di TransactionScreen dan SettlementScreen.
//
// Cara pakai di TransactionScreen (form tambah/edit):
//   ReceiptPickerWidget(
//     groupId: widget.groupId,
//     docId: tx.id,           // kosong string jika belum ada (mode create)
//     type: ReceiptType.transaction,
//     existingUrl: tx.receiptUrl,
//     onUploaded: (url) => setState(() => _receiptUrl = url),
//     onRemoved: () => setState(() => _receiptUrl = null),
//   )
//
// Cara pakai di SettlementScreen (card settlement):
//   ReceiptPickerWidget(
//     groupId: widget.groupId,
//     docId: settlement.settlementId,
//     type: ReceiptType.settlement,
//     existingUrl: settlement.receiptUrl,
//     readOnly: !isFromMe,    // penerima hanya bisa lihat
//   )
// ---------------------------------------------------------------------------

enum ReceiptType { transaction, settlement }

class ReceiptPickerWidget extends StatefulWidget {
  final String groupId;

  /// ID dokumen transaksi atau settlement.
  /// Boleh kosong ('') untuk mode create — upload dilakukan setelah doc dibuat,
  /// lalu panggil [onUploaded] untuk simpan URL sementara di parent.
  final String docId;

  final ReceiptType type;

  /// URL nota yang sudah ada (dari Firestore). Null jika belum ada.
  final String? existingUrl;

  /// Jika true, hanya tampilkan tombol lihat — tidak bisa upload/hapus.
  final bool readOnly;

  /// Dipanggil setelah upload berhasil dengan URL hasil upload.
  final void Function(String url)? onUploaded;

  /// Dipanggil setelah nota berhasil dihapus.
  final void Function()? onRemoved;

  const ReceiptPickerWidget({
    super.key,
    required this.groupId,
    required this.docId,
    required this.type,
    this.existingUrl,
    this.readOnly = false,
    this.onUploaded,
    this.onRemoved,
  });

  @override
  State<ReceiptPickerWidget> createState() => _ReceiptPickerWidgetState();
}

class _ReceiptPickerWidgetState extends State<ReceiptPickerWidget> {
  final _receiptService = ReceiptService();
  final _picker = ImagePicker();

  bool _isUploading = false;
  String? _localUrl; // URL sementara setelah upload, sebelum widget rebuild

  String? get _effectiveUrl => _localUrl ?? widget.existingUrl;
  bool get _hasReceipt => _effectiveUrl != null && _effectiveUrl!.isNotEmpty;

  // ── Pilih & Upload ────────────────────────────────────────────────────────

  Future<void> _pickAndUpload(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80, // kompresi ringan, hemat bandwidth & storage
      maxWidth: 1920,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(picked.path);
      final String url;

      // Jika docId belum ada (mode create), upload dulu ke Cloudinary
      // tanpa update Firestore — parent yang simpan URL via onUploaded
      if (widget.docId.isEmpty) {
        final result = await _receiptService.uploadToCloudinaryOnly(file,
            groupId: widget.groupId, type: widget.type);
        url = result;
      } else {
        url = widget.type == ReceiptType.transaction
            ? await _receiptService.uploadTransactionReceipt(
                groupId: widget.groupId,
                transactionId: widget.docId,
                imageFile: file,
              )
            : await _receiptService.uploadSettlementReceipt(
                groupId: widget.groupId,
                settlementId: widget.docId,
                imageFile: file,
              );
      }

      setState(() => _localUrl = url);
      widget.onUploaded?.call(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota berhasil diunggah! 🧾')),
        );
      }
    } on CloudinaryFileTooLargeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on CloudinaryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on Exception catch (e) {
      if (mounted) {
        final msg = e.toString().contains('not-authorized')
            ? 'Kamu tidak punya izin untuk upload nota ini.'
            : 'Aduh, gagal upload. Coba lagi ya.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Hapus ─────────────────────────────────────────────────────────────────

  Future<void> _remove() async {
    if (widget.docId.isEmpty) {
      // Mode create: hapus lokal saja
      setState(() => _localUrl = null);
      widget.onRemoved?.call();
      return;
    }

    setState(() => _isUploading = true);
    try {
      if (widget.type == ReceiptType.transaction) {
        await _receiptService.removeTransactionReceipt(
          groupId: widget.groupId,
          transactionId: widget.docId,
        );
      } else {
        await _receiptService.removeSettlementReceipt(
          groupId: widget.groupId,
          settlementId: widget.docId,
        );
      }
      setState(() => _localUrl = null);
      widget.onRemoved?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota dihapus.')),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        final msg = e.toString().contains('not-authorized')
            ? 'Kamu tidak punya izin hapus nota ini.'
            : 'Aduh, ada gangguan. Coba lagi ya.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Source picker bottom sheet ─────────────────────────────────────────────

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
              const SizedBox(height: 16),
              Text('Pilih sumber foto', style: AppTypography.h2),
              const SizedBox(height: 16),
              _SourceTile(
                icon: Icons.camera_alt_outlined,
                label: 'Kamera',
                subtitle: 'Foto langsung sekarang',
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUpload(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              _SourceTile(
                icon: Icons.photo_library_outlined,
                label: 'Galeri',
                subtitle: 'Pilih dari foto tersimpan',
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUpload(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Lihat nota fullscreen ──────────────────────────────────────────────────

  void _viewFullscreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ReceiptFullscreenViewer(url: _effectiveUrl!),
      ),
    );
  }

  // ── Konfirmasi hapus ──────────────────────────────────────────────────────

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.white,
        title: Text('Hapus nota?', style: AppTypography.h2),
        content: Text(
          'Foto nota akan dihapus dari catatan ini.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _remove();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.negative),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isUploading) return _buildUploading();
    if (_hasReceipt) return _buildHasReceipt();
    if (widget.readOnly) return _buildReadOnlyEmpty();
    return _buildEmpty();
  }

  // State: sedang upload
  Widget _buildUploading() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
            SizedBox(width: 12),
            Text('Mengunggah nota...'),
          ],
        ),
      ),
    );
  }

  // State: sudah ada nota
  Widget _buildHasReceipt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail klik untuk fullscreen
        GestureDetector(
          onTap: _viewFullscreen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Image.network(
                  _effectiveUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 160,
                      color: AppColors.background,
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: AppColors.background,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: AppColors.textSecondary, size: 36),
                    ),
                  ),
                ),
                // Overlay icon lihat
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.zoom_in_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!widget.readOnly) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showSourcePicker,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Ganti'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showDeleteConfirm,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Hapus'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.negative,
                    side: const BorderSide(color: AppColors.negative),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // State: readOnly, belum ada nota
  Widget _buildReadOnlyEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Text(
            'Belum ada nota diunggah.',
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // State: belum ada nota, bisa upload
  Widget _buildEmpty() {
    return GestureDetector(
      onTap: _showSourcePicker,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Unggah nota (opsional)',
                style: AppTypography.body.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SOURCE TILE
// ---------------------------------------------------------------------------

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w500)),
                Text(subtitle, style: AppTypography.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FULLSCREEN VIEWER
// ---------------------------------------------------------------------------

class _ReceiptFullscreenViewer extends StatelessWidget {
  final String url;
  const _ReceiptFullscreenViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Nota', style: AppTypography.h2.copyWith(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            },
            errorBuilder: (_, __, ___) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 48),
                  const SizedBox(height: 12),
                  Text('Gambar tidak bisa dimuat.',
                      style: AppTypography.body
                          .copyWith(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}