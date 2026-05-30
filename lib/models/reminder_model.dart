import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  final String id;
  final String title;
  final DateTime dueDate;
  final String? groupId;
  final bool isDone;

  ReminderModel({
    required this.id,
    required this.title,
    required this.dueDate,
    this.groupId,
    this.isDone = false,
  });

  factory ReminderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReminderModel(
      id: doc.id,
      title: data['title'] ?? '',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      groupId: data['groupId'],
      isDone: data['isDone'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'dueDate': Timestamp.fromDate(dueDate),
      'groupId': groupId,
      'isDone': isDone,
    };
  }

  ReminderModel copyWith({
    String? id,
    String? title,
    DateTime? dueDate,
    String? groupId,
    bool? isDone,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      groupId: groupId ?? this.groupId,
      isDone: isDone ?? this.isDone,
    );
  }
}