# NOVA (Navigational Object and Voice Assistant) - Full Project Context

NOVA is an advanced assistive application designed specifically for **Blind and Visually Impaired (BVI)** users. The ecosystem consists of a **Flutter mobile application** (engineered for extreme accessibility), a **Python FastAPI backend**, and an **ML pipeline** that trains and quantizes computer vision models for deployment on mobile devices.

---

## 1. Directory Structure

```
blindapp/
├── NOVA_DL_Model_Training_HuggingFace_v1.0.docx.pdf (HuggingFace training documentation)
├── NOVA_Mobile_Implementation_v1.0.docx.pdf         (Mobile implementation design specs)
├── NOVA_SRS_v1.0.docx.pdf                           (Software Requirements Specification)
│
├── nova_mobile/                                     (Flutter Mobile App Workspace)
│   ├── lib/
│   │   ├── core/                                    (Cross-cutting architectural services)
│   │   │   ├── camera/                              (Camera pre-warming and overlay service)
│   │   │   ├── constants/                           (API endpoints and feature keys)
│   │   │   ├── database/                            (JSON local DB simulation queue)
│   │   │   ├── haptics/                             (Haptic feedback utility wrappers)
│   │   │   ├── model_update/                        (OTA (Over-The-Air) model downloader)
│   │   │   ├── network/                             (Connectivity status and custom DioClient)
│   │   │   ├── settings/                            (SharedPreferences settings wrapper)
│   │   │   ├── sync/                                (Background sync coordinator)
│   │   │   ├── tts/                                 (Speech synthesiser with priorities)
│   │   │   └── voice/                               (Speech-to-text listener & fuzzy command parser)
│   │   │
│   │   ├── features/                                (Clean Architecture Feature Modules)
│   │   │   ├── currency_detection/                  (CFA Franc TFLite classifier)
│   │   │   ├── face_recognition/                    (Local embeddings enrollment & verification)
│   │   │   ├── home/                                (Screen-wide gesture-driven landing menu)
│   │   │   ├── obstacle_detection/                  (YOLO/SSD TFLite real-time warning module)
│   │   │   ├── ocr/                                 (On-device Google ML Kit text reader)
│   │   │   ├── onboarding/                          (Permissions requesting page)
│   │   │   ├── scene_description/                   (Image upload to HuggingFace BLIP API)
│   │   │   └── settings/                            (Speech speed/locale setting page)
│   │   │
│   │   ├── main.dart                                (App entrypoint & global voice command router)
│   │   └── injection_container.dart                 (GetIt Service Locators registration)
│   └── pubspec.yaml
│
└── nova_other_sections_backend_ml/                  (Backend & Machine Learning Section)
    ├── backend/                                     (FastAPI Server)
    │   ├── app/
    │   │   ├── api/                                 (API routers: auth, sync, face, scene)
    │   │   ├── core/                                (Config settings and security)
    │   │   ├── db/                                  (SQLAlchemy database session & schemas)
    │   │   └── services/                            (Business logic: HuggingFace & FaceNet matching)
    │   └── main.py
    └── ml_pipeline/                                 (Machine Learning Pipeline Scripts)
        ├── configs/                                 (Hyperparameters and model exports configs)
        └── scripts/                                 (Quantization and training pipelines)
```

---

## 2. Flutter Mobile Application (`nova_mobile`)

The mobile application utilizes **Clean Architecture** combined with **BLoC** (Business Logic Component) for state management and **GetIt** for dependency injection.

### A. Core Architecture & Infrastructure Services
1. **TTS Service (`core/tts/tts_service.dart`)**:
   - Encapsulates `flutter_tts`.
   - Utilizes a safety priority queue (`TtsPriority`: critical, high, normal, low) to ensure that high-importance navigational alerts (like obstacle proximity) immediately interrupt normal speech (like scene description).
2. **Voice Command Service (`core/voice/voice_command_service.dart`)**:
   - Runs speech-to-text globally.
   - Implements a **Jaccard similarity token-intersection algorithm**. Instead of strict equivalence, spoken user phrases (e.g., *"Show me options for currency"*) are tokenized, matched against keyword lists, and converted into deterministic `VoiceCommand` triggers if they pass a 25% similarity confidence threshold.
3. **App Database (`core/database/app_database.dart`)**:
   - An offline-first local queue. Keeps a copy of synced and unsynced events (usage, feedback, enrolled facial templates) using a robust file-based JSON queue, ready to transition to SQLite/Drift.
