<?php
// GET /api/legal-documents
//
// Public (un-authenticated) endpoint that surfaces the most recently
// uploaded "Privacy Policy" and "Terms & Conditions" documents the
// admin has published. Used by the registration / login screens to
// hyperlink each phrase to the corresponding PDF before the user has
// a session token.
//
// Identification is by title match: the most recent training_files row
// whose title contains "privacy" wins the privacy slot, same for
// "terms". Returns nulls when nothing matches yet.

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('GET');

$pdo = pro_link_pdo();

function pro_link_find_legal(PDO $pdo, string $needle): ?array
{
    $stmt = $pdo->prepare(
        'SELECT id, title, file_url, upload_date
           FROM training_files
          WHERE title ILIKE :q
          ORDER BY upload_date DESC
          LIMIT 1'
    );
    $stmt->execute([':q' => '%' . $needle . '%']);
    $row = $stmt->fetch();
    if (!$row) return null;
    return [
        'id' => $row['id'],
        'title' => $row['title'],
        'fileUrl' => $row['file_url'],
        'uploadDate' => pro_link_iso($row['upload_date']),
    ];
}

pro_link_ok([
    'privacy' => pro_link_find_legal($pdo, 'privacy'),
    'terms' => pro_link_find_legal($pdo, 'terms'),
]);
