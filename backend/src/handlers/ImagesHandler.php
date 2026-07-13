<?php

class ImagesHandler {
    /**
     * Two ways in:
     *  1. Normal device Bearer auth (practitioner app viewing its own
     *     generated images) — unchanged.
     *  2. `?t=<image_access_token>` — the opaque, high-entropy token a
     *     patient's client obtains only by decrypting a share bundle with
     *     its URL-fragment key (see ShareHandler's H5 fix docblock). The
     *     token is looked up by its SHA-256 hash and must resolve to this
     *     exact filename; a bare code or a guessed token gets nothing.
     */
    public static function handle(string $filename): never {
        $shareToken = trim((string)($_GET['t'] ?? ''));
        if ($shareToken !== '') {
            $allowedFilename = ShareHandler::imageFilenameForToken($shareToken);
            if ($allowedFilename === null || $allowedFilename !== $filename) {
                Response::notFound();
            }
        } else {
            Auth::require();
        }

        if (!preg_match('/^[a-z0-9_]+$/i', $filename)) {
            Response::notFound();
        }

        $path = null;
        foreach (['jpg', 'jpeg', 'png'] as $ext) {
            $candidate = STORAGE_PATH . '/generated/' . $filename . '.' . $ext;
            if (file_exists($candidate)) {
                $path = $candidate;
                break;
            }
        }

        if ($path === null) {
            Response::notFound();
        }

        $finfo    = new finfo(FILEINFO_MIME_TYPE);
        $mimeType = $finfo->file($path);

        header('Content-Type: ' . $mimeType);
        header('Content-Length: ' . filesize($path));
        header('Cache-Control: private, max-age=86400');
        readfile($path);
        exit;
    }
}
