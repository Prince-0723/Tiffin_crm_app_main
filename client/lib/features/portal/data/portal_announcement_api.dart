import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

final class PortalAnnouncementDto {
  PortalAnnouncementDto({required this.text, this.updatedAt});

  final String text;
  final DateTime? updatedAt;
}

final class PortalAnnouncementSaveDto {
  PortalAnnouncementSaveDto({
    required this.text,
    this.updatedAt,
    required this.notifiedCount,
  });

  final String text;
  final DateTime? updatedAt;
  final int notifiedCount;
}

abstract final class PortalAnnouncementApi {
  static Future<PortalAnnouncementDto> get() async {
    final response =
        await DioClient.instance.get(ApiEndpoints.usersPortalAnnouncement);
    final data = parseData(response);
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid response');
    }
    return PortalAnnouncementDto(
      text: data['text'] as String? ?? '',
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  static Future<PortalAnnouncementSaveDto> put({
    required String text,
    required bool notifyAllCustomers,
  }) async {
    final response = await DioClient.instance.put(
      ApiEndpoints.usersPortalAnnouncement,
      data: <String, dynamic>{
        'text': text,
        'notifyAllCustomers': notifyAllCustomers,
      },
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid response');
    }
    return PortalAnnouncementSaveDto(
      text: data['text'] as String? ?? '',
      updatedAt: _parseDate(data['updatedAt']),
      notifiedCount: (data['notifiedCount'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
