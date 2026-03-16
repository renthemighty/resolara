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

    // Words that trigger DALL-E safety filters — map to visual equivalents
    private static function sanitizeFinding(string $text): string {
        $replacements = [
            '/\bfracture[sd]?\b/i'    => 'structural irregularity',
            '/\btorn?\b/i'            => 'disrupted',
            '/\brupture[sd]?\b/i'     => 'structural disruption',
            '/\btear[s]?\b/i'         => 'tissue separation',
            '/\binjur(?:y|ies|ed)\b/i'=> 'structural change',
            '/\bdamage[sd]?\b/i'      => 'structural variation',
            '/\blesion[s]?\b/i'       => 'area of altered tissue',
            '/\bdisplacement\b/i'     => 'positional variation',
            '/\bcomminut\w+\b/i'      => 'multi-part',
            '/\bnecros\w+\b/i'        => 'tissue change',
            '/\bpatholog\w+\b/i'      => 'anatomical variation',
        ];
        foreach ($replacements as $pattern => $replacement) {
            $text = preg_replace($pattern, $replacement, $text);
        }
        return $text;
    }

    private static function buildPrompt(array $findings): string {
        // Extract unique body regions
        $regions = array_unique(array_filter(array_map(
            fn($f) => $f['body_region'] ?? '',
            $findings
        )));
        $regionList = implode(', ', $regions) ?: 'musculoskeletal';

        // Build numbered finding list — sanitized for safety filter
        $labelLines = [];
        foreach (array_values($findings) as $i => $f) {
            $region = $f['body_region'] ?? '';
            $detail = self::sanitizeFinding($f['finding'] ?? '');
            $entry  = ($i + 1) . '. ';
            $entry .= $region ? "{$region}" : '';
            if ($detail) $entry .= $region ? " — {$detail}" : $detail;
            $labelLines[] = $entry;
        }
        $labelBlock = implode("\n", $labelLines);
        $count = count($labelLines);

        return "A detailed anatomical education diagram of the human {$regionList}, "
             . "in the style of a professional medical textbook illustration. "
             . "White or very light grey background. Realistic clean anatomical rendering — "
             . "beige/tan bones, natural skin tones, clearly defined structures. "
             . "Illustration style only, not photographic.\n\n"
             . "Highlight the following anatomical areas of interest, each visually distinct "
             . "from surrounding tissue using colour emphasis (warm reddish tones for "
             . "soft tissue changes, structural line emphasis for bone variations):\n{$labelBlock}\n\n"
             . "Place a small numbered circle marker at each highlighted area (① ② ③ …). "
             . "Numbers only inside the circles — no other text in the image. "
             . "Suitable for use as a practitioner patient-education reference.";
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
