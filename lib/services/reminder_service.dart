import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paybar_app/models/reminder_model.dart';
import 'package:paybar_app/services/notification_service.dart';

class ReminderService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _notifService = NotificationService();

  String get _uid => _auth.currentUser!.uid;

  CollectionReference get _remindersRef =>
      _firestore.collection('users').doc(_uid).collection('reminders');

  // CREATE
  Future<void> addReminder(ReminderModel reminder) async {
    final docRef = await _remindersRef.add(reminder.toFirestore());

    // Jadwalkan local notification di due date jam 08:00
    await _notifService.scheduleReminderNotification(
      id: docRef.id.hashCode,
      title: '🔔 Pengingat: ${reminder.title}',
      body: 'Jangan lupa bayar! Jatuh tempo hari ini.',
      scheduledDate: reminder.dueDate,
    );

    // Simpan ke notification inbox Firestore
    await _notifService.saveReminderToInbox(
      title: 'Pengingat Baru Ditambahkan',
      body: '${reminder.title} — jatuh tempo ${_formatDate(reminder.dueDate)}',
    );
  }

  // READ
  Stream<List<ReminderModel>> getReminders() {
    return _remindersRef
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReminderModel.fromFirestore(doc))
            .toList());
  }

  // UPDATE
  Future<void> updateReminder(ReminderModel reminder) async {
    await _remindersRef.doc(reminder.id).update(reminder.toFirestore());

    // Cancel notif lama, jadwalkan ulang
    await _notifService.cancelReminderNotification(reminder.id.hashCode);

    if (!reminder.isDone) {
      await _notifService.scheduleReminderNotification(
        id: reminder.id.hashCode,
        title: '🔔 Pengingat: ${reminder.title}',
        body: 'Jangan lupa bayar! Jatuh tempo hari ini.',
        scheduledDate: reminder.dueDate,
      );
    }
  }

  // TOGGLE isDone — selesai/batal selesai
  Future<void> toggleDone(String reminderId, bool isDone) async {
    await _remindersRef.doc(reminderId).update({'isDone': isDone});

    if (isDone) {
      // Cancel notif jika sudah selesai
      await _notifService.cancelReminderNotification(reminderId.hashCode);
    } else {
      // Reschedule jika di-undo
      final doc = await _remindersRef.doc(reminderId).get();
      final reminder = ReminderModel.fromFirestore(doc);
      await _notifService.scheduleReminderNotification(
        id: reminderId.hashCode,
        title: '🔔 Pengingat: ${reminder.title}',
        body: 'Jangan lupa bayar! Jatuh tempo hari ini.',
        scheduledDate: reminder.dueDate,
      );
    }
  }

  // DELETE — hapus reminder + cancel notif
  Future<void> deleteReminder(String reminderId) async {
    await _remindersRef.doc(reminderId).delete();
    await _notifService.cancelReminderNotification(reminderId.hashCode);
  }

  // Helper format tanggal
  String _formatDate(DateTime date) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }
}