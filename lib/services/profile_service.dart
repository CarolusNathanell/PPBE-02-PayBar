import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ---------------------------------------------------------------------------
// USER MODEL
// Representasi dokumen users/{uid} di Firestore.
// Field bank ditambah di sini; field lain (fcmToken) dikelola Orang 3.
// ---------------------------------------------------------------------------

class UserModel {
  final String uid;
  final String name;
  final String email;
  final DateTime createdAt;

  /// Nama bank — contoh: 'BCA', 'Mandiri', 'BRI', dll.
  /// Null jika belum diisi.
  final String? bankName;

  /// Nomor rekening. Null jika belum diisi.
  final String? accountNumber;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
    this.bankName,
    this.accountNumber,
  });

  bool get hasBankInfo =>
      bankName != null &&
      bankName!.isNotEmpty &&
      accountNumber != null &&
      accountNumber!.isNotEmpty;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: d['name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      bankName: d['bankName'] as String?,
      accountNumber: d['accountNumber'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// PROFILE SERVICE
// ---------------------------------------------------------------------------

class ProfileService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ── READ ───────────────────────────────────────────────────────────────────

  /// Stream profil user yang sedang login — realtime.
  Stream<UserModel> getProfile() {
    return _firestore
        .collection('users')
        .doc(_uid)
        .snapshots()
        .map(UserModel.fromFirestore);
  }

  // ── UPDATE ─────────────────────────────────────────────────────────────────

  /// Update nama tampilan.
  Future<void> updateName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('name-empty');
    await _firestore.collection('users').doc(_uid).update({
      'name': trimmed,
    });
    // Sinkronkan juga ke Firebase Auth displayName
    await _auth.currentUser?.updateDisplayName(trimmed);
  }

  /// Update info bank. Keduanya harus diisi bersamaan atau keduanya kosong.
  Future<void> updateBankInfo({
    required String bankName,
    required String accountNumber,
  }) async {
    final bank = bankName.trim();
    final acc = accountNumber.trim();

    if (bank.isEmpty && acc.isNotEmpty) throw Exception('bank-name-empty');
    if (bank.isNotEmpty && acc.isEmpty) throw Exception('account-number-empty');

    // Validasi nomor rekening: hanya angka, 6–20 digit
    if (acc.isNotEmpty && !RegExp(r'^\d{6,20}$').hasMatch(acc)) {
      throw Exception('account-number-invalid');
    }

    await _firestore.collection('users').doc(_uid).update({
      'bankName': bank.isEmpty ? FieldValue.delete() : bank,
      'accountNumber': acc.isEmpty ? FieldValue.delete() : acc,
    });
  }

  /// Hapus info bank.
  Future<void> removeBankInfo() async {
    await _firestore.collection('users').doc(_uid).update({
      'bankName': FieldValue.delete(),
      'accountNumber': FieldValue.delete(),
    });
  }

  /// Update password — butuh re-autentikasi dengan password lama.
  /// Melempar [Exception] jika password lama salah atau password baru terlalu pendek.
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) throw Exception('password-too-short');

    final user = _auth.currentUser!;
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    // Re-autentikasi wajib sebelum ganti password (Firebase requirement)
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  // ── DELETE ACCOUNT ─────────────────────────────────────────────────────────

  /// Hapus akun permanen — butuh re-autentikasi.
  /// Data Firestore dibersihkan terlebih dahulu sebelum akun dihapus.
  Future<void> deleteAccount(String currentPassword) async {
    final user = _auth.currentUser!;
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);

    // Hapus dokumen user dari Firestore
    await _firestore.collection('users').doc(_uid).delete();

    // Hapus akun Firebase Auth
    await user.delete();
  }
}