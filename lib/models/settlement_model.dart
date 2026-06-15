import 'package:cloud_firestore/cloud_firestore.dart';

class SettlementModel {
  final String settlementId;
  final String transactionId;
  final String fromUid;       // uid yang membayar hutang
  final String toUid;         // uid yang menerima (paidBy di transaction)
  final double amount;
  final bool settled;         // false = menunggu konfirmasi penerima, true = lunas
  final DateTime? settledAt;  // diisi saat confirmed
  
  /// Diupload oleh fromUid sebagai bukti kepada toUid.
  final String? receiptUrl;

  const SettlementModel({
    required this.settlementId,
    required this.transactionId,
    required this.fromUid,
    required this.toUid,
    required this.amount,
    required this.settled,
    this.settledAt,
    this.receiptUrl,
  });

  /// Settlement sudah dikonfirmasi oleh penerima
  bool get isConfirmed => settled && settledAt != null;

  /// Settlement menunggu konfirmasi
  bool get isPending => !settled;

  factory SettlementModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SettlementModel(
      settlementId: doc.id,
      transactionId: d['transactionId'] ?? '',
      fromUid: d['fromUid'] ?? '',
      toUid: d['toUid'] ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      settled: d['settled'] as bool? ?? false,
      settledAt: d['settledAt'] != null
          ? (d['settledAt'] as Timestamp).toDate()
          : null,
      receiptUrl: d['receiptUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'transactionId': transactionId,
        'fromUid': fromUid,
        'toUid': toUid,
        'amount': amount,
        'settled': settled,
        'settledAt':
            settledAt != null ? Timestamp.fromDate(settledAt!) : null,
        if (receiptUrl != null) 'receiptUrl': receiptUrl,
      };

  SettlementModel copyWith({
    String? settlementId,
    String? transactionId,
    String? fromUid,
    String? toUid,
    double? amount,
    bool? settled,
    DateTime? settledAt,
    String? receiptUrl,
  }) =>
      SettlementModel(
        settlementId: settlementId ?? this.settlementId,
        transactionId: transactionId ?? this.transactionId,
        fromUid: fromUid ?? this.fromUid,
        toUid: toUid ?? this.toUid,
        amount: amount ?? this.amount,
        settled: settled ?? this.settled,
        settledAt: settledAt ?? this.settledAt,
        receiptUrl: receiptUrl ?? this.receiptUrl,
      );
}