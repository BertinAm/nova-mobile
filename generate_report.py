"""
NOVA Mobile App — Full Technical Report Generator
Run: pip install python-docx && python generate_report.py
Output: NOVA_Mobile_Report.docx (saved to current directory)
"""

from docx import Document
from docx.shared import Pt, RGBColor, Inches, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import datetime

# ─── Colour palette ──────────────────────────────────────────────────────────
NOVA_BLUE   = RGBColor(0x4A, 0x9E, 0xFF)
NOVA_DARK   = RGBColor(0x0D, 0x11, 0x1A)
NOVA_MID    = RGBColor(0x1A, 0x1F, 0x2E)
WHITE       = RGBColor(0xFF, 0xFF, 0xFF)
GREY_TEXT   = RGBColor(0x55, 0x60, 0x70)
GREEN       = RGBColor(0x2E, 0xCC, 0x71)
AMBER       = RGBColor(0xF3, 0x9C, 0x12)
RED         = RGBColor(0xE7, 0x4C, 0x3C)

# ─── Helpers ──────────────────────────────────────────────────────────────────
def shade_cell(cell, hex_color: str):
    """Fill table cell background."""
    tc = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hex_color)
    tcPr.append(shd)

def set_cell_border(cell, **kwargs):
    tc = cell._tc
    tcPr = tc.get_or_add_tcPr()
    tcBorders = OxmlElement("w:tcBorders")
    for edge in ("top", "left", "bottom", "right"):
        el = OxmlElement(f"w:{edge}")
        el.set(qn("w:val"), "single")
        el.set(qn("w:sz"), "4")
        el.set(qn("w:color"), "4A9EFF")
        tcBorders.append(el)
    tcPr.append(tcBorders)

def add_heading(doc, text, level=1, color=None):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(18 if level == 1 else 10)
    p.paragraph_format.space_after  = Pt(4)
    run = p.add_run(text)
    run.bold = True
    run.font.size = Pt({1: 20, 2: 15, 3: 13}.get(level, 12))
    run.font.color.rgb = color or (NOVA_BLUE if level == 1 else NOVA_DARK)
    return p

def add_body(doc, text, italic=False, color=None):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(4)
    run = p.add_run(text)
    run.font.size = Pt(11)
    run.italic = italic
    if color:
        run.font.color.rgb = color
    return p

def add_bullet(doc, text, indent=0):
    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.left_indent = Inches(0.25 * (indent + 1))
    p.paragraph_format.space_after = Pt(2)
    run = p.add_run(text)
    run.font.size = Pt(10.5)
    return p

def add_table(doc, headers, rows, col_widths=None):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    # Header row
    hdr_cells = table.rows[0].cells
    for i, h in enumerate(headers):
        shade_cell(hdr_cells[i], "0D111A")
        p = hdr_cells[i].paragraphs[0]
        run = p.add_run(h)
        run.bold = True
        run.font.size = Pt(10)
        run.font.color.rgb = WHITE
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    # Data rows
    for r_idx, row in enumerate(rows):
        row_cells = table.add_row().cells
        bg = "F0F4FA" if r_idx % 2 == 0 else "FFFFFF"
        for i, val in enumerate(row):
            shade_cell(row_cells[i], bg)
            p = row_cells[i].paragraphs[0]
            run = p.add_run(str(val))
            run.font.size = Pt(10)
    # Column widths
    if col_widths:
        for i, width in enumerate(col_widths):
            for cell in table.columns[i].cells:
                cell.width = Inches(width)
    doc.add_paragraph()  # spacing after table
    return table

def add_divider(doc):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after  = Pt(4)
    border = OxmlElement("w:pBdr")
    bottom = OxmlElement("w:bottom")
    bottom.set(qn("w:val"),   "single")
    bottom.set(qn("w:sz"),    "4")
    bottom.set(qn("w:color"), "4A9EFF")
    border.append(bottom)
    p._p.get_or_add_pPr().append(border)

# ─── Build Document ───────────────────────────────────────────────────────────
doc = Document()

# Page margins
for section in doc.sections:
    section.top_margin    = Cm(2.0)
    section.bottom_margin = Cm(2.0)
    section.left_margin   = Cm(2.5)
    section.right_margin  = Cm(2.5)

# ── Cover ────────────────────────────────────────────────────────────────────
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("NOVA")
r.bold = True
r.font.size = Pt(40)
r.font.color.rgb = NOVA_BLUE

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("Navigational Object & Voice Assistant")
r.font.size = Pt(15)
r.font.color.rgb = GREY_TEXT

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("Mobile Application — Technical Report")
r.bold = True
r.font.size = Pt(14)
r.font.color.rgb = NOVA_DARK

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run(f"Generated: {datetime.datetime.now().strftime('%d %B %Y')}")
r.font.size = Pt(10)
r.font.color.rgb = GREY_TEXT

