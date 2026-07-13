/// Allowlist used to suppress name-detectors on ordinary clinical language.
///
/// Without this, every "Chest Xray", "Colles Fracture" or "Distal Radius" in
/// a report reads as a plausible two-word proper name and drowns the
/// practitioner in false positives. This is intentionally small (~250
/// terms) — it does not need to be exhaustive, it just needs to cover the
/// common anatomy / modality / eponym / section-header vocabulary that
/// otherwise collides with the capitalized-bigram and header-zone name
/// detectors.
///
/// Matching is done case-insensitively by the detectors in `detectors.dart`.
library;

/// Exact two/three-word clinical phrases that must never be flagged as a
/// name, even though both/all words are individually capitalized.
const Set<String> medicalPhrases = {
  'colles fracture',
  'achilles tendon',
  'achilles tendonitis',
  'bennett fracture',
  'smith fracture',
  'galeazzi fracture',
  'monteggia fracture',
  'jones fracture',
  'pott fracture',
  "pott's fracture",
  'salter harris',
  'chance fracture',
  'segond fracture',
  'bankart lesion',
  'hill sachs',
  'hill-sachs lesion',
  'baker cyst',
  "baker's cyst",
  'osgood schlatter',
  "osgood-schlatter disease",
  'dupuytren contracture',
  "dupuytren's contracture",
  'de quervain',
  "de quervain's tenosynovitis",
  'morton neuroma',
  "morton's neuroma",
  'haglund deformity',
  'sudeck atrophy',
  'chopart joint',
  'lisfranc injury',
  'lisfranc fracture',
  'boxer fracture',
  "boxer's fracture",
  'chauffeur fracture',
  'barton fracture',
  'maisonneuve fracture',
  'weber classification',
  'garden classification',
  'gustilo classification',
  'neer classification',
  'tossy classification',
  'rockwood classification',
  'ottawa ankle',
  'ottawa knee',
  'glasgow coma',
  'chest xray',
  'chest x-ray',
  'plain film',
  'soft tissue',
  'weight bearing',
  'range of motion',
  'blood pressure',
  'heart rate',
  'respiratory rate',
  'body mass',
  'differential diagnosis',
  'clinical impression',
  'chief complaint',
  'past medical history',
  'family history',
  'social history',
  'review of systems',
  'physical examination',
  'vital signs',
  'lab results',
  'imaging findings',
  'plan of care',
  'follow up',
  'follow-up',
};

/// Individual words that, on their own, are strong evidence a capitalized
/// token is clinical vocabulary rather than part of a person's name. If
/// either word in a candidate bigram matches this set, the bigram detector
/// skips it.
const Set<String> medicalWords = {
  // Anatomy
  'chest', 'abdomen', 'pelvis', 'spine', 'cervical', 'thoracic', 'lumbar',
  'sacral', 'coccyx', 'skull', 'cranium', 'femur', 'tibia', 'fibula',
  'humerus', 'radius', 'ulna', 'clavicle', 'scapula', 'sternum', 'rib',
  'ribs', 'hip', 'knee', 'ankle', 'wrist', 'elbow', 'shoulder', 'shoulders',
  'hand', 'hands', 'foot', 'feet', 'finger', 'fingers', 'toe', 'toes',
  'thumb', 'jaw', 'mandible', 'maxilla', 'orbit', 'sinus', 'sinuses',
  'trachea', 'esophagus', 'stomach', 'liver', 'spleen', 'kidney', 'kidneys',
  'bladder', 'uterus', 'ovary', 'ovaries', 'prostate', 'colon', 'rectum',
  'aorta', 'artery', 'vein', 'ventricle', 'atrium', 'lung', 'lungs',
  'pulmonary', 'cardiac', 'hepatic', 'renal', 'gastric', 'brain',
  'cerebral', 'cerebellum', 'meniscus', 'ligament', 'ligaments', 'tendon',
  'tendons', 'cartilage', 'muscle', 'muscles', 'joint', 'joints', 'bone',
  'bones', 'marrow', 'nerve', 'nerves', 'disc', 'discs', 'vertebra',
  'vertebrae', 'patella', 'calcaneus', 'talus', 'navicular', 'cuboid',
  'metatarsal', 'metacarpal', 'phalanx', 'phalanges', 'carpal', 'tarsal',
  'acetabulum', 'sacroiliac', 'iliac', 'ischium', 'pubis', 'malleolus',
  'olecranon', 'coracoid', 'acromion', 'glenoid', 'trochanter',
  // Direction / position
  'left', 'right', 'bilateral', 'unilateral', 'anterior', 'posterior',
  'medial', 'lateral', 'proximal', 'distal', 'superior', 'inferior',
  'dorsal', 'ventral', 'transverse', 'oblique', 'sagittal', 'coronal',
  'axial', 'supine', 'prone', 'upright',
  // Modalities / procedures
  'xray', 'x-ray', 'radiograph', 'radiography', 'ultrasound', 'mri', 'mra',
  'ct', 'cta', 'pet', 'spect', 'fluoroscopy', 'mammogram', 'mammography',
  'angiogram', 'angiography', 'biopsy', 'endoscopy', 'colonoscopy',
  'echocardiogram', 'electrocardiogram', 'ekg', 'ecg', 'eeg', 'emg',
  'densitometry', 'scintigraphy', 'venogram', 'myelogram', 'arthrogram',
  // Conditions / findings
  'fracture', 'fractures', 'sprain', 'strain', 'dislocation',
  'subluxation', 'contusion', 'laceration', 'abrasion', 'edema',
  'effusion', 'hematoma', 'hemorrhage', 'inflammation', 'infection',
  'arthritis', 'osteoarthritis', 'osteoporosis', 'osteopenia', 'stenosis',
  'herniation', 'degenerative', 'tear', 'tendinopathy', 'tendinitis',
  'bursitis', 'neuropathy', 'radiculopathy', 'myelopathy', 'scoliosis',
  'kyphosis', 'lordosis', 'spondylosis', 'spondylolisthesis', 'malunion',
  'nonunion', 'callus', 'necrosis', 'ischemia', 'infarct', 'thrombosis',
  'embolism', 'aneurysm', 'nodule', 'nodules', 'mass', 'lesion', 'lesions',
  'cyst', 'tumor', 'neoplasm', 'metastasis', 'atrophy', 'hypertrophy',
  'deformity', 'contracture', 'instability', 'impingement', 'displacement',
  'comminuted', 'compression', 'avulsion', 'intact', 'unremarkable',
  'normal', 'abnormal', 'stable', 'unchanged', 'improved', 'worsened',
  'mild', 'moderate', 'severe', 'acute', 'chronic', 'subacute',
  // Report structure / demographics words (also useful for header-zone
  // false-positive suppression — these commonly appear title-cased on
  // their own line in the demographics block)
  'patient', 'report', 'date', 'exam', 'examination', 'study', 'findings',
  'impression', 'history', 'indication', 'technique', 'comparison',
  'recommendation', 'summary', 'conclusion', 'diagnosis', 'referring',
  'ordering', 'attending', 'interpreting', 'radiologist', 'physician',
  'clinic', 'clinical', 'hospital', 'department', 'male', 'female', 'age',
  'sex', 'gender', 'weight', 'height', 'signed', 'electronically',
  'dictated', 'transcribed', 'reviewed', 'page', 'continued', 'none',
  'view', 'views', 'series', 'protocol', 'contrast', 'without', 'with',
};
