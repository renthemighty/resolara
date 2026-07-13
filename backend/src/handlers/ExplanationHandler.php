<?php
declare(strict_types=1);

class ExplanationHandler {
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
            'id'          => substr(preg_replace('/[^a-zA-Z0-9_-]/', '', (string)($f['id'] ?? '')), 0, 32),
            'body_region' => substr(strip_tags((string)($f['body_region'] ?? '')), 0, 100),
            'finding'     => substr(strip_tags((string)($f['finding']     ?? '')), 0, 500),
            'layman_term' => substr(strip_tags((string)($f['layman_term'] ?? '')), 0, 100),
        ], $findings);

        $explanations = self::generate($clean);

        Response::json(['explanations' => $explanations]);
    }

    private static function generate(array $findings): array {
        $findingLines = array_map(function($f) {
            $label = $f['layman_term'] ?: $f['body_region'];
            return "- ID {$f['id']} | {$label}: {$f['finding']}";
        }, $findings);

        $findingText = implode("\n", $findingLines);

        $prompt = <<<PROMPT
You are explaining medical findings to a patient in plain, clear language. The practitioner has reviewed and confirmed these findings.

For each finding, write a JSON object with these exact fields:
- id: the finding ID provided
- heading: a clear plain-English name for the condition (e.g. "Wrist Fracture" not "Scaphoid waist fracture")
- what_it_is: 2-3 sentences explaining what the condition is in plain language a non-medical person can understand
- why_it_matters: 2-3 sentences explaining how this affects the patient day-to-day and why treatment matters
- outlook: 1-2 sentences on typical recovery expectations

Rules:
- Use plain language. Avoid medical jargon.
- Do not give specific treatment instructions or prescriptions.
- Do not make prognoses beyond what is typical and general.
- Keep a calm, informative tone.

Return ONLY a valid JSON array. No explanation, no markdown, no code fences.

Confirmed findings:
{$findingText}
PROMPT;

        $response = ClaudeService::complete($prompt, maxTokens: 2000);
        $text     = trim($response['content'] ?? '');

        $text = preg_replace('/^```(?:json)?\s*/i', '', $text);
        $text = preg_replace('/\s*```$/',            '', $text);

        $parsed = json_decode($text, true);

        if (!is_array($parsed)) {
            // Do not log $text — it is Claude's raw output for a findings-
            // derived explanation prompt and may contain clinical content.
            error_log('ExplanationHandler: unexpected Claude response (length ' . strlen($text) . ')');
            return [];
        }

        $result = [];
        foreach ($parsed as $e) {
            if (!is_array($e)) continue;
            $result[] = [
                'id'            => substr(strip_tags((string)($e['id']            ?? '')), 0, 32),
                'heading'       => substr(strip_tags((string)($e['heading']       ?? '')), 0, 150),
                'what_it_is'    => substr(strip_tags((string)($e['what_it_is']    ?? '')), 0, 600),
                'why_it_matters' => substr(strip_tags((string)($e['why_it_matters'] ?? '')), 0, 600),
                'outlook'       => substr(strip_tags((string)($e['outlook']       ?? '')), 0, 400),
            ];
        }

        return $result;
    }
}
