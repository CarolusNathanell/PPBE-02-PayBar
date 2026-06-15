import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ---------------------------------------------------------------------------
// CLOUDINARY SERVICE
//
// Upload gambar nota ke Cloudinary menggunakan Unsigned Upload Preset.
// Tidak butuh backend/Cloud Function — aman untuk free tier.
//
// Setup di Cloudinary Dashboard:
//   1. Settings → Upload → Upload Presets → Add Upload Preset
//   2. Signing Mode: Unsigned
//   3. Folder: paybar/receipts (opsional tapi rapi)
//   4. Salin preset name ke CloudinaryConfig.uploadPreset di bawah
//
// Variabel yang perlu diisi tim sebelum build:
//   - CloudinaryConfig.cloudName   → Settings → Account → Cloud name
//   - CloudinaryConfig.uploadPreset → nama preset dari langkah 2
// ---------------------------------------------------------------------------

class CloudinaryConfig {
  // TODO: Ganti dengan nilai dari Cloudinary Dashboard sebelum build
  static const cloudName = 'dxxkk3cwr';
  static const uploadPreset = '897ce218-a6ce-4b80-8553-92f9219817f4';

  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
}

// ---------------------------------------------------------------------------
// HASIL UPLOAD
// ---------------------------------------------------------------------------

class CloudinaryUploadResult {
  final String url;         // URL publik yang bisa langsung dipakai di Image.network()
  final String secureUrl;   // HTTPS version — selalu gunakan ini
  final String publicId;    // ID untuk delete/transform nanti jika perlu
  final int bytes;          // ukuran file bytes

  const CloudinaryUploadResult({
    required this.url,
    required this.secureUrl,
    required this.publicId,
    required this.bytes,
  });

  factory CloudinaryUploadResult.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadResult(
      url: json['url'] as String,
      secureUrl: json['secure_url'] as String,
      publicId: json['public_id'] as String,
      bytes: (json['bytes'] as num).toInt(),
    );
  }
}

// ---------------------------------------------------------------------------
// SERVICE
// ---------------------------------------------------------------------------

class CloudinaryService {
  /// Upload satu file gambar ke Cloudinary.
  ///
  /// [file]   — file yang dipilih user (dari image_picker)
  /// [folder] — subfolder di Cloudinary, default 'paybar/receipts'
  ///
  /// Melempar [CloudinaryException] jika upload gagal.
  /// Melempar [CloudinaryFileTooLargeException] jika file > 10MB.
  Future<CloudinaryUploadResult> uploadReceipt(
    File file, {
    String folder = 'paybar/receipts',
  }) async {
    // Validasi ukuran: Cloudinary free tier max 10MB per file
    final bytes = await file.length();
    const maxBytes = 10 * 1024 * 1024; // 10MB
    if (bytes > maxBytes) {
      throw CloudinaryFileTooLargeException(
        'Ukuran file terlalu besar (${(bytes / 1024 / 1024).toStringAsFixed(1)}MB). Maksimum 10MB.',
      );
    }

    final uri = Uri.parse(CloudinaryConfig.uploadUrl);

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..fields['folder'] = folder
      // Tambah timestamp sebagai context agar mudah filter di dashboard Cloudinary
      ..fields['context'] = 'app=paybar|uploaded_at=${DateTime.now().toIso8601String()}'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw CloudinaryException('Upload timeout. Cek koneksi dan coba lagi.'),
    );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return CloudinaryUploadResult.fromJson(json);
    } else {
      // Parse error dari Cloudinary jika ada
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = (json['error'] as Map?)?.entries.first.value?.toString() ??
            'Upload gagal (${response.statusCode})';
        throw CloudinaryException(msg);
      } catch (_) {
        throw CloudinaryException('Upload gagal (${response.statusCode}). Coba lagi ya.');
      }
    }
  }

  /// Delete gambar dari Cloudinary menggunakan publicId.
  /// Catatan: delete dari client-side butuh signed request (perlu secret key).
  /// Untuk free tier tanpa backend, biarkan gambar lama di Cloudinary
  /// dan cukup overwrite URL di Firestore saat user upload ulang.
  ///
  /// Jika perlu delete, implementasikan via Cloud Function (Orang 1).
  // Future<void> deleteReceipt(String publicId) async { ... }
}

// ---------------------------------------------------------------------------
// EXCEPTIONS
// ---------------------------------------------------------------------------

class CloudinaryException implements Exception {
  final String message;
  CloudinaryException(this.message);

  @override
  String toString() => message;
}

class CloudinaryFileTooLargeException extends CloudinaryException {
  CloudinaryFileTooLargeException(super.message);
}