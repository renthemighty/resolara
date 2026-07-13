<?php
declare(strict_types=1);

class ExercisesHandler {
    public static function handle(): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            Response::error('Method not allowed', 405);
        }

        Auth::require();

        $body     = json_decode(file_get_contents('php://input'), true) ?? [];
        $findings = $body['findings'] ?? [];
        $phase    = trim((string)($body['phase'] ?? 'acute'));

        if (!in_array($phase, ['acute', 'subacute', 'rehabilitation'], true)) {
            Response::error('Invalid phase. Must be acute, subacute, or rehabilitation.');
        }

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

        $exercises = self::generate($clean, $phase);

        Response::json(['exercises' => $exercises]);
    }

    private static function generate(array $findings, string $phase): array {
        $phaseDescriptions = [
            'acute'          => 'acute phase (first 1-2 weeks) — rest, protection, pain management only',
            'subacute'       => 'subacute phase (weeks 2-6) — gentle range of motion, light stretching',
            'rehabilitation' => 'rehabilitation phase (6+ weeks, cleared for activity) — strengthening and functional exercises',
        ];

        $findingLines = array_map(function($f) {
            $label = $f['layman_term'] ?: $f['body_region'];
            return "- {$label}: {$f['finding']}";
        }, $findings);

        $findingText  = implode("\n", $findingLines);
        $phaseDesc    = $phaseDescriptions[$phase];

        $prompt = <<<PROMPT
You are assisting a licensed physiotherapist reviewing confirmed clinical findings.

Recovery phase: {$phaseDesc}

Based on the findings and phase below, return appropriate exercise recommendations.

IMPORTANT rules:
- If the findings include fractures, breaks, or acute bone injuries in the acute phase, set rest_only=true on ALL exercises and return only rest/immobilization recommendations.
- For soft tissue, ligament, tendon, or muscle injuries in subacute or rehabilitation phases, return active exercises.
- Match exercises precisely to the injured body region.
- Keep descriptions clear enough for a patient to follow without supervision.

For each exercise return a JSON object with these exact fields:
- id: unique string like "ex_1", "ex_2"
- name: short exercise name
- description: 2-3 sentences describing exactly how to perform it
- reps_or_duration: e.g. "Hold 30 seconds, 3 sets" or "10 repetitions, 3 sets"
- frequency: e.g. "3 times daily" or "Once daily"
- category: one of: stretch | mobility | strengthening | rest
- rest_only: true only for rest/immobilization items
- youtube_query: a precise YouTube search string that would find an accurate clinical demonstration of this specific exercise (e.g. "wrist flexion stretch physiotherapy demonstration")

Return ONLY a valid JSON array. No explanation, no markdown, no code fences. Maximum 6 items.

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
            // derived exercise prompt and may contain clinical content.
            error_log('ExercisesHandler: unexpected Claude response (length ' . strlen($text) . ')');
            return [];
        }

        $result = [];
        foreach ($parsed as $i => $e) {
            if (!is_array($e)) continue;
            $result[] = [
                'id'              => 'ex_' . ($i + 1),
                'name'            => substr(strip_tags((string)($e['name']             ?? '')), 0, 100),
                'description'     => substr(strip_tags((string)($e['description']      ?? '')), 0, 600),
                'reps_or_duration' => substr(strip_tags((string)($e['reps_or_duration'] ?? '')), 0, 100),
                'frequency'       => substr(strip_tags((string)($e['frequency']        ?? '')), 0, 100),
                'category'        => in_array($e['category'] ?? '', ['stretch','mobility','strengthening','rest'], true)
                                        ? $e['category']
                                        : 'stretch',
                'rest_only'       => (bool)($e['rest_only'] ?? false),
                'youtube_query'   => substr(strip_tags((string)($e['youtube_query']    ?? '')), 0, 200),
            ];
        }

        return $result;
    }
}