4. **Sync Service (`core/sync/sync_service.dart`)**:
   - Listens to connectivity changes. When the device returns online, it pushes pending local events and telemetry back to the FastAPI backend.
5. **Model Update Service (`core/model_update/model_update_service.dart`)**:
   - Connects to the backend server to check if more accurate `.tflite` model files or label indices are available (OTA update mechanism).
6. **Camera Service (`core/camera/camera_service.dart`)**:
   - Pre-warms the device's camera hardware in the background so that preview-dependent features load instantly with zero delay.

### B. User Interface & Feature Pages

#### 1. Home Menu Page (`features/home/presentation/pages/home_menu_page.dart`)
- **Visual Design**: Sleek, high-contrast, black-background layout with expansive color-coded panels that sighted companions or low-vision users can view.
- **Screen-Wide Gestures (For Blind Users)**:
  - **Double-Tap**: Double-tapping *anywhere* on the screen interrupts current audio and triggers voice command listening.
  - **Slide-to-Explore**: Dragging a single finger up or down triggers haptic ticks (`HapticFeedback.selectionClick()`) and speaks the item name immediately as boundary boxes are traversed.
  - **Lift-to-Select**: Releasing the screen while hovering over an option selects it.
- **System Screen Reader Compatibility**:
  - Embedded `SemanticsBinding.instance.ensureSemantics()` at boot.
  - Options are fully wrapped in `Semantics(button: true)` widgets so TalkBack/VoiceOver users can use standard system swipes and double-taps to navigate without breaking the custom gesture layer.

#### 2. Obstacle Detection Page (`features/obstacle_detection/`)
- Runs a local `.tflite` model on real-time camera frames.
- Implements an **Alert Suppression Policy** to prevent "alarm fatigue" (e.g., repeating "wall in front" 30 times a second). Alerts are throttled based on proximity and duration.

#### 3. Read Text Page (`features/ocr/`)
- Leverages Google ML Kit's on-device Text Recognition.
- Guides the user to center the page and reads the recognized text block using `TtsService`.

#### 4. Describe Scene Page (`features/scene_description/`)
- Captures a picture and uploads it to the backend.
- The backend queries a Hugging Face hosted model (BLIP/CLIP) to obtain a descriptive caption, which is read back to the user.

#### 5. Identify Money Page (`features/currency_detection/`)
- Uses a quantized MobileNetV2/EfficientNet TFLite model packaged within the assets to identify Central African CFA franc banknotes (`500`, `1000`, `2000`, `5000`, `10000`).

#### 6. Recognize Faces Page (`features/face_recognition/`)
- Matches bounding boxes of faces in the frame.
- Extracts features into a 128-dimensional facial embedding vector using a local FaceNet TFLite model.
- Allows BVI users to enroll friends by speaking their names, persisting their embeddings locally or syncing them with the server.

---

## 3. Python Backend Application (`nova_other_sections_backend_ml/backend`)

Built using **FastAPI** to support real-time data sync, model hosting, and API-heavy ML inferences.

- **API Modules**:
  - `auth`: Handles device registrations and API tokens.
  - `sync`: Syncs local database usage logs, user feedback, and metadata queue.
  - `faces`: Allows central storage, retrieval, and grouping of face embeddings.
  - `scene`: Receives captured camera frames and routes them directly to Hugging Face Inference endpoints (BLIP/CLIP models) to generate verbose image descriptions.
- **Database (`db/`)**:
  - Structured using SQLAlchemy models to persist user logs, device settings, and sync states.

---

## 4. Machine Learning & Quantization Pipeline (`nova_other_sections_backend_ml/ml_pipeline`)

Designed to train, optimize, and convert models from PyTorch/TensorFlow into optimized mobile-ready TFLite files.

- **Model Training**:
  - Contains scripts to train classification and detection architectures (e.g. YOLOv8 Nano for obstacles, MobileNet for CFA Franc currency).
- **Optimization & Quantization**:
  - Uses post-training **Full Integer Quantization** (`int8`) or float16 to shrink model sizes (down to 2MB - 5MB) and speed up execution, ensuring low-latency inference on low-end Android and iOS devices.
- **Label Exports**:
  - Generates structured `.txt` mapping labels that the mobile app dynamically loads during runtime.
