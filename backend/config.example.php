<?php
// Copy this file to config.php and fill in real values.
// config.php is gitignored — never commit it.

define('DB_HOST',     'localhost');
define('DB_NAME',     'DAUSER_resolara');
define('DB_USER',     'DAUSER_resolara_user');
define('DB_PASS',     'YOUR_DB_PASSWORD');

define('ANTHROPIC_API_KEY', 'YOUR_ANTHROPIC_KEY');
define('OPENAI_API_KEY',    'YOUR_OPENAI_KEY');

// Path for storing uploaded report images and generated visualizations.
// Must be outside the web root.
define('STORAGE_PATH', '/home/DAUSER/resolara_storage');

// API base URL (used in image_url responses)
define('API_BASE_URL', 'https://api.resolara.ai');

// Claude model to use for OCR + extraction
define('CLAUDE_MODEL', 'claude-sonnet-4-6');

// Image generation model — gpt-image-1 for flat style + text label support
define('DALLE_MODEL', 'gpt-image-1');
