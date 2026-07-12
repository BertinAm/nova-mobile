import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/emergency_contact_repository.dart';
import '../../data/datasources/emergency_contact_datasource.dart';

// ─── Events ───────────────────────────────────────────────────────────────────
abstract class EmergencyContactEvent {
  const EmergencyContactEvent();
}

class LoadEmergencyContact extends EmergencyContactEvent {
  const LoadEmergencyContact();
}

class SetEmergencyContact extends EmergencyContactEvent {
  final String name;
  final String phone;
  const SetEmergencyContact(this.name, this.phone);
}

class DeleteEmergencyContact extends EmergencyContactEvent {
  const DeleteEmergencyContact();
}

// ─── States ───────────────────────────────────────────────────────────────────
abstract class EmergencyContactState {
  const EmergencyContactState();
}

class EmergencyContactLoading extends EmergencyContactState {
  const EmergencyContactLoading();
}

class EmergencyContactLoaded extends EmergencyContactState {
  final EmergencyContact? contact;
  const EmergencyContactLoaded(this.contact);
}

class EmergencyContactError extends EmergencyContactState {
  final String message;
  const EmergencyContactError(this.message);
}

// ─── Bloc ─────────────────────────────────────────────────────────────────────
class EmergencyContactBloc extends Bloc<EmergencyContactEvent, EmergencyContactState> {
  final EmergencyContactRepository _repo;

  EmergencyContactBloc(this._repo) : super(const EmergencyContactLoading()) {
    on<LoadEmergencyContact>(_onLoad);
    on<SetEmergencyContact>(_onSet);
    on<DeleteEmergencyContact>(_onDelete);
  }

  Future<void> _onLoad(LoadEmergencyContact event, Emitter<EmergencyContactState> emit) async {
    emit(const EmergencyContactLoading());
    try {
      final contact = await _repo.getContact();
      emit(EmergencyContactLoaded(contact));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        emit(const EmergencyContactError('You need to be logged in to manage your emergency contact.'));
      } else if (e.type == DioExceptionType.connectionError ||
                 e.type == DioExceptionType.connectionTimeout) {
        emit(const EmergencyContactLoaded(null)); // Graceful offline fallback
      } else {
        emit(const EmergencyContactError('Couldn\'t load your emergency contact right now. Please try again.'));
      }
    } catch (_) {
      emit(const EmergencyContactError('Something went wrong while loading your contact.'));
    }
  }

  Future<void> _onSet(SetEmergencyContact event, Emitter<EmergencyContactState> emit) async {
    emit(const EmergencyContactLoading());
    try {
      final contact = await _repo.setContact(event.name, event.phone);
      emit(EmergencyContactLoaded(contact));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        emit(const EmergencyContactError('You need to be logged in to save your contact.'));
      } else if (e.response?.statusCode == 422) {
        emit(const EmergencyContactError('Please check the name and phone number format.'));
      } else if (e.type == DioExceptionType.connectionError ||
                 e.type == DioExceptionType.connectionTimeout) {
        emit(const EmergencyContactError('You seem to be offline. Please connect to the internet and try again.'));
      } else {
        emit(const EmergencyContactError('Couldn\'t save your contact right now. Please try again.'));
      }
    } catch (_) {
      emit(const EmergencyContactError('Something went wrong while saving your contact.'));
    }
  }

  Future<void> _onDelete(DeleteEmergencyContact event, Emitter<EmergencyContactState> emit) async {
    emit(const EmergencyContactLoading());
    try {
      await _repo.deleteContact();
      emit(const EmergencyContactLoaded(null));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        emit(const EmergencyContactError('You seem to be offline. Please connect to the internet and try again.'));
      } else {
        emit(const EmergencyContactError('Couldn\'t delete your contact right now. Please try again.'));
      }
    } catch (_) {
      emit(const EmergencyContactError('Something went wrong while deleting your contact.'));
    }
  }
}
