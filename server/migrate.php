<?php
// One-off migration runner: reads every .sql file under server/migrations/
// in lexicographic order and executes it. Idempotent (CREATE IF NOT EXISTS).
// Usage: DATABASE_URL='postgresql://...' php server/migrate.php

require_once __DIR__ . '/lib/helpers.php';
require_once __DIR__ . '/lib/db.php';

$pdo = pro_link_pdo();
$dir = __DIR__ . '/migrations';
$files = glob($dir . '/*.sql');
sort($files);
foreach ($files as $f) {
    echo "[migrate] applying " . basename($f) . "\n";
    $sql = file_get_contents($f);
    $pdo->exec($sql);
}
echo "[migrate] done (" . count($files) . " file(s)).\n";
