import 'package:flutter/foundation.dart';
import '../models/ground_model.dart';
import 'api_client.dart';

/// The admin's side of the Django API: approving new grounds.
class AdminApi {
  /// Bumped after a ground is approved or rejected, so lists reload.
  static final groundsChanged = ValueNotifier<int>(0);

  /// How many grounds are pending, approved and rejected.
  static Future<Map<GroundStatus, int>> fetchCounts() async {
    final data = await ApiClient.get('/admin/summary/') as Map<String, dynamic>;
    return {for (final status in GroundStatus.values) status: data[status.name] as int? ?? 0};
  }

  static Future<List<AdminGround>> fetchGrounds(GroundStatus status) async {
    final data = await ApiClient.get('/admin/grounds/', query: {'status': status.name}) as List;
    return data.map((json) => AdminGround.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Every ground, whatever its status, whose name, area, address or owner
  /// (name, phone, email) contains [text].
  static Future<List<AdminGround>> searchGrounds(String text) async {
    final data = await ApiClient.get('/admin/grounds/', query: {'search': text}) as List;
    return data.map((json) => AdminGround.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// One ground, with a link to its lalpurja photo.
  static Future<AdminGround> fetchGround(String id) async =>
      AdminGround.fromJson(await ApiClient.get('/admin/grounds/$id/') as Map<String, dynamic>);

  static Future<AdminGround> approve(String id) => _review(id, 'approve');

  static Future<AdminGround> reject(String id, String reason) => _review(id, 'reject', {'review_note': reason});

  static Future<AdminGround> _review(String id, String decision, [Map<String, dynamic>? body]) async {
    final data = await ApiClient.post('/admin/grounds/$id/$decision/', body);
    groundsChanged.value++;
    return AdminGround.fromJson(data as Map<String, dynamic>);
  }
}

/// A ground as the admin reviews it: the ground plus who owns it.
class AdminGround {
  final GroundModel ground;
  final String ownerName;
  final String ownerPhone;
  final String ownerEmail;
  final String ownerAddress;
  final String? documentUrl; // only when fetched one at a time
  final DateTime submittedAt;

  const AdminGround({
    required this.ground,
    required this.ownerName,
    required this.ownerPhone,
    required this.ownerEmail,
    required this.ownerAddress,
    required this.documentUrl,
    required this.submittedAt,
  });

  factory AdminGround.fromJson(Map<String, dynamic> json) => AdminGround(
        ground: GroundModel.fromJson(json),
        ownerName: json['owner_name'] as String? ?? '',
        ownerPhone: json['owner_phone'] as String? ?? '',
        ownerEmail: json['owner_email'] as String? ?? '',
        ownerAddress: json['owner_address'] as String? ?? '',
        documentUrl: json['document_url'] as String?,
        submittedAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
