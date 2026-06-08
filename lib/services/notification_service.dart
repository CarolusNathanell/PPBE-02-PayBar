import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:paybar_app/models/notification_model.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _firestore = FirebaseFirestore.instance;

  static const String _channelId = 'paybar_channel';
  static const String _channelName = 'PayBar Notifications';
  static const String _channelReminder = 'paybar_reminder';
  static const String _channelReminderName = 'PayBar Reminders';

  bool _initialized = false;
  final Set<String> _listenedGroups = {};

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    tz.initializeTimeZones();
    final String timezoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _local.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse res) {
        debugPrint('[LocalNotif] tapped: ${res.payload}');
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Notifikasi transaksi dan settlement PayBar',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelReminder,
        _channelReminderName,
        description: 'Pengingat hutang PayBar',
        importance: Importance.max,
      ),
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    await _saveFcmToken();
    _messaging.onTokenRefresh.listen(_updateFcmToken);

    _startGroupListeners();
  }

  void _startGroupListeners() {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _firestore
        .collection('groups')
        .where('members', arrayContains: uid)
        .snapshots()
        .listen((QuerySnapshot groupSnap) {
      for (final QueryDocumentSnapshot groupDoc in groupSnap.docs) {
        final String groupId = groupDoc.id;
        if (_listenedGroups.contains(groupId)) continue;
        _listenedGroups.add(groupId);

        final Map<String, dynamic> data =
            groupDoc.data() as Map<String, dynamic>;
        final String groupName = data['name'] as String? ?? 'sebuah grup';
        _listenNewTransactions(uid, groupId, groupName);
        _listenNewSettlements(uid, groupId, groupName);
      }
    });
  }

  void _listenNewTransactions(
      String uid, String groupId, String groupName) {
    final Timestamp startTime = Timestamp.now();

    _firestore
        .collection('groups')
        .doc(groupId)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((QuerySnapshot snap) async {
      for (final DocumentChange change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final Map<String, dynamic> tx =
            change.doc.data() as Map<String, dynamic>;
        final Timestamp? createdAt = tx['createdAt'] as Timestamp?;

        if (createdAt == null || createdAt.compareTo(startTime) <= 0) continue;

        final String paidBy = tx['paidBy'] as String? ?? '';
        if (paidBy == uid) continue;

        final DocumentSnapshot payerDoc =
            await _firestore.collection('users').doc(paidBy).get();
        final Map<String, dynamic>? payerData =
            payerDoc.data() as Map<String, dynamic>?;
        final String payerName = payerData?['name'] as String? ?? 'Seseorang';

        final String desc = tx['description'] as String? ?? '';
        final dynamic amount = tx['amount'] ?? 0;

        const String title = 'Tagihan Baru! 🧾';
        final String body =
            '$payerName nambahin "$desc" Rp$amount di grup $groupName';

        await _saveToInbox(
          uid: uid,
          title: title,
          body: body,
          type: 'transaction',
          groupId: groupId,
        );
        await showLocalNotification(title: title, body: body);
      }
    });
  }

  void _listenNewSettlements(
      String uid, String groupId, String groupName) {
    final Timestamp startTime = Timestamp.now();

    _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .orderBy('settledAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((QuerySnapshot snap) async {
      for (final DocumentChange change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final Map<String, dynamic> settlement =
            change.doc.data() as Map<String, dynamic>;
        final Timestamp? settledAt = settlement['settledAt'] as Timestamp?;

        if (settledAt == null || settledAt.compareTo(startTime) <= 0) continue;

        final String toUid = settlement['toUid'] as String? ?? '';
        if (toUid != uid) continue;

        final String fromUid = settlement['fromUid'] as String? ?? '';
        final DocumentSnapshot fromDoc =
            await _firestore.collection('users').doc(fromUid).get();
        final Map<String, dynamic>? fromData =
            fromDoc.data() as Map<String, dynamic>?;
        final String fromName = fromData?['name'] as String? ?? 'Seseorang';

        final dynamic amount = settlement['amount'] ?? 0;

        const String title = 'Hutang Dibayar! 💸';
        final String body =
            '$fromName udah bayar Rp$amount di grup $groupName';

        await _saveToInbox(
          uid: uid,
          title: title,
          body: body,
          type: 'settlement',
          groupId: groupId,
        );
        await showLocalNotification(title: title, body: body);
      }
    });
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final RemoteNotification? notif = message.notification;
    if (notif == null) return;
    await showLocalNotification(
      title: notif.title ?? '',
      body: notif.body ?? '',
    );
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final DateTime notifTime = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      7,
      1,
    );

    if (notifTime.isBefore(DateTime.now())) {
      final tomorrow = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day + 1,
        7,
        1,
      );
      return scheduleReminderNotification(
        id: id,
        title: title,
        body: body,
        scheduledDate: tomorrow,
      );
    }

    final tz.TZDateTime tzTime = tz.TZDateTime.from(notifTime, tz.local);

    final tz.TZDateTime scheduledTz = tz.TZDateTime(
      tz.local,
      tzTime.year,
      tzTime.month,
      tzTime.day,
      tzTime.hour,
      tzTime.minute,
    );

    await _local.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledTz,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelReminder,
          _channelReminderName,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
          channelShowBadge: true,
          ongoing: false,
          autoCancel: true,
        ),
      ),

      
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      
      payload: 'reminder_$id',
    );

    debugPrint('[Reminder Scheduled] ✅ Success! "$title" → $scheduledTz');
    debugPrint('[Reminder Scheduled] Current time: ${DateTime.now()}');

    // Cek pending notifications
    final pending = await _local.pendingNotificationRequests();
    debugPrint('📋 Total pending: ${pending.length}');
    for (var p in pending) {
      debugPrint('  - ID: ${p.id}, Title: ${p.title}');
    }
  }


  Future<void> cancelReminderNotification(int id) async {
    await _local.cancel(id: id);
  }

  Future<void> cancelAllReminders() async {
    await _local.cancelAll();
  }

  // Tambahkan method ini untuk testing (letakkan setelah scheduleReminderNotification)
