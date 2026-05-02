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

    // Neon SNI workaround. Older libpq builds (notably the one bundled
    // with XAMPP on Windows) cannot negotiate SNI, so Neon doesn't know
    // which compute endpoint a TLS handshake is for and rejects the
    // connection with "endpoint ID not specified". Neon's documented
    // workaround is to send the endpoint ID in libpq's `options`
    // connection parameter; modern libpq builds ignore it harmlessly.
    $options = $query['options'] ?? null;
    if ($options === null
        && str_ends_with($host, '.neon.tech')
        && preg_match('/^(ep-[a-z0-9-]+?)(?:-pooler)?\./', $host, $m)) {
        $options = 'endpoint=' . $m[1];
    }

    $dsn = sprintf(
        'pgsql:host=%s;port=%d;dbname=%s;sslmode=%s',
        $host, $port, $dbname, $sslmode
    );
    if ($options !== null && $options !== '') {
        $dsn .= ";options='" . $options . "'";
    }

    try {
        // EMULATE_PREPARES must be true when running against a
        // pgbouncer-style transaction-pooling endpoint (e.g. Neon's
        // "*-pooler" hostname). With server-side prepares the second
        // prepared query inside a transaction fails with
        // "current transaction is aborted" because the pooler may route
        // the two statements to different backend connections. Client-
        // side emulated prepares are just parameterised SQL, which the
        // pooler handles correctly, and PDO still provides proper
        // escaping / type handling.
        $pdo = new PDO($dsn, $user, $pass, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => true,
        ]);
    } catch (PDOException $e) {
        // The exception message can contain the connection string, so
        // don't echo it back to the client.
        error_log('[pro-link] DB connection failed: ' . $e->getMessage());
        pro_link_fail(500, 'db_connection_failed', 'Database connection failed.');
    }

    return $pdo;
}
