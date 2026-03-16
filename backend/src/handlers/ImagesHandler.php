<?php

class ImagesHandler {
    public static function handle(string $filename): never {
        Auth::require();

        if (!preg_match('/^[a-f0-9_]+\.(?:jpg|jpeg|png)$/i', $filename)) {
            Response::notFound();
        }

        $path = STORAGE_PATH . '/generated/' . $filename;

        if (!file_exists($path)) {
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
