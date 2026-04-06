from docx import Document
from docx.shared import Pt, RGBColor, Inches, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_ALIGN_VERTICAL
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import copy

# ── Brand colours ─────────────────────────────────────────────────────────────
EMERALD   = RGBColor(0x0E, 0x3A, 0x29)   # Deep Emerald  #0E3A29
FOREST    = RGBColor(0x0A, 0x1F, 0x1C)   # Deep Forest   #0A1F1C
GOLD      = RGBColor(0xB7, 0xA4, 0x6B)   # Antique Gold  #B7A46B
SAGE      = RGBColor(0x73, 0x97, 0x8C)   # Muted Sage    #73978C
STONE     = RGBColor(0xD4, 0xD1, 0xC7)   # Warm Stone    #D4D1C7
WHITE     = RGBColor(0xFF, 0xFF, 0xFF)
LIGHTGREY = RGBColor(0xF5, 0xF5, 0xF3)
MIDGREY   = RGBColor(0xE8, 0xE6, 0xE0)

doc = Document()

# ── Page margins ──────────────────────────────────────────────────────────────
for section in doc.sections:
    section.top_margin    = Cm(1.8)
    section.bottom_margin = Cm(1.8)
    section.left_margin   = Cm(2.2)
    section.right_margin  = Cm(2.2)

# ── Helper: set paragraph background colour ───────────────────────────────────
def shade_paragraph(para, rgb: RGBColor):
    pPr = para._p.get_or_add_pPr()
    shd = OxmlElement('w:shd')
    hex_colour = '{:02X}{:02X}{:02X}'.format(rgb[0], rgb[1], rgb[2])
    shd.set(qn('w:val'),   'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'),  hex_colour)
    pPr.append(shd)

def shade_cell(cell, rgb: RGBColor):
    hex_colour = '{:02X}{:02X}{:02X}'.format(rgb[0], rgb[1], rgb[2])
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd  = OxmlElement('w:shd')
    shd.set(qn('w:val'),   'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'),  hex_colour)
    tcPr.append(shd)

def set_cell_border(cell, **kwargs):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    tcBorders = OxmlElement('w:tcBorders')
    for edge in ('top','left','bottom','right','insideH','insideV'):
        tag = OxmlElement(f'w:{edge}')
        tag.set(qn('w:val'),   'single')
        tag.set(qn('w:sz'),    '4')
        tag.set(qn('w:space'), '0')
        tag.set(qn('w:color'), 'FFFFFF')
        tcBorders.append(tag)
    tcPr.append(tcBorders)

# ── Helper: add a styled heading ──────────────────────────────────────────────
def add_section_heading(doc, text, level=1):
    para = doc.add_paragraph()
    shade_paragraph(para, EMERALD)
    para.paragraph_format.space_before = Pt(0)
    para.paragraph_format.space_after  = Pt(0)
    para.paragraph_format.left_indent  = Cm(0.3)
    run = para.add_run(text.upper())
    run.bold      = True
    run.font.size = Pt(10) if level == 1 else Pt(9)
    run.font.color.rgb = GOLD
    return para

def add_subheading(doc, text):
    para = doc.add_paragraph()
    para.paragraph_format.space_before = Pt(10)
    para.paragraph_format.space_after  = Pt(3)
    run = para.add_run(text)
    run.bold = True
    run.font.size = Pt(11)
    run.font.color.rgb = EMERALD
    return para

def add_body(doc, text, indent=False):
    para = doc.add_paragraph()
    para.paragraph_format.space_before = Pt(2)
    para.paragraph_format.space_after  = Pt(2)
    if indent:
        para.paragraph_format.left_indent = Cm(0.5)
    run = para.add_run(text)
    run.font.size = Pt(10)
    run.font.color.rgb = FOREST
    return para

