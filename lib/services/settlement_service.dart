import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paybar_app/models/settlement_model.dart';
import 'package:paybar_app/services/transaction_service.dart';

class SettlementService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _transactionService = TransactionService();

  String get _uid => _auth.currentUser!.uid;

  CollectionReference _settlementRef(String groupId) => _firestore
      .collection('groups')
      .doc(groupId)
      .collection('settlements');

  /// Buat settlement baru (settled = false, menunggu konfirmasi penerima).
  /// Dipanggil oleh fromUid (orang yang mengaku sudah bayar).
  Future<DocumentReference> createSettlement(
    String groupId, {
    required String transactionId,
    required String toUid,
    required double amount,
    File? imageFile,
  }) async {
    
    final doc = await _settlementRef(groupId).add({
      'transactionId': transactionId,
      'fromUid': _uid,
      'toUid': toUid,
      'amount': amount,
      'settled': false,
      'settledAt': null,
    });
    
    final docSnap = await doc.get();
    final data = docSnap.data() as Map<String, dynamic>;
    
    return _settlementRef(groupId).doc(data['id']);
  }
  
  /// Stream semua settlement di grup — diurutkan dari terbaru.
  Stream<List<SettlementModel>> getSettlements(String groupId) {
    return _settlementRef(groupId)
        .orderBy('settledAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(SettlementModel.fromFirestore).toList());
  }

  /// Stream settlement yang menunggu konfirmasi dari currentUser (toUid == _uid).
  Stream<List<SettlementModel>> getPendingForMe(String groupId) {
    return _settlementRef(groupId)
        .where('toUid', isEqualTo: _uid)
        .where('settled', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.map(SettlementModel.fromFirestore).toList());
  }

  /// Stream settlement yang sudah dikirim oleh currentUser (fromUid == _uid).
  Stream<List<SettlementModel>> getSentByMe(String groupId) {
    return _settlementRef(groupId)
        .where('fromUid', isEqualTo: _uid)
        .snapshots()
        .map((s) {
      final list = s.docs.map(SettlementModel.fromFirestore).toList();
      list.sort((a, b) {
        // Pending dulu, lalu terbaru
        if (a.settled != b.settled) return a.settled ? 1 : -1;
        final aTime = a.settledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.settledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Konfirmasi pembayaran — hanya bisa dilakukan oleh toUid (penerima / paidBy).
  /// Melempar [Exception] jika currentUser bukan penerima.
  ///
  /// Setelah dikonfirmasi, nominal settlement (bisa pelunasan sebagian/partial)
  /// dicatat ke `paidAmounts` transaksi terkait supaya Rekapitulasi langsung
  /// mengurangi tagihan fromUid.
  Future<void> confirmSettlement(
      String groupId, String settlementId) async {
    final doc =
        await _settlementRef(groupId).doc(settlementId).get();
    if (!doc.exists) throw Exception('settlement-not-found');

    final data = doc.data() as Map<String, dynamic>;
    if (data['toUid'] != _uid) throw Exception('not-authorized');
    if (data['settled'] == true) throw Exception('already-settled');

    await _settlementRef(groupId).doc(settlementId).update({
      'settled': true,
      'settledAt': FieldValue.serverTimestamp(),
    });

    final String transactionId = data['transactionId'] as String;
    final String fromUid = data['fromUid'] as String;
    final double amount = (data['amount'] as num).toDouble();
    await _transactionService.adjustPaidAmount(
        groupId, transactionId, fromUid, amount);
  }

  /// Batalkan konfirmasi — hanya oleh toUid, selama settled == true.
  /// Nominal yang sebelumnya dicatat ke `paidAmounts` dikembalikan lagi
  /// supaya Rekapitulasi tetap konsisten dengan status settlement.
  Future<void> unconfirmSettlement(
      String groupId, String settlementId) async {
    final doc =
        await _settlementRef(groupId).doc(settlementId).get();
    if (!doc.exists) throw Exception('settlement-not-found');

    final data = doc.data() as Map<String, dynamic>;
    if (data['toUid'] != _uid) throw Exception('not-authorized');

    await _settlementRef(groupId).doc(settlementId).update({
      'settled': false,
      'settledAt': null,
    });

    final String transactionId = data['transactionId'] as String;
    final String fromUid = data['fromUid'] as String;
    final double amount = (data['amount'] as num).toDouble();
    await _transactionService.adjustPaidAmount(
        groupId, transactionId, fromUid, -amount);
  }

  /// Hapus settlement — hanya bisa oleh fromUid dan selama belum dikonfirmasi.
  Future<void> deleteSettlement(
      String groupId, String settlementId) async {
    final doc =
        await _settlementRef(groupId).doc(settlementId).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    if (data['fromUid'] != _uid) throw Exception('not-authorized');
    if (data['settled'] == true) throw Exception('already-confirmed');

    await _settlementRef(groupId).doc(settlementId).delete();
  }
}