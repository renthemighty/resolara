<?php
declare(strict_types=1);

class MedicationsHandler {
    public static function handle(): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            Response::error('Method not allowed', 405);
        }

        Auth::require();

        $body     = json_decode(file_get_contents('php://input'), true) ?? [];
        $findings = $body['findings'] ?? [];

        if (empty($findings) || !is_array($findings)) {
            Response::error('findings array is required.');
        }

        if (count($findings) > 20) {
            Response::error('Too many findings. Maximum is 20.');
        }

        $clean = array_map(fn($f) => [
            'body_region' => substr(strip_tags((string)($f['body_region'] ?? '')), 0, 100),
            'finding'     => substr(strip_tags((string)($f['finding']     ?? '')), 0, 500),
            'layman_term' => substr(strip_tags((string)($f['layman_term'] ?? '')), 0, 100),
        ], $findings);

        $medications = self::suggest($clean);

        Response::json(['medications' => $medications]);
    }

    private static function suggest(array $findings): array {
        $findingLines = array_map(function($f) {
            $label = $f['layman_term'] ?: $f['body_region'];
            return "- {$label}: {$f['finding']}";
        }, $findings);

        $findingText = implode("\n", $findingLines);

        $prompt = <<<PROMPT
You are assisting a licensed healthcare practitioner who is reviewing confirmed clinical findings.

Based on the findings below, list the medications that are commonly considered for these conditions. Include both over-the-counter and common prescription options as appropriate.

For each medication return a JSON object with these exact fields:
- id: a unique string like "med_1", "med_2" etc.
- name: the generic medication name
- purpose: one sentence explaining why it is commonly considered for these findings
- typical_dosing: a general dosing range practitioners commonly use (e.g. "400–600 mg, two to three times daily with food")

Return ONLY a valid JSON array. No explanation, no markdown, no code fences. Maximum 6 medications.

Confirmed findings:
{$findingText}
PROMPT;

        $response = ClaudeService::complete($prompt, maxTokens: 1200);
        $text     = trim($response['content'] ?? '');

        // Strip markdown code fences if present
        $text = preg_replace('/^```(?:json)?\s*/i', '', $text);
        $text = preg_replace('/\s*```$/', '', $text);

        $parsed = json_decode($text, true);

        if (!is_array($parsed)) {
            error_log('MedicationsHandler: unexpected Claude response: ' . $text);
            return [];
        }

        $result = [];
        foreach ($parsed as $i => $m) {
            if (!is_array($m)) continue;
            $result[] = [
                'id'            => 'med_' . ($i + 1),
                'name'          => substr(strip_tags((string)($m['name']           ?? '')), 0, 100),
                'purpose'       => substr(strip_tags((string)($m['purpose']        ?? '')), 0, 300),
                'typical_dosing' => substr(strip_tags((string)($m['typical_dosing'] ?? '')), 0, 200),
                'ai_suggested'  => true,
            ];
        }

        return $result;
    }
}
