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

        // Build numbered finding list with full detail for visual rendering
        $labelLines = [];
        foreach (array_values($findings) as $i => $f) {
            $region = $f['body_region'] ?? '';
            $detail = $f['finding']     ?? '';
            $entry  = ($i + 1) . '. ';
            if ($detail) {
                $entry .= $region ? "{$region}: {$detail}" : $detail;
            } else {
                $entry .= $region;
            }
            $labelLines[] = $entry;
        }
        $labelBlock = implode("\n", $labelLines);
        $count = count($labelLines);

        return "A professional medical education illustration of the human {$regionList}, "
             . "rendered in the style of a high-quality anatomical textbook or medical app diagram. "
             . "Clean light background (white to very light grey gradient). "
             . "Realistic but clean anatomical rendering — beige/tan bones with subtle shading, "
             . "natural skin tones, clearly defined structures. "
             . "NOT photographic — illustration style, like BioDigital or Visible Body.\n\n"
             . "The illustration must visually depict these specific findings:\n{$labelBlock}\n\n"
             . "CRITICAL — show each finding as it actually appears: "
             . "fractures must show visible crack lines and bone displacement, "
             . "edema/swelling must show reddened enlarged soft tissue, "
             . "tears must show disrupted or separated tissue, "
             . "lesions must show distinct abnormal areas, "
             . "degeneration must show worn irregular surfaces. "
             . "Affected areas should be clearly visually distinct from healthy tissue "
             . "(use colour contrast — red/pink for inflammation, highlighted cracks for fractures).\n\n"
             . "Place a small numbered circle marker (① ② ③ …) directly at each affected area. "
             . "Numbers only — no other text anywhere in the image. "
             . "Educational reference illustration only. No patient data, no clinical photography.";
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