doc.add_page_break()

# ── 1. Executive Summary ─────────────────────────────────────────────────────
add_heading(doc, "1. Executive Summary")
add_body(doc,
    "NOVA is an offline-first, BVI-accessible (Blind & Visually Impaired) Flutter mobile "
    "application that delivers five AI-powered assistive modules entirely on-device. The app "
    "communicates with users exclusively through Text-to-Speech (TTS) and haptic vibrations, "
    "removing all dependency on visual feedback for core navigation tasks."
)
add_divider(doc)

# ── 2. Architecture ───────────────────────────────────────────────────────────
add_heading(doc, "2. Architecture")

add_heading(doc, "2.1  Pattern — Clean Architecture", level=2)
add_body(doc, "The app strictly separates concerns into three layers:")
for item in [
    "Presentation  ›  flutter_bloc (BLoC pattern). All UI is reactive to BLoC state emissions. No business logic lives in widgets.",
    "Domain  ›  Pure Dart entities, abstract repositories, and use-cases. Zero Flutter/platform dependencies.",
    "Data  ›  Repository implementations, TFLite datasources, ML Kit datasources, SQLite (Drift), and Dio for remote calls.",
]:
    add_bullet(doc, item)

add_heading(doc, "2.2  Dependency Injection", level=2)
for item in [
    "Uses get_it as the service locator. All core services are registered as singletons at app boot.",
    "Race conditions guarded: widgets that depend on async-registered services poll getIt.isRegistered() before accessing the container.",
    "SettingsService is the first singleton registered; all other services that read settings wait for it.",
]:
    add_bullet(doc, item)

add_heading(doc, "2.3  Global Camera Overlay", level=2)
add_body(doc,
    "A single floating camera overlay widget is mounted at the MaterialApp builder level. "
    "This keeps the camera 'hot' across all routes, eliminating the 1–2 s re-initialisation "
    "lag that would otherwise occur on every page navigation. The overlay is only visible when "
    "a developer debug toggle is enabled; it is hidden by default."
)
add_divider(doc)

# ── 3. AI Modules ─────────────────────────────────────────────────────────────
add_heading(doc, "3. AI Modules")

modules = [
    ("MOD-01", "Obstacle Detection",
     "TFLite custom object detection model",
     "Processes camera frames asynchronously. Classifies obstacles into near / warning / clear zones "
     "based on bounding-box size relative to screen. Debounce timer prevents TTS spam (max one "
     "announcement per 4 s). UI shows an animated colour-coded Sonar radar instead of a camera preview.",
     "Offline"),
    ("MOD-02", "Text Reading (OCR)",
     "Google ML Kit Text Recognition",
     "Still-capture → offline ML Kit pipeline → spoken result via TTS. Handles multi-line text "
     "and formats output into natural sentences before speaking.",
     "Offline"),
    ("MOD-03", "Scene Description",
     "NOVA Cloud Backend (Dio)",
     "Compresses a still capture and POSTs it to the scene-description endpoint. The returned "
     "natural-language description is spoken to the user. Only module requiring network.",
     "Online"),
    ("MOD-04", "Currency Detection",
     "TFLite image classification",
     "Fast note classification. Low-confidence results (< 0.5) trigger the data-collection "
     "consent flow to upload the frame as a hard case for retraining.",
     "Offline"),
    ("MOD-05", "Face Recognition",
     "BlazeFace TFLite + MobileFaceNet TFLite",
     "100% on-device pipeline: BlazeFace detects the face bounding box → crop + 20% padding → "
     "MobileFaceNet extracts a 128-d embedding → cosine similarity against a local SQLite gallery. "
     "SHA-256 deterministic fallback used in simulated/test environments.",
     "Offline"),
]

add_table(doc,
    headers=["ID", "Module", "Technology", "Description", "Network"],
    rows=[(m[0], m[1], m[2], m[3], m[4]) for m in modules],
    col_widths=[0.65, 1.3, 1.5, 3.2, 0.75],
)
add_divider(doc)

# ── 4. Interaction & UX Design ───────────────────────────────────────────────
add_heading(doc, "4. Interaction & UX Design")

add_heading(doc, "4.1  Voice Command Navigation", level=2)
for item in [
    "A VoiceCommandService listens continuously in the background. Users speak 'Option One' through 'Option Six' from any screen to navigate directly to a module.",
    "Commands are routed through a global VoiceCommandRouter stream; the root NovaApp widget subscribes and calls Navigator.pushNamedAndRemoveUntil so there is always a clean back-stack.",
    "After navigation the listener re-arms automatically with a 800 ms delay to avoid capturing the TTS confirmation as a command.",
]:
    add_bullet(doc, item)

