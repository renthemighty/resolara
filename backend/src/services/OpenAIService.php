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
        // Extract unique body regions
        $regions = array_unique(array_filter(array_map(
            fn($f) => $f['body_region'] ?? '',
            $findings
        )));
        $regionList = implode(', ', $regions) ?: 'musculoskeletal';

        // Build numbered finding labels from the actual findings
        $labelLines = [];
        foreach (array_values($findings) as $i => $f) {
            $label  = $f['body_region'] ?? '';
            $detail = $f['finding']     ?? '';
            // Keep labels concise and neutral — no clinical injury language
            if ($detail) {
                // Truncate to first 60 chars to keep the prompt manageable
                $short = substr($detail, 0, 60);
                $labelLines[] = ($i + 1) . '. ' . $label . ': ' . $short;
            } elseif ($label) {
                $labelLines[] = ($i + 1) . '. ' . $label;
            }
        }
        $labelBlock = implode("\n", $labelLines);
        $count = count($labelLines);

        return "A simple flat anatomical diagram of the human {$regionList}. "
             . "Style: flat vector illustration, clean simple outlines, white background, "
             . "soft muted colors (light beige/tan for bones, pale skin tones), "
             . "absolutely no 3D shading, no gradients, no photorealism, no harsh contrast. "
             . "Think: clean infographic or medical textbook line drawing. "
             . "Place exactly {$count} small numbered circle markers (like ① ② ③) directly on the diagram "
             . "at the relevant anatomical locations for these structures:\n{$labelBlock}\n"
             . "The circles should be clearly visible, filled with a muted accent color, white number inside. "
             . "No other text anywhere in the image — numbers only. "
             . "Educational reference style. No patient data, no clinical photography.";
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
