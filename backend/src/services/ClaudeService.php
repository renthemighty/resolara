<?php

class ClaudeService {
    private const API_URL = 'https://api.anthropic.com/v1/messages';

    /**
     * Send a report image to Claude for OCR + structured extraction.
     * Returns parsed findings array or throws on failure.
     */
    public static function extractFindings(string $imagePath): array {
        $imageData   = base64_encode(file_get_contents($imagePath));
        $imageType   = 'image/jpeg';

        $systemPrompt = <<<PROMPT
You are a medical report analyzer for a clinical visualization system used by licensed healthcare professionals.
Analyze the provided medical report image and extract clinically relevant findings.

Rules:
- Extract only medically relevant findings (anatomy, pathology, measurements, observations)
- Do NOT include patient name, date of birth, address, ID numbers, referring physician names, or facility names
- Set pii_risk=true for any finding that might contain identifying information
- Set confidence based on how clearly the text is readable and unambiguous (0.0-1.0)
- Use standardized anatomical body_region names (e.g. "lumbar spine", "left knee", "chest")

Return ONLY valid JSON with this exact structure, no other text:
{
  "findings": [
    {
      "id": "f1",
      "body_region": "anatomical region",
      "finding": "clinical finding text",
      "confidence": 0.92,
      "pii_risk": false
    }
  ],
  "pii_detected": ["list of any PII strings found, empty if none"],
  "overall_confidence": 0.88
}
PROMPT;

        $payload = [
            'model'      => CLAUDE_MODEL,
            'max_tokens' => 2048,
            'system'     => $systemPrompt,
            'messages'   => [[
                'role'    => 'user',
                'content' => [[
                    'type'       => 'image',
                    'source'     => [
                        'type'       => 'base64',
                        'media_type' => $imageType,
                        'data'       => $imageData,
                    ],
                ], [
                    'type' => 'text',
                    'text' => 'Extract the medical findings from this report image.',
                ]],
            ]],
        ];

        $response = self::call($payload);
        $text     = $response['content'][0]['text'] ?? '';

        // Strip any markdown code fences if present
        $text = preg_replace('/^```(?:json)?\s*/m', '', $text);
        $text = preg_replace('/\s*```$/m', '', $text);
        $text = trim($text);

        $parsed = json_decode($text, true);
        if (!is_array($parsed) || !isset($parsed['findings'])) {
            throw new RuntimeException('Claude returned unexpected format: ' . substr($text, 0, 200));
        }
        return $parsed;
    }

    private static function call(array $payload): array {
        $ch = curl_init(self::API_URL);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => json_encode($payload),
            CURLOPT_HTTPHEADER     => [
                'Content-Type: application/json',
                'x-api-key: ' . ANTHROPIC_API_KEY,
                'anthropic-version: 2023-06-01',
            ],
            CURLOPT_TIMEOUT        => 120,
        ]);
        $body = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($body === false || $code !== 200) {
            throw new RuntimeException('Claude API error ' . $code . ': ' . substr($body, 0, 300));
        }
        return json_decode($body, true);
    }
}
