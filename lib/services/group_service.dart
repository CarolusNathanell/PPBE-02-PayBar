import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paybar_app/models/group_model.dart';

class GroupService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  Future<DocumentReference> createGroup(String name) {
    return _firestore.collection('groups').add({
      'name': name.trim(),
      'members': [_uid],
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<GroupModel> getGroupById(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .map(GroupModel.fromFirestore);
  }

  Stream<List<GroupModel>> getGroups() {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: _uid)
        .snapshots()
        .map((s) {
      final list = s.docs.map(GroupModel.fromFirestore).toList();
      // Sort client-side — hindari kebutuhan composite index Firestore
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> updateGroupName(String groupId, String name) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .update({'name': name.trim()});
  }

  Future<void> inviteMember(String groupId, String email) async {
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) throw Exception('user-not-found');

    final invitedUid = query.docs.first.id;
    final groupDoc =
        await _firestore.collection('groups').doc(groupId).get();
    final members =
        List<String>.from((groupDoc.data() as Map)['members'] ?? []);

    if (members.contains(invitedUid)) throw Exception('already-member');

    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([invitedUid]),
    });
  }

  // Keluar grup; hapus grup jika member terakhir
  Future<void> leaveOrDeleteGroup(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (!doc.exists) return;
    final members =
        List<String>.from((doc.data() as Map)['members'] ?? []);

    if (members.length <= 1) {
      await _firestore.collection('groups').doc(groupId).delete();
    } else {
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([_uid]),
      });
    }
  }

  Future<void> deleteGroup(String groupId) {
    return _firestore.collection('groups').doc(groupId).delete();
  }

  // Batch-read nama anggota dari koleksi users
  Future<Map<String, String>> getMemberNames(List<String> uids) async {
    final names = <String, String>{};
    for (final uid in uids) {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        names[uid] = (doc.data() as Map)['name'] ?? 'Anggota';
      }
    }
    return names;
  }
}
