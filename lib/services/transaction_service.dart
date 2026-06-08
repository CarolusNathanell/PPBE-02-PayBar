import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paybar_app/models/transaction_model.dart';

class TransactionService {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference _txRef(String groupId) => _firestore
      .collection('groups')
      .doc(groupId)
      .collection('transactions');

  Future<void> addTransaction(String groupId, TransactionModel tx) {
    return _txRef(groupId).add(tx.toFirestore());
  }

  Stream<List<TransactionModel>> getTransactions(String groupId) {
    return _txRef(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(TransactionModel.fromFirestore).toList());
  }

  Future<void> updateTransaction(String groupId, TransactionModel tx) {
    return _txRef(groupId).doc(tx.id).update(tx.toFirestore());
  }

  Future<void> deleteTransaction(String groupId, String txId) {
    return _txRef(groupId).doc(txId).delete();
  }

  /// Saldo bersih tiap anggota grup berdasarkan seluruh transaksi (realtime).
  /// Map: uid -> net amount (positif = piutang/harus menerima,
  /// negatif = hutang/harus membayar, dalam mata uang asal transaksi).
  ///
  /// Dipakai untuk menampilkan "siapa kurang berapa" di Detail Grup,
  /// dan bisa dipakai ulang oleh fitur lain (mis. Dashboard) untuk
  /// agregasi hutang-piutang lintas grup.
  Stream<Map<String, double>> getGroupBalances(String groupId) {
    return getTransactions(groupId).map(calculateBalances);
  }

  static Map<String, double> calculateBalances(
      List<TransactionModel> transactions) {
    final balances = <String, double>{};
    for (final tx in transactions) {
      if (tx.participants.isEmpty) continue;
      final share = tx.amount / tx.participants.length;
      for (final uid in tx.participants) {
        if (uid == tx.paidBy) continue;
        balances[uid] = (balances[uid] ?? 0) - share;
        balances[tx.paidBy] = (balances[tx.paidBy] ?? 0) + share;
      }
    }
    return balances;
  }
}
