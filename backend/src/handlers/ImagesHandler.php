<?php

class ImagesHandler {
    public static function handle(string $filename): never {
        Auth::require();

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
