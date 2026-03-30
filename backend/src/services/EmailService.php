<?php
declare(strict_types=1);

class EmailService {
    /**
     * Send a magic-link login email to a patient.
     * The link opens the app via the resolara:// URL scheme.
     */
    public static function sendMagicLink(string $toEmail, string $token): void {
        $appLink  = 'resolara://auth?token=' . urlencode($token);
        $webLink  = API_BASE_URL . '/v1/patient/verify?token=' . urlencode($token);
        $fromName = 'Resolara';
        $fromAddr = defined('MAIL_FROM') ? MAIL_FROM : 'noreply@resolara.ai';
        $subject  = 'Your Resolara login link';

        $body = <<<BODY
Hello,

Tap the link below to open the Resolara app and access your results.

{$appLink}

If the link above does not open the app, copy and paste it into your browser:
{$webLink}

This link expires in 30 minutes. If you did not request this, you can ignore this email.

— Resolara
BODY;

        $headers  = "From: {$fromName} <{$fromAddr}>\r\n";
        $headers .= "Reply-To: {$fromAddr}\r\n";
        $headers .= "Content-Type: text/plain; charset=UTF-8\r\n";
        $headers .= "X-Mailer: PHP/" . phpversion();

        $sent = mail($toEmail, $subject, $body, $headers);

        if (!$sent) {
            throw new RuntimeException('mail() failed for ' . $toEmail);
        }
    }
}
