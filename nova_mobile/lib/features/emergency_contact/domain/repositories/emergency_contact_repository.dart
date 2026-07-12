import '../../data/datasources/emergency_contact_datasource.dart';

abstract class EmergencyContactRepository {
  Future<EmergencyContact?> getContact();
  Future<EmergencyContact> setContact(String name, String phone);
  Future<void> deleteContact();
}

class EmergencyContactRepositoryImpl implements EmergencyContactRepository {
  final EmergencyContactDatasource _ds;

  EmergencyContactRepositoryImpl(this._ds);

  @override
  Future<EmergencyContact?> getContact() => _ds.getContact();

  @override
  Future<EmergencyContact> setContact(String name, String phone) =>
      _ds.setContact(name, phone);

  @override
  Future<void> deleteContact() => _ds.deleteContact();
}