def add_bullet(doc, text, bold_prefix=None):
    para = doc.add_paragraph(style='List Bullet')
    para.paragraph_format.space_before = Pt(1)
    para.paragraph_format.space_after  = Pt(1)
    para.paragraph_format.left_indent  = Cm(0.6)
    if bold_prefix:
        r1 = para.add_run(bold_prefix + '  ')
        r1.bold = True
        r1.font.size = Pt(10)
        r1.font.color.rgb = EMERALD
        r2 = para.add_run(text)
        r2.font.size = Pt(10)
        r2.font.color.rgb = FOREST
    else:
        run = para.add_run(text)
        run.font.size = Pt(10)
        run.font.color.rgb = FOREST
    return para

def add_spacer(doc, pts=6):
    para = doc.add_paragraph()
    para.paragraph_format.space_before = Pt(0)
    para.paragraph_format.space_after  = Pt(0)
    run = para.add_run('')
    run.font.size = Pt(pts)

def add_key_value_table(doc, rows, header=None):
    """Two-column key/value table."""
    table = doc.add_table(rows=len(rows) + (1 if header else 0), cols=2)
    table.style = 'Table Grid'
    col_idx = 0
    if header:
        hrow = table.rows[0]
        for i, h in enumerate(header):
            cell = hrow.cells[i]
            shade_cell(cell, EMERALD)
            set_cell_border(cell)
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            para = cell.paragraphs[0]
            para.paragraph_format.left_indent = Cm(0.2)
            run = para.add_run(h)
            run.bold = True
            run.font.size = Pt(9)
            run.font.color.rgb = GOLD
        col_idx = 1
    for ri, (key, val) in enumerate(rows):
        row = table.rows[ri + col_idx]
        bg = LIGHTGREY if ri % 2 == 0 else WHITE
        # Key cell
        kc = row.cells[0]
        shade_cell(kc, EMERALD if ri == -1 else MIDGREY)
        shade_cell(kc, RGBColor(0xE2, 0xEA, 0xE7))
        set_cell_border(kc)
        kc.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        kp = kc.paragraphs[0]
        kp.paragraph_format.left_indent = Cm(0.2)
        kr = kp.add_run(key)
        kr.bold = True
        kr.font.size = Pt(9)
        kr.font.color.rgb = EMERALD
        # Value cell
        vc = row.cells[1]
        shade_cell(vc, bg)
        set_cell_border(vc)
        vc.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        vp = vc.paragraphs[0]
        vp.paragraph_format.left_indent = Cm(0.2)
        vr = vp.add_run(val)
        vr.font.size = Pt(9)
        vr.font.color.rgb = FOREST
    table.columns[0].width = Cm(5)
    table.columns[1].width = Cm(11.5)
    return table

# ══════════════════════════════════════════════════════════════════════════════
# COVER BLOCK
# ══════════════════════════════════════════════════════════════════════════════

# Big title banner
title_para = doc.add_paragraph()
shade_paragraph(title_para, FOREST)
title_para.paragraph_format.space_before = Pt(0)
title_para.paragraph_format.space_after  = Pt(0)
title_para.paragraph_format.left_indent  = Cm(0.4)
t1 = title_para.add_run('RESOLARA')
t1.bold = True
t1.font.size = Pt(32)
t1.font.color.rgb = GOLD

subtitle_para = doc.add_paragraph()
shade_paragraph(subtitle_para, FOREST)
subtitle_para.paragraph_format.space_before = Pt(0)
subtitle_para.paragraph_format.space_after  = Pt(0)
subtitle_para.paragraph_format.left_indent  = Cm(0.4)
s1 = subtitle_para.add_run('Clinical Visualization Platform  ·  Build Summary')
s1.font.size = Pt(12)
s1.font.color.rgb = SAGE

tagline_para = doc.add_paragraph()
shade_paragraph(tagline_para, FOREST)
tagline_para.paragraph_format.space_before = Pt(0)
tagline_para.paragraph_format.space_after  = Pt(0)
tagline_para.paragraph_format.left_indent  = Cm(0.4)
t2 = tagline_para.add_run('Version 1.3.2  ·  Build 45  ·  March 2026  ·  iOS + Android')
t2.font.size = Pt(9)
t2.font.color.rgb = RGBColor(0x8A, 0xA8, 0x9E)

