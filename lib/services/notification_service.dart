import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  // Set untuk track members tiap grup — untuk deteksi anggota keluar
  final Map<String, Set<String>> _groupMembers = {};

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Hardcode Asia/Jakarta
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

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

  // Firestore Listener: auto notif tanpa Cloud Functions
  void _startGroupListeners() {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _firestore
        .collection('groups')
        .where('members', arrayContains: uid)
        .snapshots()
        .listen((QuerySnapshot groupSnap) async {
      for (final DocumentChange change in groupSnap.docChanges) {
        final String groupId = change.doc.id;
        final Map<String, dynamic> data =
            change.doc.data() as Map<String, dynamic>;
        final String groupName = data['name'] as String? ?? 'sebuah grup';
        final List<dynamic> members =
            data['members'] as List<dynamic>? ?? [];
        final String createdBy = data['createdBy'] as String? ?? '';

        if (change.type == DocumentChangeType.added) {
          // Deteksi dimasukkan ke grup
          if (createdBy == uid) {
            // user adalah creator, tidak perlu notif
          } else {
            // Cek apakah ini grup yang baru saja user ditambahkan
            final DocumentSnapshot flagDoc = await _firestore
                .collection('users')
                .doc(uid)
                .collection('notified_groups')
                .doc(groupId)
                .get();

            if (!flagDoc.exists) {
              // Belum pernah dinotif untuk grup ini
              await _firestore
                  .collection('users')
                  .doc(uid)
                  .collection('notified_groups')
                  .doc(groupId)
                  .set({'notifiedAt': FieldValue.serverTimestamp()});

              const String title = 'Kamu Ditambahkan ke Grup! 👥';
              final String body =
                  'Kamu sekarang jadi anggota grup "$groupName"';
              await _saveToInbox(
                uid: uid,
                title: title,
                body: body,
                type: 'general',
                groupId: groupId,
              );
              await showLocalNotification(title: title, body: body);
            }
          }

          // Simpan members awal untuk tracking keluar
          _groupMembers[groupId] = Set<String>.from(
              members.map((e) => e.toString()));

          // Daftarkan listener kalau belum ada
          if (!_listenedGroups.contains(groupId)) {
            _listenedGroups.add(groupId);
            _listenNewTransactions(uid, groupId, groupName);
            _listenNewSettlements(uid, groupId, groupName);
            _listenSettlementConfirmations(uid, groupId, groupName);
          }
        }

        if (change.type == DocumentChangeType.modified) {
          // Deteksi anggota keluar dari grup
          final Set<String> newMembers =
              Set<String>.from(members.map((e) => e.toString()));
          final Set<String> oldMembers =
              _groupMembers[groupId] ?? <String>{};

          final Set<String> removedMembers =
              oldMembers.difference(newMembers);

          for (final String removedUid in removedMembers) {
            if (removedUid == uid) continue; // skip diri sendiri

            // Ambil nama anggota yang keluar
            final DocumentSnapshot userDoc =
                await _firestore.collection('users').doc(removedUid).get();
            final Map<String, dynamic>? userData =
                userDoc.data() as Map<String, dynamic>?;
            final String userName =
                userData?['name'] as String? ?? 'Seseorang';

            const String title = 'Anggota Keluar dari Grup 👋';
            final String body =
                '$userName keluar dari grup "$groupName"';

            await _saveToInbox(
              uid: uid,
              title: title,
              body: body,
              type: 'general',
              groupId: groupId,
            );
            await showLocalNotification(title: title, body: body);
          }

          // Update cache members
          _groupMembers[groupId] = newMembers;
        }
      }
    });
  }

  // Listener: Transaksi baru (notif ke pembuat + anggota yang ikut)
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
        final List<dynamic> participants =
            tx['participants'] as List<dynamic>? ?? [];
        final String desc = tx['description'] as String? ?? '';
        final dynamic amount = tx['amount'] ?? 0;

        if (paidBy == uid) {
          // Notif konfirmasi ke pembuat transaksi
          const String title = 'Transaksi Tercatat! ✅';
          final String body =
              '"$desc" Rp$amount berhasil dicatat di grup $groupName';

          await _saveToInbox(
            uid: uid,
            title: title,
            body: body,
            type: 'transaction',
            groupId: groupId,
          );
          await showLocalNotification(title: title, body: body);
        } else if (participants.contains(uid)) {
          // Notif ke anggota yang ikut bayar (bukan pembuat)
          final DocumentSnapshot payerDoc =
              await _firestore.collection('users').doc(paidBy).get();
          final Map<String, dynamic>? payerData =
              payerDoc.data() as Map<String, dynamic>?;
          final String payerName =
              payerData?['name'] as String? ?? 'Seseorang';

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
      }
    });
  }

  // Listener: Settlement baru (notif ke penerima (toUid))
  void _listenNewSettlements(
      String uid, String groupId, String groupName) {
    final Timestamp startTime = Timestamp.now();

    _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .snapshots()
        .listen((QuerySnapshot snap) async {
      for (final DocumentChange change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final Map<String, dynamic> settlement =
            change.doc.data() as Map<String, dynamic>;

        // Kalau tidak ada createdAt, pakai waktu sekarang sebagai fallback
        final Timestamp? createdAt =
            settlement['createdAt'] as Timestamp? ??
            settlement['settledAt'] as Timestamp?;

        // Kalau sama sekali tidak ada timestamp, tetap proses
        if (createdAt != null && createdAt.compareTo(startTime) <= 0) continue;

        // Hanya notif ke toUid (penerima yang harus konfirmasi)
        final String toUid = settlement['toUid'] as String? ?? '';
        if (toUid != uid) continue;

        final String fromUid = settlement['fromUid'] as String? ?? '';
        final DocumentSnapshot fromDoc =
            await _firestore.collection('users').doc(fromUid).get();
        final Map<String, dynamic>? fromData =
            fromDoc.data() as Map<String, dynamic>?;
        final String fromName = fromData?['name'] as String? ?? 'Seseorang';

        final dynamic amount = settlement['amount'] ?? 0;

        const String title = 'Ada Pelunasan Masuk! 💸';
        final String body =
            '$fromName klaim udah bayar Rp$amount di grup $groupName. Konfirmasi ya!';

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

  // Listener: Settlement dikonfirmasi (notif ke pembayar (fromUid))
  void _listenSettlementConfirmations(
      String uid, String groupId, String groupName) {
    final Timestamp startTime = Timestamp.now();

    _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .where('fromUid', isEqualTo: uid)
        .snapshots()
        .listen((QuerySnapshot snap) async {
      for (final DocumentChange change in snap.docChanges) {
        // Hanya deteksi update (bukan added)
        if (change.type != DocumentChangeType.modified) continue;

        final Map<String, dynamic> settlement =
            change.doc.data() as Map<String, dynamic>;
        final bool settled = settlement['settled'] as bool? ?? false;
        if (!settled) continue;

        final Timestamp? settledAt = settlement['settledAt'] as Timestamp?;
        if (settledAt == null || settledAt.compareTo(startTime) <= 0) continue;

        final String toUid = settlement['toUid'] as String? ?? '';
        final DocumentSnapshot toDoc =
            await _firestore.collection('users').doc(toUid).get();
        final Map<String, dynamic>? toData =
            toDoc.data() as Map<String, dynamic>?;
        final String toName = toData?['name'] as String? ?? 'Seseorang';

        final dynamic amount = settlement['amount'] ?? 0;

        const String title = 'Pelunasan Dikonfirmasi! ✅';
        final String body =
            '$toName udah konfirmasi pembayaran Rp$amount di grup $groupName';

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

  // Local notification: immediate
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

  // Scheduled notification — untuk reminder
  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tz.TZDateTime scheduledTz = tz.TZDateTime(
      tz.getLocation('Asia/Jakarta'),
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      7,
      2,
    );

    // Kalau sudah lewat, skip
    final now = tz.TZDateTime.now(tz.getLocation('Asia/Jakarta'));
    if (scheduledTz.isBefore(now)) {
      debugPrint('[Reminder] Waktu sudah lewat, tidak dijadwalkan: $scheduledTz');
      return;
    }

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
          autoCancel: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'reminder_$id',
    );

    debugPrint('[Reminder Scheduled] ✅ "$title" → $scheduledTz');
  }

  Future<void> cancelReminderNotification(int id) async {
    await _local.cancel(id: id);
  }

  Future<void> cancelAllReminders() async {
    await _local.cancelAll();
  }

  // Inbox
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

  // hapus semua notifikasi
  Future<void> deleteAllNotifications() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final QuerySnapshot snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .get();

    final WriteBatch batch = _firestore.batch();
    for (final DocumentSnapshot doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
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