add_heading(doc, "4.2  Haptic Feedback", level=2)
for item in [
    "Every confirmed interaction (button press, gesture recognition, module start) triggers a short haptic vibration via HapticService (vibration package).",
    "Critical alerts (obstacle in near zone) use a long double-vibration pattern to distinguish them from informational feedback.",
]:
    add_bullet(doc, item)

add_heading(doc, "4.3  Text-To-Speech (TTS) Priority System", level=2)
for item in [
    "TtsService wraps flutter_tts and exposes three priority levels: high (interrupts current speech), normal (queued), low (skipped if another is pending).",
    "Obstacle and face results are always high priority. Background log messages use low priority so they never interrupt the user.",
    "Speech rate and language (en-CM / fr-CM) are user-configurable and persisted to SharedPreferences.",
]:
    add_bullet(doc, item)

add_heading(doc, "4.4  Gesture Design — BVI-Optimised", level=2)
for item in [
    "Large hit zones: the entire screen half is a GestureDetector, not a small button.",
    "Swipes (left / right / up / down) are the primary navigation mechanism within a module; taps confirm or repeat.",
    "Destructive actions (delete enrolled face) require a long-press + voice confirmation, not a single tap.",
    "Secret GPS Feature: a 60×60 px invisible hit zone in the bottom-right corner. Triple-tapping it pauses active TTS and speaks the user's current reverse-geocoded street address (geolocator + geocoding).",
    "Screen wake-lock: wakelock_plus prevents the display from sleeping during an active detection session.",
]:
    add_bullet(doc, item)

add_heading(doc, "4.5  Accessibility (Semantics)", level=2)
for item in [
    "Every interactive widget is wrapped in a Semantics widget with a label, value, and hint string so TalkBack/VoiceOver reads meaningful descriptions.",
    "Decorative elements (background gradients, logo animations) use ExcludeSemantics to hide them from screen readers.",
    "All toggles expose their current state (enabled/disabled) through the Semantics toggled property.",
]:
    add_bullet(doc, item)
add_divider(doc)

# ── 5. Splash & Boot Sequence ─────────────────────────────────────────────────
add_heading(doc, "5. Splash Screen & Boot Sequence")
for item in [
    "SplashPage is shown immediately on launch (zero visible delay).",
    "Background initialisation runs asynchronously: TFLite model loading, TTS engine warmup, camera permission check, SharedPreferences hydration.",
    "A non-blocking initFuture is awaited inside SplashPage. Once resolved, the app routes to AuthWrapper automatically.",
    "If any non-critical service fails (e.g., a TFLite model file is missing), the app degrades gracefully and announces the issue via TTS.",
]:
    add_bullet(doc, item)
add_divider(doc)

# ── 6. Privacy & Data Collection ─────────────────────────────────────────────
add_heading(doc, "6. Privacy & Data Collection")

add_heading(doc, "6.1  Consent Model", level=2)
for item in [
    "Data collection is OFF by default. The settings toggle ('Share uncertain detections to help improve NOVA') must be explicitly enabled.",
    "Flipping the toggle sends a PUT /training-data/consent request to the backend to sync state.",
    "A per-instance voice prompt ('NOVA wasn't sure what this was; share it to help improve?') is spoken every time a qualifying frame is about to be uploaded. The user must say 'confirm'; any other response cancels the upload.",
]:
    add_bullet(doc, item)

add_heading(doc, "6.2  On-Device Face Blurring (Non-Negotiable)", level=2)
for item in [
    "Before any frame is uploaded, DataCollectionService runs the BlazeFace TFLite model on the image.",
    "Every face bounding box is individually cropped, Gaussian-blurred (radius 25), and painted back in-place.",
    "If BlazeFace inference fails for any reason, the entire image is blurred before upload — no partial-blur leaks.",
    "The processed frame is then JPEG-compressed with quality scaling to stay under the 5 MB API limit.",
]:
    add_bullet(doc, item)

add_heading(doc, "6.3  Backend API Compliance", level=2)
add_table(doc,
    headers=["Endpoint", "Method", "Behaviour"],
    rows=[
        ("PUT /training-data/consent", "PUT", "Called once when toggle is flipped. Body: {consent: true/false}."),
        ("GET /training-data/consent", "GET", "Read current consent state from server. Called at auth time to sync."),
        ("POST /training-data/upload", "POST", "Multipart upload: module_id, outcome, confidence_score, file. Returns 201."),
        ("403 response", "—", "Consent not set server-side. Upload silently aborted. No retry loop."),
        ("413 response", "—", "File too large. Logged and dropped. Quality scaling prevents this in practice."),
    ],
    col_widths=[2.2, 0.8, 3.8],
)
add_divider(doc)