add_spacer(doc, 10)

# ══════════════════════════════════════════════════════════════════════════════
# 1. PRODUCT OVERVIEW
# ══════════════════════════════════════════════════════════════════════════════
add_section_heading(doc, '1.  Product Overview')
add_spacer(doc, 4)
add_body(doc,
    'Resolara is a mobile-first clinical visualization platform for licensed healthcare professionals. '
    'It captures a medical report on a smartphone, extracts clinically relevant findings using AI, '
    'and generates a practitioner-reviewed 2D anatomical illustration — all with a privacy-first '
    'architecture that keeps original patient documents on-device at all times.')
add_spacer(doc, 4)
add_body(doc,
    'Resolara is an educational communication tool. It is not diagnostic software and does not '
    'produce diagnoses, treatment recommendations, or exact pathology reconstructions. All clinical '
    'judgement remains with the healthcare professional.')

add_spacer(doc, 6)
add_key_value_table(doc, [
    ('Product name',        'Resolara'),
    ('Bundle ID',           'ai.resolara.app'),
    ('Current version',     '1.3.2 (Build 45)'),
    ('Platforms',           'iOS 16.0+  ·  Android (API 21+)'),
    ('Target audience',     'Licensed healthcare professionals'),
    ('Purpose',             'Educational anatomical visualization from clinical reports'),
    ('Deployment model',    'Cloud-hosted API (Mode A) — no desktop dependency required'),
    ('Privacy model',       'Original images and PDFs never leave the device'),
], header=['Property', 'Value'])

add_spacer(doc, 10)

# ══════════════════════════════════════════════════════════════════════════════
# 2. TECHNOLOGY STACK
# ══════════════════════════════════════════════════════════════════════════════
add_section_heading(doc, '2.  Technology Stack')
add_spacer(doc, 4)

add_subheading(doc, 'Mobile App')
add_key_value_table(doc, [
    ('Framework',           'Flutter 3.x  ·  Dart 3.10.8+'),
    ('State management',    'Riverpod 2.6 + riverpod_generator (code-gen providers)'),
    ('Routing',             'go_router 14.8 — shell routes for practitioner and patient shells'),
    ('HTTP client',         'Dio 5.8 — authenticated and unauthenticated instances'),
    ('Local database',      'Drift 2.23 (SQLite ORM) — encrypted session storage'),
    ('Secure storage',      'flutter_secure_storage 9.2 — bearer tokens, role, install marker'),
    ('On-device OCR',       'google_mlkit_text_recognition 0.15 — ML Kit, runs fully on-device'),
    ('PDF rendering',       'pdfx 2.8 — renders PDF pages to images on-device before OCR'),
    ('Image processing',    'image 4.5 — EXIF/metadata stripping, image stamping'),
    ('File encryption',     'encrypt 5.0 + pointycastle 3.9 — AES-256 for saved visualizations'),
    ('QR code display',     'qr_flutter 4.1'),
    ('QR code scanning',    'mobile_scanner 7.0 — barcode scanning with race-condition guard'),
    ('Voice input',         'speech_to_text 7.0 — on-device transcription'),
    ('Analytics',           'Firebase Analytics 11 + Firebase Crashlytics 4'),
    ('Camera / import',     'image_picker 1.1 + file_picker 8.3'),
    ('Sharing',             'share_plus 10.1 — native share sheet for image export'),
    ('SVG assets',          'flutter_svg 2.0'),
])

