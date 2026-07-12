import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/tts/tts_service.dart';
import '../../domain/entities/face_entities.dart';
import '../../domain/usecases/face_usecases.dart';

abstract class FaceEvent extends Equatable {
  const FaceEvent();
  @override
  List<Object?> get props => [];
}

class LoadContacts extends FaceEvent {
  const LoadContacts();
}

class EnrollContact extends FaceEvent {
  final String name;
  const EnrollContact(this.name);
  @override
  List<Object?> get props => [name];
}

class RecogniseFace extends FaceEvent {
  const RecogniseFace();
}

class DeleteContact extends FaceEvent {
  final String id;
  const DeleteContact(this.id);
  @override
  List<Object?> get props => [id];
}

abstract class FaceState extends Equatable {
  const FaceState();
  @override
  List<Object?> get props => [];
}

class FaceInitial extends FaceState {
  const FaceInitial();
}

class FaceLoading extends FaceState {
  const FaceLoading();
}

class FaceReady extends FaceState {
  final List<EnrolledContact> contacts;
  final FaceRecognitionResult? lastResult;
  const FaceReady({required this.contacts, this.lastResult});
  @override
  List<Object?> get props => [contacts, lastResult];
}

class FaceError extends FaceState {
  final String message;
  const FaceError(this.message);
  @override
  List<Object?> get props => [message];
}

class FaceBloc extends Bloc<FaceEvent, FaceState> {
  final GetContactsUseCase _getContacts;
  final EnrollFaceUseCase _enrollFace;
  final RecogniseFaceUseCase _recogniseFace;
  final DeleteContactUseCase _deleteContact;
  final CameraService _camera;
  final TtsService _tts;
  final AppDatabase _db;

  FaceBloc(
    this._getContacts,
    this._enrollFace,
    this._recogniseFace,
    this._deleteContact,
    this._camera,
    this._tts,
    this._db,
  ) : super(const FaceInitial()) {
    on<LoadContacts>(_onLoad);
    on<EnrollContact>(_onEnroll);
    on<RecogniseFace>(_onRecognise);
    on<DeleteContact>(_onDelete);
  }

  Future<void> _onLoad(LoadContacts event, Emitter<FaceState> emit) async {
    final result = await _getContacts();
    result.fold(
      (failure) => emit(FaceError(failure.message)),
      (contacts) => emit(FaceReady(contacts: contacts)),
    );
  }

  Future<void> _onEnroll(EnrollContact event, Emitter<FaceState> emit) async {
    emit(const FaceLoading());
    await _tts.speak('Hold still, I\'m learning ${event.name}\'s face.', priority: TtsPriority.high);
    final photos = [await _camera.captureStill(), await _camera.captureStill(), await _camera.captureStill()];
    final result = await _enrollFace(event.name, photos);
    await result.fold(
      (failure) async {
        emit(FaceError(failure.message));
        await _tts.speak('Sorry, I couldn\'t enroll that face. Please try again.', priority: TtsPriority.high);
      },
      (contact) async {
        await _tts.speak('Got it! I\'ll remember ${contact.name} from now on.', priority: TtsPriority.high);
        await _db.insertUsageEvent(moduleId: ModuleIds.face, outcome: 'enrolled');
        add(const LoadContacts());
      },
    );
  }

  Future<void> _onRecognise(RecogniseFace event, Emitter<FaceState> emit) async {
    emit(const FaceLoading());
    await _tts.speak('Let me see who\'s there.', priority: TtsPriority.high);
    final image = await _camera.captureStill();
    final result = await _recogniseFace(image);
    final contactsResult = await _getContacts();
    final contacts = contactsResult.getOrElse(() => <EnrolledContact>[]);

    await result.fold(
      (failure) async {
        emit(FaceError(failure.message));
        await _tts.speak('Something went wrong. Please try again.', priority: TtsPriority.high);
        await _db.insertUsageEvent(moduleId: ModuleIds.face, outcome: 'error');
      },
      (face) async {
        if (!face.faceDetected) {
          emit(FaceReady(contacts: contacts, lastResult: face));
          await _db.insertUsageEvent(moduleId: ModuleIds.face, outcome: 'no_face');
          return;
        }
        if (face.matched && face.contactName != null) {
          await _tts.speak('That looks like ${face.contactName}!', priority: TtsPriority.high);
          await _db.insertUsageEvent(
            moduleId: ModuleIds.face,
            outcome: 'matched_${face.contactName}',
            confidenceScore: face.similarity,
          );
        } else {
          await _tts.speak('I don\'t recognize this person.', priority: TtsPriority.high);
          await _db.insertUsageEvent(moduleId: ModuleIds.face, outcome: 'unknown');
        }
        emit(FaceReady(contacts: contacts, lastResult: face));
      },
    );
  }

  Future<void> _onDelete(DeleteContact event, Emitter<FaceState> emit) async {
    final result = await _deleteContact(event.id);
    await result.fold(
      (failure) async {
        emit(FaceError(failure.message));
        await _tts.speak('I couldn\'t remove that contact. Please try again.', priority: TtsPriority.high);
      },
      (_) async {
        await _tts.speak('Done, contact removed.', priority: TtsPriority.high);
        add(const LoadContacts());
      },
    );
  }
}
