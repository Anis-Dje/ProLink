<?php
// GET  /api/schedules/   — list office schedules / timetables
// POST /api/schedules/   — admin uploads a new schedule
//
// Scoping (issue: admin can target a schedule to one intern or a single
// specialization, not just publish to everybody):
//   * scope_type='public'           — visible to everyone (default)
//   * scope_type='specialization'   — visible to interns whose
//                                     interns.specialization equals
//                                     scope_value, plus their mentors,
//                                     plus admins.
//   * scope_type='intern'           — visible only to that single
//                                     intern (scope_value is the
//                                     intern's user_id), the assigned
//                                     mentor, and admins.

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
require_once __DIR__ . '/../lib/notifications.php';
pro_link_bootstrap();

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    $sql = 'SELECT s.* FROM schedules s';
    $where = [];
    $params = [];

    if ($me['role'] === 'intern') {
        // Look up the intern's specialization + own user id once so we
        // can match scope_value against either.
        $iStmt = $pdo->prepare(
            'SELECT specialization FROM interns WHERE user_id = :u');
        $iStmt->execute([':u' => $me['id']]);
        $spec = (string)($iStmt->fetchColumn() ?: '');
        $where[] = "(s.scope_type = 'public'
                     OR (s.scope_type = 'specialization'
                         AND s.scope_value = :spec)
                     OR (s.scope_type = 'intern'
                         AND s.scope_value = :uid))";
        $params[':spec'] = $spec;
        $params[':uid'] = $me['id'];
    } elseif ($me['role'] === 'mentor') {
        // Mentors see public schedules + anything scoped to one of
        // their interns or to a specialization shared with one of
        // their interns.
        $where[] = "(s.scope_type = 'public'
                     OR (s.scope_type = 'specialization'
                         AND s.scope_value IN (
                             SELECT specialization FROM interns
                              WHERE mentor_id = :me))
                     OR (s.scope_type = 'intern'
                         AND s.scope_value IN (
                             SELECT user_id::TEXT FROM interns
                              WHERE mentor_id = :me)))";
        $params[':me'] = $me['id'];
    }
    // Admin: no scope filter.

    if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
    $sql .= ' ORDER BY s.upload_date DESC';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();
    foreach ($rows as &$r) {
        $r['fileUrl'] = $r['file_url'];
        $r['uploadedBy'] = $r['uploaded_by'];
        $r['weekLabel'] = $r['week_label'];
        $r['uploadDate'] = pro_link_iso($r['upload_date']);
        $r['scopeType'] = $r['scope_type'] ?? 'public';
        $r['scopeValue'] = $r['scope_value'] ?? '';
    }
    pro_link_ok(['schedules' => $rows]);
}

if ($method === 'POST') {
    pro_link_require_role($me, 'admin');
    $body = pro_link_read_json();
    if (($body['title'] ?? '') === '' || ($body['fileUrl'] ?? '') === '') {
        pro_link_fail(400, 'missing_fields', 'title and fileUrl are required.');
    }
    $scopeType = $body['scopeType'] ?? 'public';
    $scopeValue = (string)($body['scopeValue'] ?? '');
    if (!in_array($scopeType, ['public', 'specialization', 'intern'], true)) {
        pro_link_fail(400, 'invalid_scope',
            'scopeType must be public, specialization or intern.');
    }
    if ($scopeType !== 'public' && $scopeValue === '') {
        pro_link_fail(400, 'missing_scope_value',
            'scopeValue is required when scopeType is specialization or intern.');
    }

    $ins = $pdo->prepare('INSERT INTO schedules
        (title, description, file_url, uploaded_by, week_label,
         scope_type, scope_value)
        VALUES (:t, :d, :f, :u, :w, :st, :sv) RETURNING *');
    $ins->execute([
        ':t' => $body['title'],
        ':d' => $body['description'] ?? '',
        ':f' => $body['fileUrl'],
        ':u' => $me['id'],
        ':w' => $body['weekLabel'] ?? '',
        ':st' => $scopeType,
        ':sv' => $scopeValue,
    ]);
    $r = $ins->fetch();
    $r['fileUrl'] = $r['file_url'];
    $r['uploadedBy'] = $r['uploaded_by'];
    $r['weekLabel'] = $r['week_label'];
    $r['uploadDate'] = pro_link_iso($r['upload_date']);
    $r['scopeType'] = $r['scope_type'];
    $r['scopeValue'] = $r['scope_value'];

    // Notification fan-out follows the same scoping rules.
    $msg = 'A new schedule has been published'
        . ((string)($body['weekLabel'] ?? '') !== ''
            ? ' for ' . $body['weekLabel'] : '') . '.';
    if ($scopeType === 'public') {
        pro_link_notify_role($pdo, 'mentor', 'New schedule', $msg, 'schedule');
        pro_link_notify_role($pdo, 'intern', 'New schedule', $msg, 'schedule');
    } elseif ($scopeType === 'specialization') {
        // Notify every active intern in that specialization + their
        // mentors (mentors are deduped by ID).
        $stmt = $pdo->prepare(
            'SELECT i.user_id, i.mentor_id
               FROM interns i JOIN users u ON u.id = i.user_id
              WHERE u.is_active = TRUE AND i.specialization = :s');
        $stmt->execute([':s' => $scopeValue]);
        $mentorSeen = [];
        foreach ($stmt->fetchAll() as $row) {
            pro_link_notify($pdo, (string)$row['user_id'],
                'New schedule', $msg, 'schedule');
            $mid = (string)($row['mentor_id'] ?? '');
            if ($mid !== '' && !isset($mentorSeen[$mid])) {
                pro_link_notify($pdo, $mid,
                    'New schedule', $msg, 'schedule');
                $mentorSeen[$mid] = true;
            }
        }
    } else { // 'intern'
        pro_link_notify($pdo, $scopeValue,
            'New schedule', $msg, 'schedule');
        $mStmt = $pdo->prepare(
            'SELECT mentor_id FROM interns WHERE user_id = :u');
        $mStmt->execute([':u' => $scopeValue]);
        $mid = (string)($mStmt->fetchColumn() ?: '');
        if ($mid !== '') {
            pro_link_notify($pdo, $mid,
                'New schedule', $msg, 'schedule');
        }
    }

    pro_link_ok(['schedule' => $r], 201);
}

pro_link_fail(405, 'method_not_allowed', 'Use GET or POST.');
