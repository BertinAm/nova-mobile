import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/tts/tts_service.dart';
import '../../domain/usecases/recognize_text_usecase.dart';

abstract class OcrEvent extends Equatable {
  const OcrEvent();
  @override
  List<Object?> get props => [];
}

class TriggerOcr extends OcrEvent {
  const TriggerOcr();
}

class CancelOcrReading extends OcrEvent {
  const CancelOcrReading();
}

abstract class OcrState extends Equatable {
  const OcrState();
  @override
  List<Object?> get props => [];
}

class OcrIdle extends OcrState {
  const OcrIdle();
}

class OcrCapturing extends OcrState {
  const OcrCapturing();
}

class OcrProcessing extends OcrState {
  const OcrProcessing();
}

class OcrReading extends OcrState {
  final String text;
  const OcrReading(this.text);
  @override
  List<Object?> get props => [text];
}

class OcrNoText extends OcrState {
  const OcrNoText();
}

class OcrError extends OcrState {
  final String message;
  const OcrError(this.message);
  @override
  List<Object?> get props => [message];
}

class OcrBloc extends Bloc<OcrEvent, OcrState> {
  final RecognizeTextUseCase _recognizeText;
  final CameraService _camera;
  final TtsService _tts;
  final AppDatabase _db;

  OcrBloc(this._recognizeText, this._camera, this._tts, this._db)
      : super(const OcrIdle()) {
    on<TriggerOcr>(_onTrigger);
    on<CancelOcrReading>(_onCancel);
  }

  Future<void> _onTrigger(TriggerOcr event, Emitter<OcrState> emit) async {
    emit(const OcrCapturing());
    await _tts.speak('Hold steady, reading text.', priority: TtsPriority.high);

    final image = await _camera.captureStill();
    emit(const OcrProcessing());

    final result = await _recognizeText(image);
    await result.fold(
      (failure) async {
        emit(OcrError(failure.message));
        await _tts.speak(
          'I couldn\'t read the text. Please try again.',
          priority: TtsPriority.high,
        );
        await _db.insertUsageEvent(moduleId: ModuleIds.ocr, outcome: 'error');
      },
      (ocrResult) async {
        if (!ocrResult.success || ocrResult.text.trim().isEmpty) {
          emit(const OcrNoText());
          await _tts.speak(
            'I can\'t see any text. Try moving the camera closer to what you want me to read.',
            priority: TtsPriority.high,
          );
          await _db.insertUsageEvent(moduleId: ModuleIds.ocr, outcome: 'no_text');
          return;
        }

        emit(OcrReading(ocrResult.text));
        await _tts.setLanguage(ocrResult.language);
        await _tts.speak(ocrResult.text, priority: TtsPriority.normal);
        await _db.insertUsageEvent(
          moduleId: ModuleIds.ocr,
          outcome: 'read_${ocrResult.text.length}_chars_${ocrResult.language}',
        );
      },
    );
  }

  Future<void> _onCancel(CancelOcrReading event, Emitter<OcrState> emit) async {
    await _tts.stop();
    emit(const OcrIdle());
  }
}