add_spacer(doc, 6)
add_subheading(doc, 'Backend / Server')
add_key_value_table(doc, [
    ('Language',            'PHP 8.2'),
    ('Runtime',             'LiteSpeed / CloudLinux (DirectAdmin managed hosting)'),
    ('Database',            'MySQL — DAUSER_resolara'),
    ('AI — Extraction',     'Claude (claude-sonnet-4-6) via Anthropic API'),
    ('AI — Image gen',      'gpt-image-1 via OpenAI API'),
    ('AI — Explanations',   'Claude — per-finding plain-language explanations'),
    ('AI — Exercises',      'Claude — recovery exercise plans (cached per session)'),
    ('AI — Medications',    'Claude — medication suggestions (cached per session)'),
    ('Auth',                'Bearer token — device-bound, stored in devices table'),
    ('Storage',             'Flat-file storage at ~/resolara_storage/ (uploads + generated)'),
    ('SSL',                 "Let's Encrypt wildcard *.resolara.ai — auto-renews via DirectAdmin"),
    ('Analytics / Crash',   'Firebase (Google) — non-fatal, no PHI logged'),
])

add_spacer(doc, 6)
add_subheading(doc, 'Programming Languages Used')
add_key_value_table(doc, [
    ('Dart',       'All mobile app logic, UI, models, services, routing, state management'),
    ('PHP',        'All backend API handlers, auth, AI orchestration, DB access'),
    ('SQL',        'MySQL schema — devices, activation_codes, jobs, visualizations, share_codes'),
    ('YAML',       'pubspec.yaml — Flutter dependencies and asset manifest'),
    ('XML',        'AndroidManifest.xml — permissions, metadata, AD_ID removal'),
    ('JSON',       'API request/response payloads, Firebase google-services config'),
    ('Bash',       'Build scripts, SSH server commands, pod update, Gradle'),
])

add_spacer(doc, 10)

# ══════════════════════════════════════════════════════════════════════════════
# 3. ARCHITECTURE
# ══════════════════════════════════════════════════════════════════════════════
add_section_heading(doc, '3.  Application Architecture')
add_spacer(doc, 4)
add_body(doc,
    'Resolara uses a privacy-first mobile architecture. The core principle is that original report '
    'images and PDFs never leave the device. OCR and first-pass redaction run on-device before any '
    'network call. Only cleaned, de-identified text is submitted to the Resolara API.')

add_spacer(doc, 4)
add_subheading(doc, 'Data Flow — Practitioner Workflow')
steps = [
    ('1  Capture',       'Practitioner photographs a report or imports a PDF. The file stays on-device.'),
    ('2  OCR',           'ML Kit extracts raw text from the image or PDF pages — fully on-device, no network.'),
    ('3  Redaction',     'Rule-based engine strips names, DOB, MRN, phone, email, addresses. Replaced with [PLACEHOLDER] tokens.'),
    ('4  Submit',        'Cleaned text + redaction summary sent to POST /v1/jobs. No images or PDFs leave the device.'),
    ('5  Extraction',    'Server runs Claude on the cleaned text. Returns structured findings: body region, description, confidence.'),
    ('6  Review',        'Practitioner reviews and edits findings on-device before any image is generated.'),
    ('7  Generate',      'Approved findings sent to POST /v1/visualizations. Server builds prompt, calls gpt-image-1, returns image URL.'),
    ('8  Approve',       'Practitioner reviews the generated anatomical illustration. Can regenerate or approve.'),
    ('9  Save',          'On approval, image saved to encrypted local storage (AES-256). Session record written to Drift DB.'),
    ('10 Share',         'Practitioner can share via native share sheet (image) or generate a 6-char share code for patient access.'),
]
add_key_value_table(doc, steps, header=['Step', 'Description'])

add_spacer(doc, 6)
add_subheading(doc, 'Data Flow — Patient Workflow')
patient_steps = [
    ('1  Receive code',  'Patient receives a 6-character share code (e.g. A3B7K2) from their practitioner.'),
    ('2  Scan / Enter',  'Patient opens the app, scans a QR code or enters the code manually.'),
    ('3  Fetch results', 'App calls GET /v1/patient/results/{code} — public endpoint, no auth required.'),
    ('4  View tabs',     'Results displayed in 4 tabs: Image · Knowledge · Exercises · Medications.'),
]
add_key_value_table(doc, patient_steps, header=['Step', 'Description'])

add_spacer(doc, 10)

