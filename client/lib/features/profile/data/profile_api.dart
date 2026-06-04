import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

abstract final class ProfileApi {
  static Future<Map<String, dynamic>> getMe() async {
    final response = await DioClient.instance.get(ApiEndpoints.authMe);
    final data = parseData(response);
    if (data is Map<String, dynamic>) return data;
    throw ApiException('Invalid response');
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> body,
  ) async {
    final response = await DioClient.instance.put(
      ApiEndpoints.authMe,
      data: body,
    );
    final data = parseData(response);
    if (data is Map<String, dynamic>) return data;
    throw ApiException('Invalid response');
  }
}
