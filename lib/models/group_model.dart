import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final List<String> members;
  final String createdBy;
  final DateTime createdAt;

  const GroupModel({
    required this.id,
    required this.name,
    required this.members,
    required this.createdBy,
    required this.createdAt,
  });

  bool isCreator(String uid) => createdBy == uid;

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      name: d['name'] ?? '',
      members: List<String>.from(d['members'] ?? []),
      createdBy: d['createdBy'] ?? '',
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'members': members,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  GroupModel copyWith({
    String? id,
    String? name,
    List<String>? members,
    String? createdBy,
    DateTime? createdAt,
  }) =>
      GroupModel(
        id: id ?? this.id,
        name: name ?? this.name,
        members: members ?? this.members,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
      );
}