# ══════════════════════════════════════════════════════════════════════════════
# 4. FILE STRUCTURE
# ══════════════════════════════════════════════════════════════════════════════
add_section_heading(doc, '4.  File Structure')
add_spacer(doc, 4)

add_subheading(doc, 'Mobile App  (lib/)')
add_key_value_table(doc, [
    ('lib/app/',                        'App shell, routing (go_router), theme, review mode notifier'),
    ('lib/core/api/',                   'API service classes — OcrService, GenerationService, ShareService, ExplanationService, ExercisesService, MedicationsService'),
    ('lib/core/models/',                'Typed models — Finding, ExtractionResult, GenerationJob, OcrJob, Exercise, Medication, Explanation'),
    ('lib/core/services/',              'LocalOcrService (ML Kit), RedactionService, SessionService, AnalyticsService, DeviceInfoService'),
    ('lib/core/storage/',               'AppDatabase (Drift), SecureFileStorage (AES-256 encrypted file store)'),
    ('lib/core/utils/',                 'image_stamp.dart — stamps patient label bar onto exported images'),
    ('lib/features/capture/',           'Camera, photo library, file import, "Describe Instead" entry points'),
    ('lib/features/reader/',            'ReaderScreen — OCR pipeline, redaction, submission, polling'),
    ('lib/features/extract/',           'ExtractScreen — finding review and edit before generation'),
    ('lib/features/options/',           'GenerationOptionsScreen — patient name, generation mode selection'),
    ('lib/features/generate/',          'GenerateScreen — job submission, polling, resume support'),
    ('lib/features/review/',            'ReviewScreen — image display, approve/regenerate, share, explanations, exercises, medications'),
    ('lib/features/sessions/',          'SessionsScreen + detail sheet — local history, share-with-patient flow'),
    ('lib/features/patient/',           'PatientHomeScreen, PatientQrScreen, PatientResultsScreen — 4-tab results view'),
    ('lib/features/onboarding/',        'OnboardingScreen — practitioner pass-through login, patient email entry'),
    ('lib/features/settings/',          'SettingsScreen — account info, usage stats, sign out, app reset'),
    ('lib/features/history/',           'HistoryScreen — encrypted saved visualization browser'),
    ('lib/shared/widgets/',             'Shared UI — LoadingOverlay, reusable components'),
])

add_spacer(doc, 6)
add_subheading(doc, 'Backend  (backend/src/)')
add_key_value_table(doc, [
    ('handlers/ActivateHandler.php',        'Validates practitioner activation code, issues bearer token'),
    ('handlers/ConfigHandler.php',          'Returns server-side config to app'),
    ('handlers/JobsHandler.php',            'Accepts cleaned text, creates extraction job, polls Claude'),
    ('handlers/VisualizationsHandler.php',  'Accepts findings, creates visualization job, calls gpt-image-1'),
    ('handlers/ShareHandler.php',           'Creates share codes (POST /v1/share), serves patient results (GET /v1/patient/results/{code})'),
    ('handlers/ExplanationHandler.php',     'Generates per-finding plain-language explanations via Claude'),
    ('handlers/ExercisesHandler.php',       'Generates recovery exercise plans via Claude (cached)'),
    ('handlers/MedicationsHandler.php',     'Generates medication suggestions via Claude (cached)'),
    ('handlers/ImagesHandler.php',          'Serves generated images from ~/resolara_storage/generated/'),
    ('services/ClaudeService.php',          'Claude API client — callRaw(), 429 retry, configurable model'),
    ('services/OpenAIService.php',          'OpenAI API client — gpt-image-1 image generation'),
    ('Auth.php',                            'Bearer token validation against devices table'),
    ('Database.php',                        'PDO MySQL wrapper — getInstance(), execute(), fetchOne()'),
    ('Response.php',                        'Standardised JSON response helpers'),
    ('index.php',                           'URL router — maps all /v1/* routes to handlers via regex'),
])

add_spacer(doc, 10)

