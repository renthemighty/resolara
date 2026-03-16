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
                $short = mb_substr($detail, 0, 60);
                $labelLines[] = ($i + 1) . '. ' . $label . ': ' . $short;
            } elseif ($label) {
                $labelLines[] = ($i + 1) . '. ' . $label;
            }
        }
        $labelBlock = implode("\n", $labelLines);
        $count = count($labelLines);

        return "A clean, light-toned scientific anatomical diagram of the human {$regionList}. "
             . "Style: textbook medical illustration, soft neutral palette, white or very pale background, "
             . "precise line art with gentle shading, no harsh contrast or dark tones. "
             . "The diagram must include {$count} clearly visible callout labels numbered 1 through {$count}, "
             . "each with a thin leader line pointing to the relevant anatomical structure. "
             . "Label text should be small, legible, and placed outside the body outline. "
             . "The labeled structures correspond to these findings:\n{$labelBlock}\n"
             . "Educational reference illustration style. No patient data, no clinical photography, "
             . "no photorealistic imagery. Suitable for use as a practitioner communication aid.";
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
