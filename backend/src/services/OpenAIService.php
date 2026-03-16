<?php

class OpenAIService {
    private const IMAGE_URL = 'https://api.openai.com/v1/images/generations';

    /**
     * Generate an anatomical visualization from confirmed findings.
     * Downloads the image, saves it to storage, returns local filename.
     */
    public static function generateVisualization(array $findings): string {
        $prompt = self::buildPrompt($findings);

        $payload = [
            'model'   => DALLE_MODEL,
            'prompt'  => $prompt,
            'n'       => 1,
            'size'    => '1024x1024',
            'quality' => 'standard',
        ];

        $response = self::call(self::IMAGE_URL, $payload);
        $imageUrl = $response['data'][0]['url'] ?? null;

        if (!$imageUrl) {
            throw new RuntimeException('OpenAI returned no image URL');
        }

        // Download and store the image (DALL-E URLs expire in ~1 hour)
        $filename = 'viz_' . bin2hex(random_bytes(12)) . '.jpg';
        $destPath = STORAGE_PATH . '/generated/' . $filename;

        $imageData = file_get_contents($imageUrl);
        if ($imageData === false) {
            throw new RuntimeException('Failed to download generated image');
        }
        file_put_contents($destPath, $imageData);
        return $filename;
    }

    private static function buildPrompt(array $findings): string {
        // Extract unique body regions for the illustration focus
        $regions = array_unique(array_filter(array_map(
            fn($f) => $f['body_region'] ?? '',
            $findings
        )));
        $regionList = implode(', ', $regions) ?: 'musculoskeletal';

        // Describe structures to highlight without clinical injury language
        $structures = [];
        foreach ($findings as $f) {
            $region = $f['body_region'] ?? '';
            if ($region) $structures[] = $region;
        }
        $structureList = implode(', ', array_unique($structures));

        return "A detailed scientific anatomical illustration of the human {$regionList} "
             . "showing internal structures including bones, ligaments, tendons and soft tissue. "
             . "Textbook diagram style with labeled anatomical landmarks. "
             . "Clean white background, educational illustration, no text overlays, "
             . "precise anatomical detail, professional medical reference art style.";
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
            CURLOPT_TIMEOUT        => 120,
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
