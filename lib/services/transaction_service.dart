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
}
