import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paybar_app/models/reminder_model.dart';

class ReminderService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  CollectionReference get _remindersRef =>
      _firestore.collection('users').doc(_uid).collection('reminders');

  // CREATE
  Future<void> addReminder(ReminderModel reminder) async {
    await _remindersRef.add(reminder.toFirestore());
  }

  // READ - stream realtime
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
  }

  // UPDATE
  Future<void> toggleDone(String reminderId, bool isDone) async {
    await _remindersRef.doc(reminderId).update({'isDone': isDone});
  }

  // DELETE
  Future<void> deleteReminder(String reminderId) async {
    await _remindersRef.doc(reminderId).delete();
  }
}