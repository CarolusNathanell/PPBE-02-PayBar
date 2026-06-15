import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String groupId; // referensi ke groups/{groupId}
  final String description;
  final double amount;
  final String currency;
  final String paidBy; // uid
  final List<String> participants; // uids
  final DateTime createdAt;
  // uid -> nominal tagihan masing-masing (dalam currency transaksi).
  // Map kosong berarti bagi sama rata (amount / participants.length).
  final Map<String, double> splits;

  // uid -> total pembayaran yang sudah dikonfirmasi (dalam currency transaksi).
  // Diupdate saat settlement untuk uid tersebut dikonfirmasi penerima.
  final Map<String, double> paidAmounts;

  final String? receiptUrl;

  const TransactionModel({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.currency,
    required this.paidBy,
    required this.participants,
    required this.createdAt,
    this.splits = const {},
    this.paidAmounts = const {},
    this.receiptUrl,
  });

  bool get isEqualSplit => splits.isEmpty;

  double get perPerson =>
      participants.isEmpty ? 0 : amount / participants.length;

  // Tagihan orang tertentu: pakai splits jika ada, fallback ke sama rata.
  double splitFor(String uid) =>
      splits.isEmpty ? perPerson : (splits[uid] ?? 0);

  // Sisa tagihan orang tertentu setelah dikurangi pembayaran terkonfirmasi.
  double remainingFor(String uid) =>
      splitFor(uid) - (paidAmounts[uid] ?? 0);

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      groupId: d['groupId'] ?? '',
      description: d['description'] ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      currency: d['currency'] ?? 'IDR',
      paidBy: d['paidBy'] ?? '',
      participants: List<String>.from(d['participants'] ?? []),
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      splits: (d['splits'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      paidAmounts: (d['paidAmounts'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      receiptUrl: d['receiptUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'groupId': groupId,
        'description': description,
        'amount': amount,
        'currency': currency,
        'paidBy': paidBy,
        'participants': participants,
        'createdAt': Timestamp.fromDate(createdAt),
        // Simpan splits hanya jika tidak sama rata; hemat storage.
        if (splits.isNotEmpty) 'splits': splits,
        if (paidAmounts.isNotEmpty) 'paidAmounts': paidAmounts,
        if (receiptUrl != null) 'receiptUrl': receiptUrl,
      };

  TransactionModel copyWith({
    String? id,
    String? groupId,
    String? description,
    double? amount,
    String? currency,
    String? paidBy,
    List<String>? participants,
    DateTime? createdAt,
    Map<String, double>? splits,
    Map<String, double>? paidAmounts,
    String? receiptUrl,
  }) =>
      TransactionModel(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        paidBy: paidBy ?? this.paidBy,
        participants: participants ?? this.participants,
        createdAt: createdAt ?? this.createdAt,
        splits: splits ?? this.splits,
        paidAmounts: paidAmounts ?? this.paidAmounts,
        receiptUrl: receiptUrl ?? this.receiptUrl,
      );
}