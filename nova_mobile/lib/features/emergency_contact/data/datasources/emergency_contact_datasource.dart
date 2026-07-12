import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';

class EmergencyContact {
  final String id;
  final String contactName;
  final String phoneNumber;

  const EmergencyContact({
    required this.id,
    required this.contactName,
    required this.phoneNumber,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        id: j['id'] as String,
        contactName: j['contact_name'] as String,
        phoneNumber: j['phone_number'] as String,
      );
}

class EmergencyContactDatasource {
  final Dio _dio;

  EmergencyContactDatasource(this._dio);

  Future<EmergencyContact?> getContact() async {
    try {
      final res = await _dio.get(AppConstants.emergencyContactPath);
      return EmergencyContact.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<EmergencyContact> setContact(String name, String phone) async {
    final res = await _dio.put(
      AppConstants.emergencyContactPath,
      data: {'contact_name': name, 'phone_number': phone},
    );
    return EmergencyContact.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteContact() async {
    await _dio.delete(AppConstants.emergencyContactPath);
  }
}