# ══════════════════════════════════════════════════════════════════════════════
# 5. STORAGE
# ══════════════════════════════════════════════════════════════════════════════
add_section_heading(doc, '5.  Storage Locations')
add_spacer(doc, 4)

add_subheading(doc, 'On-Device (Mobile)')
add_key_value_table(doc, [
    ('Drift SQLite DB',         'App support directory — sessions, findings, job IDs, token counts, patient labels'),
    ('Encrypted files',         'App support directory — AES-256 encrypted PNG visualizations saved on approval'),
    ('Secure storage',          'iOS Keychain / Android Keystore — bearer token, user role, fresh-install marker'),
    ('Temporary files',         'Temporary directory — shared images before native share sheet; cleaned up after share'),
    ('Original report images',  'Never persisted — held in memory only for the duration of OCR, then discarded'),
    ('Original PDFs',           'Never persisted — rendered page-by-page in memory, then discarded'),
])

add_spacer(doc, 6)
add_subheading(doc, 'Server-Side')
add_key_value_table(doc, [
    ('Generated images',        '~/resolara_storage/generated/ — PNG files returned by gpt-image-1'),
    ('Uploaded source files',   '~/resolara_storage/uploads/ — not used in current architecture (OCR is on-device)'),
    ('MySQL database',          'DAUSER_resolara — tables: devices, activation_codes, jobs, visualizations, share_codes'),
    ('Config / API keys',       '~/resolara_api/config.php — Anthropic + OpenAI keys, DB credentials, storage paths'),
    ('Generation prompt',       '~/resolara_api/generation_prompt.txt — editable without app rebuild'),
    ('Security log',            '~/resolara_logs/security.log — auth failures, suspicious requests'),
    ('Backend source',          '~/resolara/backend/ — symlinked to ~/domains/resolara.ai/public_html/api'),
])

add_spacer(doc, 10)

# ══════════════════════════════════════════════════════════════════════════════
# 6. API ENDPOINTS
# ══════════════════════════════════════════════════════════════════════════════
add_section_heading(doc, '6.  API Endpoints')
add_spacer(doc, 4)
add_body(doc, 'Base URL:  https://resolara.ai/api')
add_spacer(doc, 4)
add_key_value_table(doc, [
    ('POST  /v1/activate',                  'Validate practitioner activation code → return bearer token'),
    ('GET   /v1/config',                    'Return server-side configuration to app'),
    ('POST  /v1/jobs',                      'Submit cleaned OCR text → start AI extraction job'),
    ('GET   /v1/jobs/{id}',                 'Poll extraction job status and results'),
    ('POST  /v1/visualizations',            'Submit confirmed findings → start image generation job'),
    ('GET   /v1/visualizations/{id}',       'Poll visualization job status and image URL'),
    ('GET   /v1/images/{filename}',         'Serve generated PNG from server storage'),
    ('POST  /v1/explanation',               'Generate per-finding plain-language explanations (Claude)'),
    ('POST  /v1/exercises',                 'Generate recovery exercise plan (Claude, cached)'),
    ('POST  /v1/medications',               'Generate medication suggestions (Claude, cached)'),
    ('POST  /v1/share',                     'Practitioner creates share record → returns 6-char code  [auth required]'),
    ('GET   /v1/patient/results/{code}',    'Patient fetches shared result by code  [no auth — public endpoint]'),
], header=['Endpoint', 'Purpose'])

add_spacer(doc, 10)

# ══════════════════════════════════════════════════════════════════════════════
# 7. DATABASE SCHEMA
# ══════════════════════════════════════════════════════════════════════════════
add_section_heading(doc, '7.  Database Schema  (MySQL)')
add_spacer(doc, 4)
add_key_value_table(doc, [
    ('devices',           'token, activation_code, created_at — one row per authenticated device. local-practitioner token inserted for pass-through login.'),
    ('activation_codes',  'code, max_activations, used_count — controls how many devices can activate with a given code'),
    ('jobs',              'id, device_token, status, cleaned_text, redaction_summary, result_json, tokens_in, tokens_out, created_at — OCR extraction jobs'),
    ('visualizations',    'id, device_token, job_id, status, image_url, image_path, prompt, error, created_at — image generation jobs'),
    ('share_codes',       'id, code (6-char, no dash), image_url, findings_json, exercises_json, medications_json, explanation_json, patient_name, created_at, expires_at — patient share records (1-year expiry)'),
], header=['Table', 'Columns & Purpose'])

