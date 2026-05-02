<?php
// Server-side notification helpers. Every API endpoint that needs to
// inform a user (intern approved, mentor assigned, schedule uploaded,
// evaluation received, etc.) calls one of these functions to insert
// rows into the `notifications` table. The Flutter client polls
// /api/notifications/ to render the bell-icon list.

if (!function_exists('pro_link_notify')) {
    /**
     * Insert a single notification row for the given user.
     *
     * Errors are swallowed (logged only) so a failed notification can
     * never roll back the primary user-visible action that triggered
     * it.
     */
    function pro_link_notify(
        PDO $pdo,
        string $userId,
        string $title,
        string $message,
        string $type = 'info'
    ): void {
        if ($userId === '') return;
        try {
            $stmt = $pdo->prepare('INSERT INTO notifications
                (user_id, title, message, type)
                VALUES (:u, :t, :m, :ty)');
            $stmt->execute([
                ':u' => $userId,
                ':t' => $title,
                ':m' => $message,
                ':ty' => $type,
            ]);
        } catch (Throwable $e) {
            error_log('[pro-link] notify failed: ' . $e->getMessage());
        }
    }
}

if (!function_exists('pro_link_notify_role')) {
    /**
     * Fan out a notification to every active user with the given role.
     */
    function pro_link_notify_role(
        PDO $pdo,
        string $role,
        string $title,
        string $message,
        string $type = 'info'
    ): void {
        try {
            $stmt = $pdo->prepare('SELECT id FROM users
                                    WHERE role = :r AND is_active = TRUE');
            $stmt->execute([':r' => $role]);
            foreach ($stmt->fetchAll(PDO::FETCH_COLUMN) as $uid) {
                pro_link_notify($pdo, (string)$uid, $title, $message, $type);
            }
        } catch (Throwable $e) {
            error_log('[pro-link] notify_role failed: ' . $e->getMessage());
        }
    }
}