# ── 7. Key Technical Decisions ───────────────────────────────────────────────
add_heading(doc, "7. Key Technical Decisions")
decisions = [
    ("BlazeFace TFLite over ML Kit", "Use raw BlazeFace TFLite model + BlazeFaceHelper anchor decoder rather than google_mlkit_face_detection.", "Stays consistent with original SRS specification. Avoids an additional native SDK dependency. BlazeFaceHelper correctly applies sigmoid() to output logits before confidence thresholding, fixing a bug in the earlier implementation."),
    ("Sonar UI for Obstacle Detection", "Replace camera preview + bounding boxes with an animated Sonar radar.", "A live camera preview gives zero utility to a BVI user. Saves CPU for TFLite inference. Sonar colour-codes by zone (Green / Amber / Red) for users with partial sight."),
    ("SHA-256 Embedding Fallback", "When TFLite models are unavailable (simulator / missing assets), generate a deterministic SHA-256 embedding from the file path.", "Allows enrolment and recognition to be demoed end-to-end on any device, including emulators without camera hardware."),
    ("Global Camera Overlay", "Mount a single camera stream at the MaterialApp level, not per-page.", "Eliminates 1–2 s re-initialisation lag on every route change. Critical for a realtime assistive tool."),
    ("Secret GPS Triple-Tap", "60×60 px invisible hit zone (bottom-right) triggers reverse-geocoding on triple-tap.", "High-value demo feature. Gives the user their exact address without any explicit UI element taking up screen real-estate."),
]
add_table(doc,
    headers=["Decision", "What", "Why"],
    rows=decisions,
    col_widths=[1.6, 2.2, 2.9],
)
add_divider(doc)

# ── 8. Dependencies ───────────────────────────────────────────────────────────
add_heading(doc, "8. Key Dependencies")
deps = [
    ("flutter_bloc / bloc", "State management"),
    ("get_it / injectable", "Dependency injection"),
    ("tflite_flutter", "On-device ML inference (BlazeFace, MobileFaceNet, obstacle, currency)"),
    ("google_mlkit_text_recognition", "OCR (MOD-02)"),
    ("camera", "Real-time camera frame streaming"),
    ("drift + sqlite3_flutter_libs", "Local relational database (enrolled contacts, usage events)"),
    ("flutter_tts", "Text-to-Speech engine"),
    ("speech_to_text", "Voice command input"),
    ("geolocator + geocoding", "GPS coordinates + reverse-geocoding for secret location feature"),
    ("dio", "HTTP client for backend API calls (scene description, data collection, auth)"),
    ("vibration", "Haptic feedback"),
    ("shared_preferences", "User settings persistence"),
    ("flutter_secure_storage", "JWT token storage"),
    ("crypto", "SHA-256 fallback embedding"),
    ("connectivity_plus", "Network availability checks"),
]
add_table(doc,
    headers=["Package", "Purpose"],
    rows=deps,
    col_widths=[2.4, 4.3],
)
add_divider(doc)

# ── 9. Build Status ───────────────────────────────────────────────────────────
add_heading(doc, "9. Demo-Day Build Status")
status = [
    ("Splash Screen + async boot", "✅ Done"),
    ("MOD-01 Obstacle Detection (Sonar UI)", "✅ Done"),
    ("MOD-02 OCR / Text Reading", "✅ Done"),
    ("MOD-03 Scene Description (cloud)", "✅ Done"),
    ("MOD-04 Currency Detection", "✅ Done"),
    ("MOD-05 Face Recognition (BlazeFace + MobileFaceNet)", "✅ Done"),
    ("Global Voice Command Navigation", "✅ Done"),
    ("Secret GPS Triple-Tap Feature", "✅ Done"),
    ("Privacy-first data collection (on-device blur)", "✅ Done"),
    ("Settings: consent toggle, speech rate, language", "✅ Done"),
    ("Emergency Contact management", "✅ Done"),
    ("Auth (JWT login/register)", "✅ Done"),
    ("ObstacleZone enum alignment (near/warning/clear)", "✅ Fixed"),
    ("GetIt race condition (SettingsService overlay)", "✅ Fixed"),
    ("google_mlkit_face_detection removed", "✅ Removed"),
    ("BlazeFace anchor sigmoid decoding", "✅ Fixed"),
],
add_table(doc,
    headers=["Feature / Fix", "Status"],
    rows=[r for r in status[0]],
    col_widths=[4.5, 1.5],
)

# ── Footer ───────────────────────────────────────────────────────────────────
doc.add_page_break()
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("NOVA Mobile Application — Technical Report")
r.font.size = Pt(9)
r.font.color.rgb = GREY_TEXT
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("Confidential  ·  For presentation purposes only")
r.font.size = Pt(9)
r.italic = True
r.font.color.rgb = GREY_TEXT

# ─── Save ─────────────────────────────────────────────────────────────────────
out_path = "NOVA_Mobile_Report.docx"
doc.save(out_path)
print(f"✅  Report saved → {out_path}")
