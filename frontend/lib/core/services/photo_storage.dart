import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_exception.dart';

/// Photos in Supabase Storage. Each user may only write inside their own
/// folder, `<bucket>/<user id>/` (see supabase/migrations/*_avatars.sql,
/// *_ground_photos.sql and *_ground_documents.sql).
class PhotoStorage {
  static const avatars = PhotoStorage._('avatars');
  static const groundPhotos = PhotoStorage._('ground-photos');

  /// Private: lalpurja photos, seen only by the owner and admins.
  static const groundDocuments = PhotoStorage._('ground-documents', isPublic: false);

  static const _contentTypes = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'};

  final String bucket;
  final bool isPublic;

  const PhotoStorage._(this.bucket, {this.isPublic = true});

  StorageFileApi get _files => Supabase.instance.client.storage.from(bucket);

  /// Uploads [photo] and returns its public URL, or for a private bucket its
  /// path ("<user id>/photo-123.jpg"). A new file name each time means phones
  /// never show a stale cached copy of the old photo.
  Future<String> upload(String userId, XFile photo) async {
    final extension = photo.name.split('.').last.toLowerCase();
    final contentType = _contentTypes[extension];
    if (contentType == null) throw ApiException('Please choose a JPG or PNG photo.');

    final path = '$userId/photo-${DateTime.now().millisecondsSinceEpoch}.$extension';
    try {
      await _files.uploadBinary(path, await photo.readAsBytes(), fileOptions: FileOptions(contentType: contentType));
    } on StorageException catch (e) {
      throw ApiException(e.statusCode == '413' ? 'That photo is too large. Please choose a smaller one.'
          : "Couldn't upload the photo. Please try again.");
    } on Exception {
      throw ApiException("Couldn't upload the photo. Check your internet connection and try again.");
    }
    return isPublic ? _files.getPublicUrl(path) : path;
  }

  /// A short-lived link to a photo in a private bucket, or null if it can't
  /// be made right now.
  Future<String?> signedUrl(String path) async {
    try {
      return await _files.createSignedUrl(path, 600);
    } on Exception {
      return null;
    }
  }

  /// Best effort: if this fails, an old photo just takes up a little space.
  /// Takes what [upload] returned.
  Future<void> delete(String uploaded) async {
    var path = uploaded;
    if (isPublic) {
      final marker = '/object/public/$bucket/';
      final start = uploaded.indexOf(marker);
      if (start < 0) return;
      path = uploaded.substring(start + marker.length);
    }
    try {
      await _files.remove([path]);
    } on Exception {
      // ignore
    }
  }
}
