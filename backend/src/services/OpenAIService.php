<?php

class OpenAIService {
    private const IMAGE_URL = 'https://api.openai.com/v1/images/generations';

    private const PROMPT_SUFFIX = "show me a 2d image of what these issues would look like, and show the affected areas in red";

    /**
     * Generate a visualization from structured findings.
     * Saves the image to storage and returns the local filename.
     */
    public static function generateVisualization(array $findings, string $patientName = ''): string {
        $lines = [];
        foreach ($findings as $f) {
            $region  = trim($f['body_region'] ?? '');
            $finding = trim($f['finding']     ?? '');
            if ($region && $finding) {
                $lines[] = $region . ': ' . $finding;
            } elseif ($finding) {
                $lines[] = $finding;
            }
        }
        $text = implode("\n", $lines);
        $prompt = self::buildPrompt($text, $patientName);
        return self::generate($prompt);
    }

    /**
     * Generate a visualization from a free-form text description.
     * Used by the "Describe Instead" flow.
     */
    public static function generateFromPrompt(string $directPrompt, string $patientName = ''): string {
        $prompt = self::buildPrompt(trim($directPrompt), $patientName);
        return self::generate($prompt);
    }

    /**
     * The patient name is deliberately NOT included in the prompt.
     * It is a direct HIPAA identifier and must never be transmitted to a
     * third-party AI vendor. It also serves no generative purpose: the name
     * is stamped onto the image on-device (image_stamp.dart) after generation.
     * $patientName is retained in the signature for call-site compatibility only.
     */
    private static function buildPrompt(string $text, string $patientName): string {
        unset($patientName);
        $parts = [];
        if ($text !== '') $parts[] = $text;
        $parts[] = self::PROMPT_SUFFIX;
        return implode("\n", $parts);
    }

    private static function generate(string $prompt): string {
        $payload = [
            'model'   => DALLE_MODEL,
            'prompt'  => $prompt,
            'n'       => 1,
            'size'    => '1024x1024',
            'quality' => 'high',
        ];

        $response = self::call(self::IMAGE_URL, $payload);

        $b64      = $response['data'][0]['b64_json'] ?? null;
        $imageUrl = $response['data'][0]['url']      ?? null;

        $filename = 'viz_' . bin2hex(random_bytes(12)) . '.png';
        $destPath = STORAGE_PATH . '/generated/' . $filename;

        if ($b64 !== null) {
            $imageData = base64_decode($b64);
            if ($imageData === false) {
                throw new RuntimeException('Failed to decode base64 image from API');
            }
        } elseif ($imageUrl !== null) {
            $imageData = file_get_contents($imageUrl);
            if ($imageData === false) {
                throw new RuntimeException('Failed to download generated image');
            }
        } else {
            throw new RuntimeException('API returned neither b64_json nor url');
        }

        file_put_contents($destPath, $imageData);
        return $filename;
    }

    private static function call(string $url, array $payload): array {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => json_encode($payload),
            CURLOPT_HTTPHEADER     => [
                'Content-Type: application/json',
                'Authorization: Bearer ' . OPENAI_API_KEY,
            ],
            CURLOPT_TIMEOUT        => 180,
        ]);
        $body = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($body === false || $code !== 200) {
            throw new RuntimeException('OpenAI API error ' . $code . ': ' . substr($body, 0, 300));
        }
        return json_decode($body, true);
    }
}
