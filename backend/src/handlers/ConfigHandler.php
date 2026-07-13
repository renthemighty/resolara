<?php

class ConfigHandler {
    public static function handle(): never {
        if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
            Response::error('Method not allowed', 405);
        }

        $configPath = STORAGE_PATH . '/app_config.json';

        if (!file_exists($configPath)) {
            // Return built-in defaults if no override file exists
            Response::json(self::defaults());
        }

        $raw = file_get_contents($configPath);
        $config = json_decode($raw, true);

        if (!is_array($config)) {
            Response::json(self::defaults());
        }

        // Merge with defaults so new keys always have a value
        Response::json(array_replace_recursive(self::defaults(), $config));
    }

    private static function defaults(): array {
        return [
            'body_regions' => [
                'cervical_spine'    => 'Cervical Spine',
                'thoracic_spine'    => 'Thoracic Spine',
                'lumbar_spine'      => 'Lumbar Spine',
                'shoulder_left'     => 'Left Shoulder',
                'shoulder_right'    => 'Right Shoulder',
                'elbow_left'        => 'Left Elbow',
                'elbow_right'       => 'Right Elbow',
                'wrist_left'        => 'Left Wrist',
                'wrist_right'       => 'Right Wrist',
                'hip_left'          => 'Left Hip',
                'hip_right'         => 'Right Hip',
                'knee_left'         => 'Left Knee',
                'knee_right'        => 'Right Knee',
                'ankle_left'        => 'Left Ankle',
                'ankle_right'       => 'Right Ankle',
                'head'              => 'Head',
                'chest'             => 'Chest',
                'abdomen'           => 'Abdomen',
                'pelvis'            => 'Pelvis',
            ],
            'retention_days'     => 90,
            'max_findings'       => 20,
            'support_email'      => 'support@resolara.ai',
            'app_message'        => null,
            'maintenance_mode'   => false,
            'backend_version'    => APP_VERSION,
        ];
    }
}
