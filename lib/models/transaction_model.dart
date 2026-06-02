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

  const TransactionModel({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.currency,
    required this.paidBy,
    required this.participants,
    required this.createdAt,
  });

  double get perPerson =>
      participants.isEmpty ? 0 : amount / participants.length;

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
      );
}
