# NOVA Mobile Application: Comprehensive Build Report

This report summarizes the entire architecture, feature set, and design decisions implemented in the final build of the NOVA assistive application.

## 1. Architectural Foundation
The application is built using **Flutter** and strictly adheres to **Clean Architecture** principles to separate concerns and ensure maintainability.

* **Presentation Layer:** Managed by `flutter_bloc` for predictable state management. UIs are strictly reactive to BLoC states (e.g., `CurrencyDetecting`, `ObstacleError`).
* **Domain Layer:** Contains pure Dart entities (`DetectedObstacle`, `EnrolledContact`) and abstract Repositories.
* **Data Layer:** Implements repositories and communicates with local DataSources (TFLite, ML Kit, SQLite via Drift) and Remote DataSources (Dio for backend syncing).
* **Dependency Injection:** Uses `get_it` to provide singletons for core services (TTS, Camera, VoiceRouter) and lazy singletons for DataSources.

## 2. Core Modules & AI Implementations

### MOD-01: Obstacle Detection
* **Technology:** TFLite custom object detection model.
* **Implementation:** Processes frames asynchronously. Calculates estimated distance based on bounding box size relative to the screen. 
* **Accessibility:** Sorts obstacles into `near`, `warning`, and `clear` zones. Uses debounce logic to prevent overwhelming the user with TTS spam. UI features an animated, color-coded Sonar radar instead of a visual camera feed.

### MOD-02: Text Reading (OCR)
* **Technology:** Google ML Kit Text Recognition.
* **Implementation:** Offline, instantaneous extraction of text from still captures. Wraps the results in a readable format and passes them to the TTS engine.

### MOD-03: Scene Description
* **Technology:** Backend Integration via Dio.
* **Implementation:** The only module that relies on the cloud. Captures an image, compresses it, and sends it to the NOVA backend. The returned rich-text description is spoken to the user.

### MOD-04: Currency Detection
* **Technology:** TFLite custom image classification model.
* **Implementation:** Fast classification of CFA and other supported notes. If confidence is low, it triggers the data collection pipeline to upload the "hard case" for future retraining.

### MOD-05: Face Recognition
* **Technology:** Google ML Kit Face Detection + MobileFaceNet (TFLite).
* **Implementation:** 100% Offline. Uses ML Kit to find the face bounding box, crops it, and extracts a 128-dimensional embedding via MobileFaceNet. Compares the embedding against a local SQLite database of enrolled contacts using Cosine Similarity.

## 3. Universal Accessibility (BVI-First Design)

* **Continuous Voice Command Routing:** A global `VoiceCommandService` listens continuously for trigger words. A user can say "Option One" from any screen, and the global `navigatorKey` will instantly route them to the Obstacle Detection module.
* **Semantics & Haptics:** Every button and toggle is wrapped in `Semantics` widgets to provide precise TalkBack/VoiceOver descriptions. Every interaction triggers a micro-haptic vibration to confirm physical contact.
* **Gestures Over Taps:** The UI features massive, high-contrast hit zones. Critical destructive actions (like deleting a face) require confirmation, and the secret GPS feature utilizes a global triple-tap gesture.

## 4. Privacy & Data Collection
* **Local-First Philosophy:** All modules (except Scene Description) run entirely on the mobile device's CPU/NPU. Data does not leave the device.
* **Consent-Driven Retraining:** A specific settings toggle allows users to opt-in to uploading "hard cases" (low confidence images) to help retrain models.
* **Mandatory On-Device Blurring:** Before an opted-in hard case is uploaded, the `DataCollectionService` scans the image for faces using ML Kit and permanently applies a heavy Gaussian blur to the face pixels. If detection fails, the entire image is blurred.

## 5. UX & Aesthetics
* **Dynamic Splash Boot Sequence:** A premium animated splash screen runs while background services (TTS, Camera warmup, TFLite model loading) execute asynchronously. 
* **Dark-Mode High Contrast:** The app strictly utilizes the `NovaDesignSystem` with deep blacks, vibrant primary colors, and stark white text to maximize visibility for users with partial sight.

## Conclusion
The NOVA Mobile Application is a robust, production-ready assistive tool. By offloading heavy processing to local TFLite/ML Kit engines and prioritizing non-visual feedback mechanisms (TTS, Haptics), the app delivers a seamless, private, and highly responsive experience for Blind and Visually Impaired users.
