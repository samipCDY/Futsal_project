import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_exception.dart';

/// Profile photos in Supabase Storage. Each user may only write inside their
/// own folder, `avatars/<user id>/` (see supabase/migrations/*_avatars.sql).
class AvatarStorage {
  static const _bucketName = 'avatars';
  static const _contentTypes = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'};

  static StorageFileApi get _bucket => Supabase.instance.client.storage.from(_bucketName);

  /// Uploads [photo] and returns its public URL. A new file name each time
  /// means phones never show a stale cached copy of the old photo.
  static Future<String> upload(String userId, XFile photo) async {
    final extension = photo.name.split('.').last.toLowerCase();
    final contentType = _contentTypes[extension];
    if (contentType == null) throw ApiException('Please choose a JPG or PNG photo.');

    final path = '$userId/avatar-${DateTime.now().millisecondsSinceEpoch}.$extension';
    try {
      await _bucket.uploadBinary(path, await photo.readAsBytes(), fileOptions: FileOptions(contentType: contentType));
    } on StorageException catch (e) {
      throw ApiException(e.statusCode == '413' ? 'That photo is too large. Please choose a smaller one.'
          : "Couldn't upload the photo. Please try again.");
    } on Exception {
      throw ApiException("Couldn't upload the photo. Check your internet connection and try again.");
    }
    return _bucket.getPublicUrl(path);
  }

  /// Best effort: if this fails, an old photo just takes up a little space.
  static Future<void> delete(String publicUrl) async {
    const marker = '/object/public/$_bucketName/';
    final start = publicUrl.indexOf(marker);
    if (start < 0) return;
    try {
      await _bucket.remove([publicUrl.substring(start + marker.length)]);
    } on Exception {
      // ignore
    }
  }
}