add_spacer(doc, 10)

# ══════════════════════════════════════════════════════════════════════════════
# 8. NAVIGATION STRUCTURE
# ══════════════════════════════════════════════════════════════════════════════
add_section_heading(doc, '8.  Navigation Structure')
add_spacer(doc, 4)
add_key_value_table(doc, [
    ('Practitioner shell  /home',   'Bottom nav: Capture · Sessions · Settings'),
    ('  Capture',                   'Camera / Photo Library / File Import / Describe Instead'),
    ('  Sessions',                  'Local history of completed visualizations with detail sheet'),
    ('  Settings',                  'Account info, usage totals, sign out, reset app'),
    ('Patient shell  /patient',     'Bottom nav: Home · My Results'),
    ('  Patient Home',              'Scan QR Code button · Enter Code button · Logout (top right)'),
    ('  Patient QR Screen',         'Live scanner viewport + manual code entry field'),
    ('  Patient Results',           '4 tabs: Image · Knowledge · Exercises · Medications'),
    ('Onboarding  /onboarding',     'Practitioner tab (pass-through Enter button) · Patient tab (email entry)'),
    ('Imperative screens',          'ReaderScreen · ExtractScreen · GenerationOptionsScreen · GenerateScreen · ReviewScreen  (pushed via Navigator.push, not go_router)'),
], header=['Route / Screen', 'Description'])

add_spacer(doc, 10)

# ══════════════════════════════════════════════════════════════════════════════
# 9. BUILD HISTORY (recent)
# ══════════════════════════════════════════════════════════════════════════════
add_section_heading(doc, '9.  Recent Build History')
add_spacer(doc, 4)
add_key_value_table(doc, [
    ('Build 32',  'First Play Store live release'),
    ('Build 36',  'Patient logout button · QR scan race-condition fix · Firebase Analytics + Crashlytics'),
    ('Build 40',  'Pass-through practitioner login (activation code removed) · local-practitioner token registered in DB'),
    ('Build 41',  'Share flow — createShare() called before approve sheet · ShareHandler.php crash fixes · 6-char no-dash codes · route regex fix in index.php'),
    ('Build 42',  'Exercises max_tokens raised to 3000 (was truncating JSON and breaking cache)'),
    ('Build 43',  'Stale imperative route stack fix in review_screen.dart · Finding cast bug fixed in sessions share flow'),
    ('Build 44',  'QR _busy flag race fix · reader_screen context.go → popUntil fix · review _share() mounted check'),
    ('Build 45',  '_shareWithPatient() orphaned dialog fix · _sharing double-tap guard added (current build)'),
], header=['Build', 'Changes'])

add_spacer(doc, 10)

# ══════════════════════════════════════════════════════════════════════════════
# 10. SECURITY & PRIVACY RULES
# ══════════════════════════════════════════════════════════════════════════════
add_section_heading(doc, '10.  Security & Privacy Rules')
add_spacer(doc, 4)
add_key_value_table(doc, [
    ('Original files',          'Report images and PDFs never leave the mobile device under any circumstances'),
    ('OCR',                     'Runs fully on-device using ML Kit — raw text never sent to any server'),
    ('Redaction',               'Rule-based on-device pass strips PHI before any network call'),
    ('API keys',                'No vendor API keys in the mobile app — all keys server-side only'),
    ('Transit encryption',      'HTTPS/TLS 1.3 enforced on all API calls; ATS enforced on iOS; cleartext disabled on Android'),
    ('At-rest encryption',      'Saved visualizations encrypted with AES-256 on-device via encrypt package'),
    ('Keychain persistence',    'iOS Keychain survives app deletion — marker file clears stale tokens on fresh install'),
    ('Auth token',              'Device-bound bearer token — stored in Keychain/Keystore, never logged'),
    ('AD_ID permission',        'Removed from AndroidManifest via tools:node=remove — no advertising ID collected'),
    ('Firebase',                'Analytics and Crashlytics — non-fatal only; no PHI logged; wrapped in try/catch'),
    ('Server residual check',   'Second-pass PII safeguard on server — flags suspicious payloads without storing raw text'),
    ('Compliance note',         'Designed for HIPAA-aligned handling. Legal review, BAA, and formal risk analysis required before clinical deployment.'),
], header=['Area', 'Rule'])

