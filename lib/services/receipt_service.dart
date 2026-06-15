import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paybar_app/services/cloudinary_service.dart';
import 'package:paybar_app/widgets/receipt_picker_widget.dart'
    show ReceiptType;

// ---------------------------------------------------------------------------
// RECEIPT SERVICE
//
// Jembatan antara Cloudinary (upload gambar) dan Firestore (simpan URL).
// Dipakai oleh TransactionReceiptService dan SettlementReceiptService
// melalui mixin di bawah, sehingga logika upload tidak duplikat.
//
// Path Firestore:
//   Transaksi : groups/{groupId}/transactions/{txId}  → field receiptUrl
//   Settlement: groups/{groupId}/settlements/{sId}    → field receiptUrl
// ---------------------------------------------------------------------------

class ReceiptService {
  final _cloudinary = CloudinaryService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  /// Upload ke Cloudinary saja tanpa update Firestore.
  /// Dipakai saat dokumen (transaksi/settlement) belum dibuat —
  /// parent menyimpan URL sementara, lalu pass ke toFirestore() saat save.
  Future<String> uploadToCloudinaryOnly(
    File imageFile, {
    required String groupId,
    required ReceiptType type,
  }) async {
    final folder = type == ReceiptType.transaction
        ? 'paybar/receipts/transactions/$groupId'
        : 'paybar/receipts/settlements/$groupId';
    final result = await _cloudinary.uploadReceipt(imageFile, folder: folder);
    return result.secureUrl;
  }

  // ── TRANSACTION ──────────────────────────────────────────────────────────

  /// Upload nota transaksi dan simpan URL ke Firestore.
  /// Hanya bisa dilakukan oleh paidBy (yang bayar) atau anggota grup.
  /// Returns URL yang tersimpan.
  Future<String> uploadTransactionReceipt({
    required String groupId,
    required String transactionId,
    required File imageFile,
  }) async {
    final result = await _cloudinary.uploadReceipt(
      imageFile,
      folder: 'paybar/receipts/transactions/$groupId',
    );

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('transactions')
        .doc(transactionId)
        .update({'receiptUrl': result.secureUrl});

    return result.secureUrl;
  }

  /// Hapus URL nota transaksi dari Firestore (tanpa hapus dari Cloudinary).
  Future<void> removeTransactionReceipt({
    required String groupId,
    required String transactionId,
  }) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('transactions')
        .doc(transactionId)
        .update({'receiptUrl': FieldValue.delete()});
  }

  // ── SETTLEMENT ───────────────────────────────────────────────────────────

  /// Upload bukti bayar settlement dan simpan URL ke Firestore.
  /// Hanya bisa dilakukan oleh fromUid (yang mengklaim sudah bayar).
  Future<String> uploadSettlementReceipt({
    required String groupId,
    required String settlementId,
    required File imageFile,
  }) async {
    // Validasi: hanya fromUid yang boleh upload bukti
    final doc = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .doc(settlementId)
        .get();

    if (!doc.exists) throw Exception('settlement-not-found');
    final data = doc.data() as Map<String, dynamic>;
    if (data['fromUid'] != _uid) throw Exception('not-authorized');

    final result = await _cloudinary.uploadReceipt(
      imageFile,
      folder: 'paybar/receipts/settlements/$groupId',
    );

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .doc(settlementId)
        .update({'receiptUrl': result.secureUrl});

    return result.secureUrl;
  }

  /// Hapus URL bukti bayar dari Firestore.
  Future<void> removeSettlementReceipt({
    required String groupId,
    required String settlementId,
  }) async {
    final doc = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .doc(settlementId)
        .get();

    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    if (data['fromUid'] != _uid) throw Exception('not-authorized');

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .doc(settlementId)
        .update({'receiptUrl': FieldValue.delete()});
  }
}