Future<void> testReminderNow() async {
  // Test dengan delay 10 detik
  final testTime = DateTime.now().add(Duration(seconds: 10));
  
  await scheduleReminderNotification(
    id: 999999,
    title: '🔔 TEST REMINDER',
    body: 'Notifikasi reminder berhasil! Waktu: ${DateTime.now()}',
    scheduledDate: testTime,
  );
  
  debugPrint('⏰ Test reminder scheduled for: $testTime');
  
  // Cek pending notifications
  final pending = await _local.pendingNotificationRequests();
  debugPrint('📋 Total pending notifications: ${pending.length}');
  for (var p in pending) {
    debugPrint('  - ID: ${p.id}, Title: ${p.title}');
  }
}

  Stream<List<NotificationModel>> getNotifications() {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((QuerySnapshot snap) =>
            snap.docs.map(NotificationModel.fromDoc).toList());
  }

  Future<void> markAsRead(String notificationId) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final QuerySnapshot snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    final WriteBatch batch = _firestore.batch();
    for (final DocumentSnapshot doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> _saveToInbox({
    required String uid,
    required String title,
    required String body,
    required String type,
    String? groupId,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .add({
      'title': title,
      'body': body,
      'type': type,
      'groupId': groupId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveReminderToInbox({
    required String title,
    required String body,
  }) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _saveToInbox(
      uid: uid,
      title: title,
      body: body,
      type: 'reminder',
    );
  }

  Future<void> _saveFcmToken() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final String? token = await _messaging.getToken();
    if (token != null) {
      await _firestore
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token});
    }
  }

  Future<void> _updateFcmToken(String token) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'fcmToken': token});
  }
}