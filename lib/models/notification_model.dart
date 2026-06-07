import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { transaction, settlement, reminder, general }

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? groupId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.groupId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: _parseType(data['type'] as String? ?? ''),
      groupId: data['groupId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'type': type.name,
        'groupId': groupId,
        'isRead': isRead,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static NotificationType _parseType(String raw) {
    switch (raw) {
      case 'transaction':
        return NotificationType.transaction;
      case 'settlement':
        return NotificationType.settlement;
      case 'reminder':
        return NotificationType.reminder;
      default:
        return NotificationType.general;
    }
  }
}