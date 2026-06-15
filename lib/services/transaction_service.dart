import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paybar_app/models/transaction_model.dart';
import 'package:paybar_app/services/currency_service.dart';

class TransactionService {
  final _firestore = FirebaseFirestore.instance;
  final _currencyService = CurrencyService();

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
  /// Map: uid -> net amount dalam IDR (positif = piutang/harus menerima,
  /// negatif = hutang/harus membayar). Transaksi dengan mata uang selain IDR
  /// dikonversi dulu lewat Frankfurter API supaya bisa dijumlah secara adil.
  ///
  /// Dipakai untuk menampilkan "siapa kurang berapa" di Detail Grup,
  /// dan bisa dipakai ulang oleh fitur lain (mis. Dashboard) untuk
  /// agregasi hutang-piutang lintas grup.
  Stream<Map<String, double>> getGroupBalances(String groupId) {
    return getTransactions(groupId).asyncMap(_balancesInIdr);
  }

  Future<Map<String, double>> _balancesInIdr(
      List<TransactionModel> transactions) async {
    // Cache kurs per mata uang supaya tidak memanggil API berulang kali
    // untuk transaksi dengan mata uang yang sama.
    final rateCache = <String, double>{};
    final amountsInIdr = <double>[];

    for (final tx in transactions) {
      if (tx.currency == 'IDR') {
        amountsInIdr.add(tx.amount);
        continue;
      }
      final rate = rateCache[tx.currency] ??=
          await _currencyService.convertToIdr(1, tx.currency);
      amountsInIdr.add(tx.amount * rate);
    }

    return calculateBalances(transactions, amountsInIdr: amountsInIdr);
  }

  /// Hitung saldo bersih per anggota dari daftar transaksi.
  /// [amountsInIdr] opsional — sediakan jika amount transaksi perlu
  /// dikonversi dulu ke IDR (urutannya harus sejajar dengan [transactions]).
  /// Tanpa parameter ini, `tx.amount` dipakai apa adanya (anggap sudah IDR).
  ///
  /// Pembayaran yang sudah dikonfirmasi (`tx.paidAmounts`) dikurangkan dari
  /// tagihan masing-masing anggota, jadi pelunasan sebagian (partial) ikut
  /// mengurangi saldo hutang meski belum lunas total.
  static Map<String, double> calculateBalances(
    List<TransactionModel> transactions, {
    List<double>? amountsInIdr,
  }) {
    final balances = <String, double>{};
    for (var i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      if (tx.participants.isEmpty) continue;

      // amount: gunakan nilai IDR jika tersedia (untuk transaksi non-IDR),
      // fallback ke tx.amount apa adanya.
      final amount = amountsInIdr != null ? amountsInIdr[i] : tx.amount;
      // Skala konversi IDR, dipakai juga untuk mengonversi paidAmounts.
      final scale = tx.amount > 0 ? amount / tx.amount : 1.0;

      for (final uid in tx.participants) {
        if (uid == tx.paidBy) continue;

        // Jika ada splits custom, proporsi tagihan uid diambil dari splits
        // lalu diskala ke amount (supaya konversi IDR ikut terhitung).
        final double share;
        if (tx.splits.isNotEmpty && tx.amount > 0) {
          share = (tx.splits[uid] ?? 0) / tx.amount * amount;
        } else {
          share = amount / tx.participants.length;
        }

        // Kurangi pembayaran yang sudah terkonfirmasi (partial/full).
        final paid = (tx.paidAmounts[uid] ?? 0) * scale;
        final remaining = share - paid;

        balances[uid] = (balances[uid] ?? 0) - remaining;
        balances[tx.paidBy] = (balances[tx.paidBy] ?? 0) + remaining;
      }
    }
    return balances;
  }

  /// Catat pembayaran yang sudah dikonfirmasi penerima ke transaksi terkait,
  /// supaya Rekapitulasi langsung mencerminkan pelunasan sebagian/penuh.
  /// [delta] positif saat settlement dikonfirmasi, negatif saat dibatalkan
  /// (unconfirm).
  Future<void> adjustPaidAmount(
    String groupId,
    String txId,
    String uid,
    double delta,
  ) {
    return _txRef(groupId).doc(txId).update({
      'paidAmounts.$uid': FieldValue.increment(delta),
    });
  }
}
