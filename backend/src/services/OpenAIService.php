<?php

class OpenAIService {
    private const IMAGE_URL = 'https://api.openai.com/v1/images/generations';

    /**
     * Generate an anatomical visualization from confirmed findings.
     * Saves the image to storage and returns the local filename.
     */
    public static function generateVisualization(array $findings): string {
        $prompt = self::buildPrompt($findings);

        $payload = [
            'model'   => DALLE_MODEL,   // gpt-image-1
            'prompt'  => $prompt,
            'n'       => 1,
            'size'    => '1024x1024',
            'quality' => 'high',
        ];

        $response = self::call(self::IMAGE_URL, $payload);

        // gpt-image-1 returns base64 directly; dall-e-3 returns a URL
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

    private static function buildPrompt(array $findings): string {
        // Extract unique body regions
        $regions = array_unique(array_filter(array_map(
            fn($f) => $f['body_region'] ?? '',
            $findings
        )));
        $regionList = implode(', ', $regions) ?: 'musculoskeletal';

        // Build labelled finding list — body region + short clinical detail
        $labelLines = [];
        foreach (array_values($findings) as $i => $f) {
            $region = $f['body_region'] ?? '';
            $detail = $f['finding']     ?? '';
            $entry  = ($i + 1) . '. ' . ($region ?: 'structure');
            if ($detail) $entry .= ': ' . substr($detail, 0, 80);
            $labelLines[] = $entry;
        }
        $labelBlock = implode("\n", $labelLines);
        $count      = count($labelLines);

        return "Create a clean flat medical education illustration of the human {$regionList}.\n\n"
             . "Style: flat 2D anatomical diagram, vector illustration aesthetic, "
             . "white background, simple clean outlines, muted colour palette "
             . "(light beige/tan for bone, soft skin tones), minimal shading. "
             . "Think: clear infographic-style medical diagram, not photorealistic.\n\n"
             . "The diagram must visually show these {$count} findings, each clearly marked:\n"
             . "{$labelBlock}\n\n"
             . "For each finding draw a callout line from a small filled circle marker "
             . "to a text label placed outside the body outline. "
             . "Use the exact label text from the list above for each callout. "
             . "Affected areas should use subtle colour cues (soft red/pink wash for "
             . "inflammation or swelling, dashed outline for structural changes). "
             . "Labels should be small, legible, sans-serif. "
             . "This is a patient-education reference illustration for licensed practitioners.";
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