add_spacer(doc, 10)

# ══════════════════════════════════════════════════════════════════════════════
# 11. SERVER ACCESS
# ══════════════════════════════════════════════════════════════════════════════
add_section_heading(doc, '11.  Server & Infrastructure')
add_spacer(doc, 4)
add_key_value_table(doc, [
    ('Production API',      'https://resolara.ai/api'),
    ('Server IP',           'ORIGIN_IP_REDACTED  ·  SSH port REDACTED  ·  user: DAUSER'),
    ('Hosting',             'DirectAdmin  —  REDACTED_HOST'),
    ('PHP version',         '8.2 (selectorctl per-user)'),
    ('SSL certificate',     "Let's Encrypt wildcard *.resolara.ai — auto-renews"),
    ('DB host',             'localhost (127.0.0.1) — MySQL'),
    ('DB name',             'DAUSER_resolara'),
    ('Storage root',        '~/resolara_storage/'),
    ('Backend root',        '~/resolara/backend/  →  symlink at ~/domains/resolara.ai/public_html/api'),
    ('GitHub repo',         'github.com/renthemighty/resolara (private) — deploy key at REDACTED'),
])

add_spacer(doc, 10)

# ══════════════════════════════════════════════════════════════════════════════
# 12. KNOWN LIMITATIONS / NEXT STEPS
# ══════════════════════════════════════════════════════════════════════════════
add_section_heading(doc, '12.  Known Limitations & Next Steps')
add_spacer(doc, 4)

add_subheading(doc, 'Current Limitations')
for item in [
    'Handwritten reports are not a primary OCR target — printed text only',
    'Token counts in session history show 0 — server /v1/jobs/{id} response shape needs verification',
    'Launch image is placeholder — needs custom splash screen asset',
    'Patient email authentication deferred — currently local UUID token only',
    'DB encryption key generated but not used to encrypt the Drift database itself (data at rest risk)',
]:
    add_bullet(doc, item)

add_spacer(doc, 4)
add_subheading(doc, 'Deferred / Phase 2')
for item in [
    'Certificate pinning',
    'Provider fallback routing (Claude fails → OpenAI fallback)',
    'Stronger audit / event logging',
    'ML-based on-device redaction (v1 uses rule-based regex)',
    'Desktop hub / clinic-mediated mode (Phase 3)',
    'EMR integration',
    'Monitoring, cost controls, cleanup jobs',
]:
    add_bullet(doc, item)

add_spacer(doc, 10)

# ══════════════════════════════════════════════════════════════════════════════
# FOOTER LINE
# ══════════════════════════════════════════════════════════════════════════════
footer_para = doc.add_paragraph()
shade_paragraph(footer_para, FOREST)
footer_para.paragraph_format.space_before = Pt(0)
footer_para.paragraph_format.space_after  = Pt(0)
footer_para.paragraph_format.left_indent  = Cm(0.4)
fp = footer_para.add_run('Resolara  ·  Build 45  ·  March 2026  ·  Confidential')
fp.font.size = Pt(8)
fp.font.color.rgb = SAGE

# ── Save ──────────────────────────────────────────────────────────────────────
out = '/Users/simonpainter/Documents/GitHub/resolara/Resolara_Build_Summary.docx'
doc.save(out)
print(f'Saved: {out}')
