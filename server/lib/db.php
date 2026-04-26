<?php
// Shared PDO connection to Neon Postgres. The DSN is derived from
// DATABASE_URL (the Neon connection string) so the same env var works in
// every environment.

function pro_link_pdo(): PDO {
    static $pdo = null;
    if ($pdo !== null) {
        return $pdo;
    }

    $url = getenv('DATABASE_URL');
    if ($url === false || $url === '') {
        pro_link_fail(500, 'server_misconfigured',
            'DATABASE_URL environment variable is not set.');
    }

    $parts = parse_url($url);
    if ($parts === false || !isset($parts['host'], $parts['user'], $parts['path'])) {
        pro_link_fail(500, 'server_misconfigured',
            'DATABASE_URL could not be parsed.');
    }

    $host = $parts['host'];
    $port = isset($parts['port']) ? (int)$parts['port'] : 5432;
    $user = urldecode($parts['user']);
    $pass = isset($parts['pass']) ? urldecode($parts['pass']) : '';
    $dbname = ltrim($parts['path'], '/');

    $query = [];
    if (isset($parts['query'])) {
        parse_str($parts['query'], $query);
    }
    $sslmode = $query['sslmode'] ?? 'require';

    $dsn = sprintf(
        'pgsql:host=%s;port=%d;dbname=%s;sslmode=%s',
        $host, $port, $dbname, $sslmode
    );

    try {
        $pdo = new PDO($dsn, $user, $pass, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    } catch (PDOException $e) {
        // The exception message can contain the connection string, so
        // don't echo it back to the client.
        error_log('[pro-link] DB connection failed: ' . $e->getMessage());
        pro_link_fail(500, 'db_connection_failed', 'Database connection failed.');
    }

    return $pdo;
}
